import postgres, { type Sql } from "postgres";
import { defaultUserScopes, type CalorieTargetSource, type DailyGoals, type Meal, type MealItem, type MealLabel, type MealProposal, type MealTemplate, type NutritionSnapshot, type PermissionScope } from "@cal-tracker/contracts";
import { newId } from "../utils/ids.js";
import { normalizeText } from "../utils/normalize.js";
import { subtractNutrition, sumNutrition } from "../utils/nutrition.js";
import type {
  ActionCallRecord,
  AppRepository,
  AuditEventRecord,
  AuthIdentityProvider,
  AuthIdentityRecord,
  EmbeddingModelRecord,
  FoodFeedbackRecord,
  FoodItemRecord,
  FoodItemEmbeddingRecord,
  FoodHybridSearchInput,
  FoodPortionRecord,
  FoodSearchCandidate,
  MemoryMatch,
  StoredSession,
  StoredUser,
  UpsertFoodItemEmbeddingInput,
  UserFoodPreference
} from "./types.js";

const ACTIVE_EMBEDDING_MODEL = { provider: "local", model: "bge-m3", dimensions: 1024 };
const DEFAULT_FOOD_SEARCH_LIMIT = 50;
const MAX_FOOD_SEARCH_LIMIT = 100;
const LEXICAL_SCORE_WEIGHT = 0.7;
const VECTOR_SCORE_WEIGHT = 0.25;
const LEXICAL_ONLY_SCORE_WEIGHT = 0.95;
const PREFERENCE_SCORE_WEIGHT = 0.05;
const PREFERENCE_SCORE_NORMALIZER = 10;

export class PostgresRepository implements AppRepository {
  private readonly sql: Sql;

  constructor(databaseUrl: string) {
    this.sql = postgres(databaseUrl);
  }

  async createUser(input: { email: string; displayName: string; passwordHash?: string; scopes: PermissionScope[] }): Promise<StoredUser> {
    const [row] = await this.sql`
      INSERT INTO users (email, display_name)
      VALUES (${input.email.toLowerCase()}, ${input.displayName})
      RETURNING id, email, display_name, trusted_mode_enabled, created_at
    `;
    if (input.passwordHash) {
      await this.sql`INSERT INTO user_credentials (user_id, password_hash) VALUES (${row.id}, ${input.passwordHash})`;
    }
    await this.sql`
      INSERT INTO nutrition_targets (
        user_id, calories, protein_grams, carbs_grams, fat_grams, hydration_goal_glasses,
        calorie_target_configured, calorie_target_source
      )
      VALUES (${row.id}, 2200, 160, 240, 70, 12, false, 'default')
    `;
    const user = this.mapUser(row, input.passwordHash, input.scopes);
    return user;
  }

  async findUserByEmail(email: string): Promise<StoredUser | undefined> {
    const [row] = await this.sql`
      SELECT u.id, u.email, u.display_name, u.trusted_mode_enabled, u.created_at, c.password_hash
      FROM users u
      LEFT JOIN user_credentials c ON c.user_id = u.id
      WHERE lower(u.email) = lower(${email}) AND u.deleted_at IS NULL
    `;
    return row ? this.mapUser(row, row.password_hash as string | undefined, defaultUserScopes) : undefined;
  }

  async findUserById(id: string): Promise<StoredUser | undefined> {
    const [row] = await this.sql`
      SELECT u.id, u.email, u.display_name, u.trusted_mode_enabled, u.created_at, c.password_hash
      FROM users u
      LEFT JOIN user_credentials c ON c.user_id = u.id
      WHERE u.id = ${id} AND u.deleted_at IS NULL
    `;
    return row ? this.mapUser(row, row.password_hash as string | undefined, defaultUserScopes) : undefined;
  }

  async updateTrustedMode(userId: string, enabled: boolean): Promise<StoredUser> {
    await this.sql`UPDATE users SET trusted_mode_enabled = false WHERE id = ${userId}`;
    const user = await this.findUserById(userId);
    if (!user) throw new Error("user_not_found");
    return user;
  }

  async findAuthIdentity(provider: AuthIdentityProvider, providerUserId: string): Promise<AuthIdentityRecord | undefined> {
    const [row] = await this.sql`
      SELECT id, user_id, provider, provider_user_id, email, created_at, updated_at
      FROM auth_identities
      WHERE provider = ${provider} AND provider_user_id = ${providerUserId}
      LIMIT 1
    `;
    return row ? mapAuthIdentity(row) : undefined;
  }

  async linkAuthIdentity(input: { userId: string; provider: AuthIdentityProvider; providerUserId: string; email: string }): Promise<AuthIdentityRecord> {
    const [row] = await this.sql`
      INSERT INTO auth_identities (user_id, provider, provider_user_id, email)
      VALUES (${input.userId}, ${input.provider}, ${input.providerUserId}, ${input.email.toLowerCase()})
      ON CONFLICT (provider, provider_user_id)
      DO UPDATE SET email = EXCLUDED.email, updated_at = now()
      RETURNING id, user_id, provider, provider_user_id, email, created_at, updated_at
    `;
    return mapAuthIdentity(row);
  }

  async createSession(input: Omit<StoredSession, "createdAt">): Promise<StoredSession> {
    const [row] = await this.sql`
      INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at, revoked_at, rotated_at)
      VALUES (${input.id}, ${input.userId}, ${input.refreshTokenHash}, ${input.expiresAt}, ${input.revokedAt ?? null}, ${input.rotatedAt ?? null})
      RETURNING *
    `;
    return mapSession(row);
  }

  async findSessionByRefreshTokenHash(hash: string): Promise<StoredSession | undefined> {
    const [row] = await this.sql`
      SELECT * FROM auth_sessions
      WHERE refresh_token_hash = ${hash} AND revoked_at IS NULL AND expires_at > now()
      LIMIT 1
    `;
    return row ? mapSession(row) : undefined;
  }

  async revokeSession(sessionId: string): Promise<void> {
    await this.sql`UPDATE auth_sessions SET revoked_at = now() WHERE id = ${sessionId}`;
  }

  async revokeAllSessions(userId: string): Promise<void> {
    await this.sql`UPDATE auth_sessions SET revoked_at = now() WHERE user_id = ${userId} AND revoked_at IS NULL`;
  }

  async rotateSession(sessionId: string, nextHash: string, expiresAt: string): Promise<StoredSession> {
    const [row] = await this.sql`
      UPDATE auth_sessions
      SET refresh_token_hash = ${nextHash}, expires_at = ${expiresAt}, rotated_at = now()
      WHERE id = ${sessionId}
      RETURNING *
    `;
    return mapSession(row);
  }

  async createPasswordReset(input: { userId: string; tokenHash: string; expiresAt: string }): Promise<void> {
    await this.sql`
      INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
      VALUES (${input.userId}, ${input.tokenHash}, ${input.expiresAt})
    `;
  }

  async consumePasswordReset(tokenHash: string, newPasswordHash: string): Promise<boolean> {
    return this.sql.begin(async (tx) => {
      const [reset] = await tx`
        UPDATE password_reset_tokens
        SET used_at = now()
        WHERE token_hash = ${tokenHash} AND used_at IS NULL AND expires_at > now()
        RETURNING user_id
      `;
      if (!reset) return false;
      await tx`UPDATE user_credentials SET password_hash = ${newPasswordHash}, updated_at = now() WHERE user_id = ${reset.user_id}`;
      return true;
    });
  }

  async listFoods(userId: string): Promise<FoodItemRecord[]> {
    const rows = await this.sql`SELECT * FROM food_items WHERE user_id IS NULL OR user_id = ${userId}`;
    return this.mapFoodsWithPortions(rows);
  }

  async searchFoods(userId: string, query: string, barcode?: string): Promise<FoodItemRecord[]> {
    const candidates = await this.searchFoodsHybrid(userId, { query, barcode });
    return candidates.map(stripFoodSearchCandidate);
  }

  async searchFoodsHybrid(userId: string, input: FoodHybridSearchInput): Promise<FoodSearchCandidate[]> {
    const limit = sanitizeLimit(input.limit);
    const normalized = normalizeText(input.query);
    const candidateRows = new Map<string, { row: Record<string, unknown>; lexicalScore: number; vectorScore?: number }>();
    const includeBranded = !input.excludeBranded;

    if (input.barcode) {
      const rows = await this.sql`
        SELECT *, 1::float AS search_score
        FROM food_items
        WHERE (user_id IS NULL OR user_id = ${userId}) AND barcode = ${input.barcode}
        LIMIT ${limit}
      `;
      for (const row of rows) {
        candidateRows.set(row.id as string, { row, lexicalScore: 1 });
      }
    } else if (normalized.length > 0) {
      const rows = await this.sql`
          WITH food_query AS (SELECT ${normalized}::text AS q)
          SELECT food_items.*,
                 GREATEST(
                   similarity(food_items.normalized_name, food_query.q),
                   similarity(COALESCE(food_items.canonical_name, ''), food_query.q),
                   similarity(COALESCE(food_items.brand, ''), food_query.q)
                 ) AS search_score
          FROM food_items, food_query
          WHERE (food_items.user_id IS NULL OR food_items.user_id = ${userId})
            AND (${includeBranded} OR food_items.data_type IS DISTINCT FROM 'Branded')
            AND (
              food_items.normalized_name % food_query.q
              OR COALESCE(food_items.canonical_name, '') % food_query.q
              OR COALESCE(food_items.brand, '') % food_query.q
              OR food_query.q LIKE '%' || food_items.normalized_name || '%'
              OR food_items.normalized_name LIKE '%' || food_query.q || '%'
              OR food_query.q LIKE '%' || COALESCE(food_items.canonical_name, food_items.normalized_name) || '%'
              OR COALESCE(food_items.canonical_name, food_items.normalized_name) LIKE '%' || food_query.q || '%'
            )
          ORDER BY
            CASE WHEN food_items.user_id = ${userId} THEN 0 ELSE 1 END,
            CASE food_items.data_type
              WHEN 'SR Legacy' THEN 0
              WHEN 'Foundation' THEN 1
              WHEN 'Survey (FNDDS)' THEN 2
              WHEN 'Branded' THEN 3
              ELSE 2
            END,
            search_score DESC,
            char_length(food_items.normalized_name),
            food_items.name
          LIMIT ${Math.max(limit, DEFAULT_FOOD_SEARCH_LIMIT)}
        `;
      for (const row of rows) {
        candidateRows.set(row.id as string, { row, lexicalScore: clampScore(Number(row.search_score ?? 0)) });
      }
    }

    if (!input.barcode && input.embedding && input.embeddingModelId) {
      const vectorLiteral = toVectorLiteral(input.embedding);
      const rows = await this.sql`
        SELECT food_items.*,
               1 - (food_item_embeddings.embedding <=> ${vectorLiteral}::vector) AS vector_score
        FROM food_item_embeddings
        JOIN food_items ON food_items.id = food_item_embeddings.food_item_id
        WHERE food_item_embeddings.embedding_model_id = ${input.embeddingModelId}
          AND (food_items.user_id IS NULL OR food_items.user_id = ${userId})
          AND (${includeBranded} OR food_items.data_type IS DISTINCT FROM 'Branded')
        ORDER BY food_item_embeddings.embedding <=> ${vectorLiteral}::vector
        LIMIT ${Math.max(limit, DEFAULT_FOOD_SEARCH_LIMIT)}
      `;
      for (const row of rows) {
        const foodId = row.id as string;
        const existing = candidateRows.get(foodId);
        const vectorScore = clampScore(Number(row.vector_score ?? 0));
        if (existing) {
          existing.vectorScore = Math.max(existing.vectorScore ?? 0, vectorScore);
        } else {
          candidateRows.set(foodId, { row, lexicalScore: 0, vectorScore });
        }
      }
    }

    const merged = [...candidateRows.values()];
    if (merged.length === 0) return [];

    const foods = await this.mapFoodsWithPortions(merged.map((candidate) => candidate.row));
    const scoresByFoodId = new Map(merged.map((candidate) => [candidate.row.id as string, candidate]));
    const preferenceScores = await this.getPreferenceScoreMap(userId, foods.map((food) => food.id));

    return foods
      .map((food) => {
        const scores = scoresByFoodId.get(food.id);
        const lexicalScore = clampScore(scores?.lexicalScore ?? 0);
        const vectorScore = scores?.vectorScore == null ? undefined : clampScore(scores.vectorScore);
        const preferenceScore = clamp((preferenceScores.get(food.id) ?? 0) / PREFERENCE_SCORE_NORMALIZER, -1, 1);
        const baseScore = vectorScore == null
          ? lexicalScore * LEXICAL_ONLY_SCORE_WEIGHT
          : lexicalScore * LEXICAL_SCORE_WEIGHT + vectorScore * VECTOR_SCORE_WEIGHT;
        return {
          ...food,
          lexicalScore,
          vectorScore,
          preferenceScore,
          finalScore: clampScore(baseScore + preferenceScore * PREFERENCE_SCORE_WEIGHT)
        };
      })
      .sort((a, b) => b.finalScore - a.finalScore || b.lexicalScore - a.lexicalScore || (b.vectorScore ?? 0) - (a.vectorScore ?? 0))
      .slice(0, limit);
  }

  async upsertFoodItem(input: Omit<FoodItemRecord, "id">): Promise<FoodItemRecord> {
    const normalizedName = normalizeText(input.normalizedName || input.name);
    const [existing] = input.externalSource && input.externalId
      ? await this.sql`
          SELECT * FROM food_items
          WHERE external_source = ${input.externalSource}
            AND external_id = ${input.externalId}
            AND (user_id IS NULL OR user_id = ${input.userId ?? null})
          LIMIT 1
        `
      : await this.sql`
          SELECT * FROM food_items
          WHERE normalized_name = ${normalizedName}
            AND source = ${input.source}
            AND user_id IS NOT DISTINCT FROM ${input.userId ?? null}
          LIMIT 1
        `;
    if (existing) {
      const [row] = await this.sql`
        UPDATE food_items
        SET name = ${input.name},
            normalized_name = ${normalizedName},
            canonical_name = ${input.canonicalName ?? input.name},
            brand = ${input.brand ?? null},
            barcode = ${input.barcode ?? null},
            source = ${input.source},
            external_source = ${input.externalSource ?? null},
            external_id = ${input.externalId ?? null},
            source_url = ${input.sourceUrl ?? null},
            license = ${input.license ?? null},
            fetched_at = ${input.fetchedAt ?? new Date().toISOString()},
            data_type = ${input.dataType ?? null},
            food_category = ${input.foodCategory ?? null},
            publication_date = ${input.publicationDate ?? null},
            ndb_number = ${input.ndbNumber ?? null},
            food_key = ${input.foodKey ?? null},
            ingredients = ${input.ingredients ?? null},
            market_country = ${input.marketCountry ?? null},
            household_serving_fulltext = ${input.householdServingFulltext ?? null},
            nutrients_json = ${this.sql.json((input.nutrients ?? {}) as never)},
            serving_grams = ${input.servingGrams},
            calories = ${input.calories},
            protein_grams = ${input.proteinGrams},
            carbs_grams = ${input.carbsGrams},
            fat_grams = ${input.fatGrams}
        WHERE id = ${existing.id as string}
        RETURNING *
      `;
      return mapFood(row);
    }
    const [row] = await this.sql`
      INSERT INTO food_items (
        user_id, name, normalized_name, canonical_name, brand, barcode, source,
        external_source, external_id, source_url, license, fetched_at,
        data_type, food_category, publication_date, ndb_number, food_key,
        ingredients, market_country, household_serving_fulltext, nutrients_json,
        serving_grams, calories, protein_grams, carbs_grams, fat_grams
      )
      VALUES (
        ${input.userId ?? null}, ${input.name}, ${normalizedName}, ${input.canonicalName ?? input.name},
        ${input.brand ?? null}, ${input.barcode ?? null}, ${input.source},
        ${input.externalSource ?? null}, ${input.externalId ?? null}, ${input.sourceUrl ?? null},
        ${input.license ?? null}, ${input.fetchedAt ?? new Date().toISOString()},
        ${input.dataType ?? null}, ${input.foodCategory ?? null}, ${input.publicationDate ?? null},
        ${input.ndbNumber ?? null}, ${input.foodKey ?? null}, ${input.ingredients ?? null},
        ${input.marketCountry ?? null}, ${input.householdServingFulltext ?? null},
        ${this.sql.json((input.nutrients ?? {}) as never)},
        ${input.servingGrams}, ${input.calories}, ${input.proteinGrams}, ${input.carbsGrams}, ${input.fatGrams}
      )
      RETURNING *
    `;
    return mapFood(row);
  }

  async recordFoodFeedback(input: FoodFeedbackRecord): Promise<UserFoodPreference | undefined> {
    const normalizedQuery = normalizeText(input.query);
    const delta = foodFeedbackDelta(input.action);
    const positiveDelta = delta > 0 ? 1 : 0;
    const negativeDelta = delta < 0 ? 1 : 0;

    const [preference] = await this.sql.begin(async (tx) => {
      const foodItemId = input.foodItemId ?? (input.externalSource && input.externalId
        ? (await tx`
            SELECT id
            FROM food_items
            WHERE external_source = ${input.externalSource}
              AND external_id = ${input.externalId}
              AND (user_id IS NULL OR user_id = ${input.userId})
            ORDER BY CASE WHEN user_id = ${input.userId} THEN 0 ELSE 1 END
            LIMIT 1
          `)[0]?.id as string | undefined
        : undefined);
      if (!foodItemId) return [];

      await tx`
        INSERT INTO user_food_feedback_events (user_id, food_item_id, query_text, normalized_query, action, metadata_json)
        VALUES (
          ${input.userId},
          ${foodItemId},
          ${input.query},
          ${normalizedQuery},
          ${input.action},
          ${tx.json((input.metadata ?? {}) as never)}
        )
      `;
      return tx`
        INSERT INTO user_food_preferences (
          user_id, food_item_id, affinity_score, positive_feedback_count, negative_feedback_count, last_feedback_at, updated_at
        )
        VALUES (${input.userId}, ${foodItemId}, ${delta}, ${positiveDelta}, ${negativeDelta}, now(), now())
        ON CONFLICT (user_id, food_item_id)
        DO UPDATE SET
          affinity_score = user_food_preferences.affinity_score + EXCLUDED.affinity_score,
          positive_feedback_count = user_food_preferences.positive_feedback_count + EXCLUDED.positive_feedback_count,
          negative_feedback_count = user_food_preferences.negative_feedback_count + EXCLUDED.negative_feedback_count,
          last_feedback_at = now(),
          updated_at = now()
        RETURNING *
      `;
    });
    return preference ? mapUserFoodPreference(preference) : undefined;
  }

  async getUserFoodPreferences(userId: string): Promise<UserFoodPreference[]> {
    const rows = await this.sql`
      SELECT *
      FROM user_food_preferences
      WHERE user_id = ${userId}
      ORDER BY affinity_score DESC, updated_at DESC
    `;
    return rows.map(mapUserFoodPreference);
  }

  async getActiveEmbeddingModel(): Promise<EmbeddingModelRecord | undefined> {
    const [row] = await this.sql`
      SELECT *
      FROM embedding_models
      WHERE provider = ${ACTIVE_EMBEDDING_MODEL.provider}
        AND model = ${ACTIVE_EMBEDDING_MODEL.model}
        AND dimensions = ${ACTIVE_EMBEDDING_MODEL.dimensions}
      ORDER BY created_at DESC
      LIMIT 1
    `;
    return row ? mapEmbeddingModel(row) : undefined;
  }

  async upsertFoodItemEmbedding(input: UpsertFoodItemEmbeddingInput): Promise<FoodItemEmbeddingRecord> {
    const embedding = toVectorLiteral(input.embedding);
    const [row] = await this.sql`
      INSERT INTO food_item_embeddings (
        food_item_id, embedding_model_id, embedded_text, embedded_text_hash, embedding, updated_at
      )
      VALUES (
        ${input.foodItemId},
        ${input.embeddingModelId},
        ${input.embeddedText},
        ${input.embeddedTextHash},
        ${embedding}::vector,
        now()
      )
      ON CONFLICT (food_item_id, embedding_model_id)
      DO UPDATE SET
        embedded_text = EXCLUDED.embedded_text,
        embedded_text_hash = EXCLUDED.embedded_text_hash,
        embedding = EXCLUDED.embedding,
        updated_at = now()
      RETURNING *
    `;
    return mapFoodItemEmbedding(row);
  }

  async getNutritionTarget(userId: string): Promise<NutritionSnapshot> {
    const [row] = await this.sql`SELECT * FROM nutrition_targets WHERE user_id = ${userId}`;
    return row ? mapNutrition(row) : { calories: 2200, proteinGrams: 160, carbsGrams: 240, fatGrams: 70 };
  }

  async getDailyGoals(userId: string, date: string): Promise<DailyGoals> {
    const [existing] = await this.sql`
      SELECT *
      FROM daily_goal_snapshots
      WHERE user_id = ${userId} AND target_date = ${date}
    `;
    if (existing) return mapDailyGoals(existing);

    const current = await this.getCurrentGoals(userId);
    const [inserted] = await this.sql`
      INSERT INTO daily_goal_snapshots (
        user_id, target_date, calories, protein_grams, carbs_grams, fat_grams, hydration_goal_glasses,
        calorie_target_configured, calorie_target_source, calorie_target_configured_at
      )
      VALUES (
        ${userId}, ${date}, ${current.target.calories}, ${current.target.proteinGrams}, ${current.target.carbsGrams}, ${current.target.fatGrams}, ${current.hydrationGoalGlasses},
        ${current.calorieTargetConfigured}, ${current.calorieTargetSource}, ${current.calorieTargetConfiguredAt ?? null}
      )
      ON CONFLICT (user_id, target_date) DO NOTHING
      RETURNING *
    `;
    if (inserted) return mapDailyGoals(inserted);
    const [row] = await this.sql`
      SELECT *
      FROM daily_goal_snapshots
      WHERE user_id = ${userId} AND target_date = ${date}
    `;
    return mapDailyGoals(row);
  }

  async updateDailyGoals(userId: string, input: { date: string; calories?: number; hydrationGoalGlasses?: number; calorieTargetSource?: CalorieTargetSource }): Promise<DailyGoals> {
    return this.sql.begin(async (tx) => {
      const current = await this.getCurrentGoals(userId, tx);
      for (const snapshotDate of previousDatesInWeek(input.date)) {
        await tx`
          INSERT INTO daily_goal_snapshots (
            user_id, target_date, calories, protein_grams, carbs_grams, fat_grams, hydration_goal_glasses,
            calorie_target_configured, calorie_target_source, calorie_target_configured_at
          )
          VALUES (
            ${userId}, ${snapshotDate}, ${current.target.calories}, ${current.target.proteinGrams}, ${current.target.carbsGrams}, ${current.target.fatGrams}, ${current.hydrationGoalGlasses},
            ${current.calorieTargetConfigured}, ${current.calorieTargetSource}, ${current.calorieTargetConfiguredAt ?? null}
          )
          ON CONFLICT (user_id, target_date) DO NOTHING
        `;
      }

      const nextTarget = {
        ...current.target,
        calories: input.calories ?? current.target.calories
      };
      const nextHydration = input.hydrationGoalGlasses ?? current.hydrationGoalGlasses;
      const calorieTargetWasUpdated = input.calories !== undefined;
      const nextConfigured = calorieTargetWasUpdated ? true : current.calorieTargetConfigured;
      const nextSource = calorieTargetWasUpdated ? input.calorieTargetSource ?? "manual" : current.calorieTargetSource;
      const nextConfiguredAt = calorieTargetWasUpdated ? new Date().toISOString() : current.calorieTargetConfiguredAt;
      await tx`
        INSERT INTO nutrition_targets (
          user_id, calories, protein_grams, carbs_grams, fat_grams, hydration_goal_glasses,
          calorie_target_configured, calorie_target_source, calorie_target_configured_at, updated_at
        )
        VALUES (
          ${userId}, ${nextTarget.calories}, ${nextTarget.proteinGrams}, ${nextTarget.carbsGrams}, ${nextTarget.fatGrams}, ${nextHydration},
          ${nextConfigured}, ${nextSource}, ${nextConfiguredAt ?? null}, now()
        )
        ON CONFLICT (user_id) DO UPDATE
        SET calories = EXCLUDED.calories,
            protein_grams = EXCLUDED.protein_grams,
            carbs_grams = EXCLUDED.carbs_grams,
            fat_grams = EXCLUDED.fat_grams,
            hydration_goal_glasses = EXCLUDED.hydration_goal_glasses,
            calorie_target_configured = EXCLUDED.calorie_target_configured,
            calorie_target_source = EXCLUDED.calorie_target_source,
            calorie_target_configured_at = EXCLUDED.calorie_target_configured_at,
            updated_at = now()
      `;
      const [row] = await tx`
        INSERT INTO daily_goal_snapshots (
          user_id, target_date, calories, protein_grams, carbs_grams, fat_grams, hydration_goal_glasses,
          calorie_target_configured, calorie_target_source, calorie_target_configured_at, updated_at
        )
        VALUES (
          ${userId}, ${input.date}, ${nextTarget.calories}, ${nextTarget.proteinGrams}, ${nextTarget.carbsGrams}, ${nextTarget.fatGrams}, ${nextHydration},
          ${nextConfigured}, ${nextSource}, ${nextConfiguredAt ?? null}, now()
        )
        ON CONFLICT (user_id, target_date) DO UPDATE
        SET calories = EXCLUDED.calories,
            protein_grams = EXCLUDED.protein_grams,
            carbs_grams = EXCLUDED.carbs_grams,
            fat_grams = EXCLUDED.fat_grams,
            hydration_goal_glasses = EXCLUDED.hydration_goal_glasses,
            calorie_target_configured = EXCLUDED.calorie_target_configured,
            calorie_target_source = EXCLUDED.calorie_target_source,
            calorie_target_configured_at = EXCLUDED.calorie_target_configured_at,
            updated_at = now()
        RETURNING *
      `;
      return mapDailyGoals(row);
    });
  }

  async listMeals(userId: string, limit = 25): Promise<Meal[]> {
    const rows = await this.sql`
      SELECT * FROM meals
      WHERE user_id = ${userId} AND deleted_at IS NULL
      ORDER BY occurred_at DESC
      LIMIT ${limit}
    `;
    return Promise.all(rows.map((row) => this.mapMeal(row)));
  }

  async getMeal(userId: string, mealId: string): Promise<Meal | undefined> {
    const [row] = await this.sql`SELECT * FROM meals WHERE id = ${mealId} AND user_id = ${userId} AND deleted_at IS NULL`;
    return row ? this.mapMeal(row) : undefined;
  }

  async createProposal(userId: string, proposal: Omit<MealProposal, "id" | "createdAt">): Promise<MealProposal> {
    return this.sql.begin(async (tx) => {
      const id = newId();
      const [row] = await tx`
        INSERT INTO meal_proposals (id, user_id, phrase, title, status, confidence, requires_confirmation, trusted_auto_commit_eligible, source, calories, protein_grams, carbs_grams, fat_grams)
        VALUES (${id}, ${userId}, ${proposal.phrase}, ${proposal.title}, ${proposal.status}, ${proposal.confidence}, ${proposal.requiresConfirmation}, ${proposal.trustedAutoCommitEligible}, ${proposal.source}, ${proposal.nutrition.calories}, ${proposal.nutrition.proteinGrams}, ${proposal.nutrition.carbsGrams}, ${proposal.nutrition.fatGrams})
        RETURNING *
      `;
      for (const item of proposal.items) {
        await insertProposalItem(tx, id, item);
      }
      return this.mapProposal(row, proposal.title, tx);
    });
  }

  async getProposal(userId: string, proposalId: string): Promise<MealProposal | undefined> {
    const [row] = await this.sql`SELECT * FROM meal_proposals WHERE id = ${proposalId} AND user_id = ${userId}`;
    return row ? this.mapProposal(row) : undefined;
  }

  async updateProposal(userId: string, proposal: MealProposal): Promise<MealProposal> {
    await this.sql.begin(async (tx) => {
      await tx`
        UPDATE meal_proposals
        SET status = ${proposal.status}, calories = ${proposal.nutrition.calories}, protein_grams = ${proposal.nutrition.proteinGrams}, carbs_grams = ${proposal.nutrition.carbsGrams}, fat_grams = ${proposal.nutrition.fatGrams}
        WHERE id = ${proposal.id} AND user_id = ${userId}
      `;
      await tx`DELETE FROM meal_proposal_items WHERE proposal_id = ${proposal.id}`;
      for (const item of proposal.items) await insertProposalItem(tx, proposal.id, item);
    });
    return proposal;
  }

  async createMealFromProposal(userId: string, proposal: MealProposal, occurredAt: string, items = proposal.items, mealLabel?: MealLabel | null): Promise<Meal> {
    return this.sql.begin(async (tx) => {
      const id = newId();
      const nutrition = sumNutrition(items);
      const [row] = await tx`
        INSERT INTO meals (id, user_id, proposal_id, title, occurred_at, meal_type, meal_type_label, calories, protein_grams, carbs_grams, fat_grams)
        VALUES (${id}, ${userId}, ${proposal.id}, ${proposal.title}, ${occurredAt}, ${mealLabel?.type ?? null}, ${mealLabel?.label ?? null}, ${nutrition.calories}, ${nutrition.proteinGrams}, ${nutrition.carbsGrams}, ${nutrition.fatGrams})
        RETURNING *
      `;
      for (const item of items) await insertMealItem(tx, id, item);
      await tx`UPDATE meal_proposals SET status = 'committed' WHERE id = ${proposal.id}`;
      return this.mapMeal(row, tx);
    });
  }

  async updateMeal(userId: string, meal: Meal): Promise<Meal> {
    await this.sql.begin(async (tx) => {
      await tx`
        UPDATE meals
        SET calories = ${meal.nutrition.calories}, protein_grams = ${meal.nutrition.proteinGrams}, carbs_grams = ${meal.nutrition.carbsGrams}, fat_grams = ${meal.nutrition.fatGrams}
        WHERE id = ${meal.id} AND user_id = ${userId}
      `;
      await tx`DELETE FROM meal_items WHERE meal_id = ${meal.id}`;
      for (const item of meal.items) await insertMealItem(tx, meal.id, item);
    });
    return meal;
  }

  async softDeleteMeal(userId: string, mealId: string): Promise<boolean> {
    const rows = await this.sql`UPDATE meals SET deleted_at = now() WHERE id = ${mealId} AND user_id = ${userId} AND deleted_at IS NULL RETURNING id`;
    return rows.length > 0;
  }

  async getDailySummary(userId: string, date: string) {
    const meals = (await this.listMeals(userId, 100)).filter((meal) => meal.occurredAt.slice(0, 10) === date);
    const consumed = meals.reduce((total, meal) => ({
      calories: total.calories + meal.nutrition.calories,
      proteinGrams: total.proteinGrams + meal.nutrition.proteinGrams,
      carbsGrams: total.carbsGrams + meal.nutrition.carbsGrams,
      fatGrams: total.fatGrams + meal.nutrition.fatGrams
    }), { calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0 });
    const goals = await this.getDailyGoals(userId, date);
    return {
      date,
      consumed,
      target: goals.target,
      remaining: subtractNutrition(goals.target, consumed),
      hydrationGoalGlasses: goals.hydrationGoalGlasses,
      calorieTargetConfigured: goals.calorieTargetConfigured,
      calorieTargetSource: goals.calorieTargetSource,
      meals
    };
  }

  async listTemplates(userId: string): Promise<MealTemplate[]> {
    const rows = await this.sql`SELECT * FROM meal_templates WHERE user_id = ${userId} AND deleted_at IS NULL`;
    return Promise.all(rows.map((row) => this.mapTemplate(row)));
  }

  async createTemplate(userId: string, input: Omit<MealTemplate, "id">): Promise<MealTemplate> {
    return this.sql.begin(async (tx) => {
      const id = newId();
      const [row] = await tx`
        INSERT INTO meal_templates (id, user_id, title, normalized_title, trusted_auto_commit_enabled, calories, protein_grams, carbs_grams, fat_grams)
        VALUES (${id}, ${userId}, ${input.title}, ${normalizeText(input.title)}, ${input.trustedAutoCommitEnabled}, ${input.nutrition.calories}, ${input.nutrition.proteinGrams}, ${input.nutrition.carbsGrams}, ${input.nutrition.fatGrams})
        RETURNING *
      `;
      for (const item of input.items) await insertTemplateItem(tx, id, item);
      for (const alias of input.aliases) {
        await tx`
          INSERT INTO food_memories (user_id, normalized_text, label, meal_template_id, confidence)
          VALUES (${userId}, ${normalizeText(alias)}, ${alias}, ${id}, 1)
          ON CONFLICT DO NOTHING
        `;
      }
      return this.mapTemplate(row);
    });
  }

  async updateTemplate(userId: string, template: MealTemplate): Promise<MealTemplate> {
    await this.sql.begin(async (tx) => {
      await tx`
        UPDATE meal_templates
        SET title = ${template.title}, normalized_title = ${normalizeText(template.title)}, trusted_auto_commit_enabled = ${template.trustedAutoCommitEnabled}, calories = ${template.nutrition.calories}, protein_grams = ${template.nutrition.proteinGrams}, carbs_grams = ${template.nutrition.carbsGrams}, fat_grams = ${template.nutrition.fatGrams}
        WHERE id = ${template.id} AND user_id = ${userId}
      `;
      await tx`DELETE FROM meal_template_items WHERE template_id = ${template.id}`;
      for (const item of template.items) await insertTemplateItem(tx, template.id, item);
    });
    return template;
  }

  async deleteTemplate(userId: string, templateId: string): Promise<boolean> {
    const rows = await this.sql`UPDATE meal_templates SET deleted_at = now() WHERE id = ${templateId} AND user_id = ${userId} RETURNING id`;
    return rows.length > 0;
  }

  async queryMemory(userId: string, normalizedText: string): Promise<MemoryMatch[]> {
    const rows = await this.sql`
      SELECT * FROM food_memories
      WHERE user_id = ${userId}
        AND (${normalizedText} = normalized_text OR ${normalizedText} LIKE '%' || normalized_text || '%' OR normalized_text LIKE '%' || ${normalizedText} || '%')
      ORDER BY CASE WHEN ${normalizedText} = normalized_text THEN 0 ELSE 1 END, usage_count DESC
      LIMIT 5
    `;
    return Promise.all(rows.map(async (row) => ({
      id: row.id,
      userId,
      label: row.label,
      normalizedText: row.normalized_text,
      confidence: normalizedText === row.normalized_text || normalizedText.includes(row.normalized_text) ? Number(row.confidence) : Math.min(Number(row.confidence), 0.82),
      template: row.meal_template_id ? await this.getTemplateById(userId, row.meal_template_id) : null
    })));
  }

  async createMemory(input: { userId: string; normalizedText: string; label: string; templateId?: string; confidence: number }): Promise<void> {
    await this.sql`
      INSERT INTO food_memories (user_id, normalized_text, label, meal_template_id, confidence)
      VALUES (${input.userId}, ${input.normalizedText}, ${input.label}, ${input.templateId ?? null}, ${input.confidence})
      ON CONFLICT DO NOTHING
    `;
  }

  async recordActionCall(input: Omit<ActionCallRecord, "id" | "createdAt">): Promise<ActionCallRecord> {
    const [row] = await this.sql`
      INSERT INTO action_calls (user_id, action_id, source, input_json, output_json, error_json, confirmation_status, trace_id, latency_ms)
      VALUES (${input.userId}, ${input.actionId}, ${input.source}, ${this.sql.json(input.input as never)}, ${this.sql.json((input.output ?? null) as never)}, ${this.sql.json((input.error ?? null) as never)}, ${input.confirmationStatus}, ${input.traceId}, ${input.latencyMs})
      RETURNING *
    `;
    return mapActionCall(row);
  }

  async recordAuditEvent(input: Omit<AuditEventRecord, "id" | "createdAt">): Promise<AuditEventRecord> {
    const [row] = await this.sql`
      INSERT INTO audit_events (user_id, event_type, metadata_json, trace_id)
      VALUES (${input.userId ?? null}, ${input.eventType}, ${this.sql.json(input.metadata as never)}, ${input.traceId})
      RETURNING *
    `;
    return mapAuditEvent(row);
  }

  async listActionCalls(userId: string): Promise<ActionCallRecord[]> {
    const rows = await this.sql`SELECT * FROM action_calls WHERE user_id = ${userId} ORDER BY created_at`;
    return rows.map(mapActionCall);
  }

  async listAuditEvents(userId: string): Promise<AuditEventRecord[]> {
    const rows = await this.sql`SELECT * FROM audit_events WHERE user_id = ${userId} ORDER BY created_at`;
    return rows.map(mapAuditEvent);
  }

  private async mapMeal(row: Record<string, unknown>, sqlClient: Sql | any = this.sql): Promise<Meal> {
    const items = await sqlClient`SELECT * FROM meal_items WHERE meal_id = ${row.id as string}`;
    return {
      id: row.id as string,
      title: row.title as string,
      occurredAt: toIso(row.occurred_at),
      mealLabel: mapMealLabel(row),
      nutrition: mapNutrition(row),
      items: items.map(mapItem),
      createdAt: toIso(row.created_at),
      deletedAt: row.deleted_at ? toIso(row.deleted_at) : undefined
    };
  }

  private async mapProposal(row: Record<string, unknown>, fallbackTitle = "Meal", sqlClient: Sql | any = this.sql): Promise<MealProposal> {
    const items = await sqlClient`SELECT * FROM meal_proposal_items WHERE proposal_id = ${row.id as string}`;
    return {
      id: row.id as string,
      phrase: row.phrase as string,
      title: row.title as string || fallbackTitle,
      status: row.status as MealProposal["status"],
      confidence: Number(row.confidence),
      requiresConfirmation: Boolean(row.requires_confirmation),
      trustedAutoCommitEligible: Boolean(row.trusted_auto_commit_eligible),
      source: row.source as string,
      nutrition: mapNutrition(row),
      items: items.map(mapItem),
      createdAt: toIso(row.created_at)
    };
  }

  private async mapTemplate(row: Record<string, unknown>): Promise<MealTemplate> {
    const items = await this.sql`SELECT * FROM meal_template_items WHERE template_id = ${row.id as string}`;
    const aliases = await this.sql`SELECT label FROM food_memories WHERE meal_template_id = ${row.id as string}`;
    return {
      id: row.id as string,
      title: row.title as string,
      trustedAutoCommitEnabled: Boolean(row.trusted_auto_commit_enabled),
      nutrition: mapNutrition(row),
      items: items.map(mapItem),
      aliases: aliases.map((alias) => alias.label as string)
    };
  }

  private async getTemplateById(userId: string, templateId: string): Promise<MealTemplate | null> {
    const [row] = await this.sql`SELECT * FROM meal_templates WHERE id = ${templateId} AND user_id = ${userId} AND deleted_at IS NULL`;
    return row ? this.mapTemplate(row) : null;
  }

  private async getCurrentGoals(userId: string, sqlClient: Sql | any = this.sql): Promise<Omit<DailyGoals, "date"> & { calorieTargetConfiguredAt?: string }> {
    const [row] = await sqlClient`SELECT * FROM nutrition_targets WHERE user_id = ${userId}`;
    if (!row) {
      return {
        target: { calories: 2200, proteinGrams: 160, carbsGrams: 240, fatGrams: 70 },
        hydrationGoalGlasses: 12,
        calorieTargetConfigured: false,
        calorieTargetSource: "default",
        calorieTargetConfiguredAt: undefined
      };
    }
    return {
      target: mapNutrition(row),
      hydrationGoalGlasses: Number(row.hydration_goal_glasses ?? 12),
      calorieTargetConfigured: Boolean(row.calorie_target_configured),
      calorieTargetSource: parseCalorieTargetSource(row.calorie_target_source),
      calorieTargetConfiguredAt: row.calorie_target_configured_at ? toIso(row.calorie_target_configured_at) : undefined
    };
  }

  private async mapFoodsWithPortions(rows: Record<string, unknown>[]): Promise<FoodItemRecord[]> {
    if (rows.length === 0) return [];
    const foods = rows.map(mapFood);
    const portions = await this.sql`
      SELECT *
      FROM food_portions
      WHERE food_item_id IN ${this.sql(foods.map((food) => food.id))}
      ORDER BY food_item_id, gram_weight, source_description
    `;
    const byFoodId = new Map<string, FoodPortionRecord[]>();
    for (const row of portions) {
      const portion = mapFoodPortion(row);
      const list = byFoodId.get(portion.foodItemId) ?? [];
      list.push(portion);
      byFoodId.set(portion.foodItemId, list);
    }
    return foods.map((food) => ({ ...food, portions: byFoodId.get(food.id) ?? [] }));
  }

  private async getPreferenceScoreMap(userId: string, foodIds: string[]): Promise<Map<string, number>> {
    if (foodIds.length === 0) return new Map();
    const rows = await this.sql`
      SELECT food_item_id, affinity_score
      FROM user_food_preferences
      WHERE user_id = ${userId}
        AND food_item_id IN ${this.sql(foodIds)}
    `;
    return new Map(rows.map((row) => [row.food_item_id as string, Number(row.affinity_score)]));
  }

  private mapUser(row: Record<string, unknown>, passwordHash: string | undefined, scopes: PermissionScope[]): StoredUser {
    return {
      id: row.id as string,
      email: row.email as string,
      displayName: row.display_name as string,
      trustedModeEnabled: Boolean(row.trusted_mode_enabled),
      createdAt: toIso(row.created_at),
      ...(passwordHash ? { passwordHash } : {}),
      scopes
    };
  }
}

function mapAuthIdentity(row: Record<string, unknown>): AuthIdentityRecord {
  return {
    id: row.id as string,
    userId: row.user_id as string,
    provider: row.provider as AuthIdentityProvider,
    providerUserId: row.provider_user_id as string,
    email: row.email as string,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at)
  };
}

async function insertProposalItem(sql: Sql | any, proposalId: string, item: MealItem) {
  await sql`
    INSERT INTO meal_proposal_items (
      proposal_id, name, quantity, unit, calories, protein_grams, carbs_grams, fat_grams,
      source, original_text, canonical_name, external_source, external_id, source_url, license, confidence, needs_review
    )
    VALUES (
      ${proposalId}, ${item.name}, ${item.quantity}, ${item.unit}, ${item.calories}, ${item.proteinGrams}, ${item.carbsGrams}, ${item.fatGrams},
      ${item.source}, ${item.originalText ?? null}, ${item.canonicalName ?? null}, ${item.externalSource ?? null}, ${item.externalId ?? null},
      ${item.sourceUrl ?? null}, ${item.license ?? null}, ${item.confidence ?? null}, ${item.needsReview ?? false}
    )
  `;
}

async function insertMealItem(sql: Sql | any, mealId: string, item: MealItem) {
  await sql`
    INSERT INTO meal_items (
      meal_id, name, quantity, unit, calories, protein_grams, carbs_grams, fat_grams,
      source, original_text, canonical_name, external_source, external_id, source_url, license, confidence, needs_review
    )
    VALUES (
      ${mealId}, ${item.name}, ${item.quantity}, ${item.unit}, ${item.calories}, ${item.proteinGrams}, ${item.carbsGrams}, ${item.fatGrams},
      ${item.source}, ${item.originalText ?? null}, ${item.canonicalName ?? null}, ${item.externalSource ?? null}, ${item.externalId ?? null},
      ${item.sourceUrl ?? null}, ${item.license ?? null}, ${item.confidence ?? null}, ${item.needsReview ?? false}
    )
  `;
}

async function insertTemplateItem(sql: Sql | any, templateId: string, item: MealItem) {
  await sql`
    INSERT INTO meal_template_items (
      template_id, name, quantity, unit, calories, protein_grams, carbs_grams, fat_grams,
      source, original_text, canonical_name, external_source, external_id, source_url, license, confidence, needs_review
    )
    VALUES (
      ${templateId}, ${item.name}, ${item.quantity}, ${item.unit}, ${item.calories}, ${item.proteinGrams}, ${item.carbsGrams}, ${item.fatGrams},
      ${item.source}, ${item.originalText ?? null}, ${item.canonicalName ?? null}, ${item.externalSource ?? null}, ${item.externalId ?? null},
      ${item.sourceUrl ?? null}, ${item.license ?? null}, ${item.confidence ?? null}, ${item.needsReview ?? false}
    )
  `;
}

function mapFood(row: Record<string, unknown>): FoodItemRecord {
  return {
    id: row.id as string,
    userId: optionalString(row.user_id),
    name: row.name as string,
    normalizedName: row.normalized_name as string,
    canonicalName: optionalString(row.canonical_name),
    brand: optionalString(row.brand),
    barcode: optionalString(row.barcode),
    source: row.source as string,
    externalSource: optionalString(row.external_source),
    externalId: optionalString(row.external_id),
    sourceUrl: optionalString(row.source_url),
    license: optionalString(row.license),
    fetchedAt: row.fetched_at ? toIso(row.fetched_at) : undefined,
    dataType: optionalString(row.data_type),
    foodCategory: optionalString(row.food_category),
    publicationDate: row.publication_date ? toDateOnly(row.publication_date) : undefined,
    ndbNumber: optionalString(row.ndb_number),
    foodKey: optionalString(row.food_key),
    ingredients: optionalString(row.ingredients),
    marketCountry: optionalString(row.market_country),
    householdServingFulltext: optionalString(row.household_serving_fulltext),
    nutrients: isRecord(row.nutrients_json) ? row.nutrients_json : undefined,
    portions: [],
    servingGrams: Number(row.serving_grams),
    calories: Number(row.calories),
    proteinGrams: Number(row.protein_grams),
    carbsGrams: Number(row.carbs_grams),
    fatGrams: Number(row.fat_grams)
  };
}

function mapFoodPortion(row: Record<string, unknown>): FoodPortionRecord {
  return {
    id: row.id as string,
    foodItemId: row.food_item_id as string,
    usdaPortionId: optionalString(row.usda_portion_id),
    amount: row.amount == null ? undefined : Number(row.amount),
    unit: optionalString(row.unit),
    modifier: optionalString(row.modifier),
    description: optionalString(row.description),
    gramWeight: Number(row.gram_weight),
    normalizedAliases: Array.isArray(row.normalized_aliases) ? row.normalized_aliases.map(String) : [],
    kind: (row.kind as string | undefined) ?? "serving",
    sourceDescription: row.source_description as string
  };
}

function mapEmbeddingModel(row: Record<string, unknown>): EmbeddingModelRecord {
  return {
    id: row.id as string,
    provider: row.provider as string,
    model: row.model as string,
    dimensions: Number(row.dimensions)
  };
}

function mapFoodItemEmbedding(row: Record<string, unknown>): FoodItemEmbeddingRecord {
  return {
    id: row.id as string,
    foodItemId: row.food_item_id as string,
    embeddingModelId: row.embedding_model_id as string,
    embeddedText: row.embedded_text as string,
    embeddedTextHash: row.embedded_text_hash as string,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at)
  };
}

function mapUserFoodPreference(row: Record<string, unknown>): UserFoodPreference {
  return {
    userId: row.user_id as string,
    foodItemId: row.food_item_id as string,
    affinityScore: Number(row.affinity_score),
    positiveFeedbackCount: Number(row.positive_feedback_count),
    negativeFeedbackCount: Number(row.negative_feedback_count),
    lastFeedbackAt: toIso(row.last_feedback_at),
    updatedAt: toIso(row.updated_at)
  };
}

function mapNutrition(row: Record<string, unknown>): NutritionSnapshot {
  return {
    calories: Number(row.calories),
    proteinGrams: Number(row.protein_grams),
    carbsGrams: Number(row.carbs_grams),
    fatGrams: Number(row.fat_grams)
  };
}

function mapDailyGoals(row: Record<string, unknown>): DailyGoals {
  return {
    date: toDateOnly(row.target_date),
    target: mapNutrition(row),
    hydrationGoalGlasses: Number(row.hydration_goal_glasses ?? 12),
    calorieTargetConfigured: Boolean(row.calorie_target_configured),
    calorieTargetSource: parseCalorieTargetSource(row.calorie_target_source)
  };
}

function parseCalorieTargetSource(value: unknown): CalorieTargetSource {
  return value === "manual" || value === "calculator" || value === "default" ? value : "default";
}

function mapMealLabel(row: Record<string, unknown>): MealLabel | null {
  const type = row.meal_type as MealLabel["type"] | null | undefined;
  const label = row.meal_type_label as string | null | undefined;
  return type && label ? { type, label } : null;
}

function mapItem(row: Record<string, unknown>): MealItem {
  return {
    name: row.name as string,
    quantity: Number(row.quantity),
    unit: row.unit as string,
    calories: Number(row.calories),
    proteinGrams: Number(row.protein_grams),
    carbsGrams: Number(row.carbs_grams),
    fatGrams: Number(row.fat_grams),
    source: (row.source as string | undefined) ?? "snapshot",
    originalText: row.original_text as string | undefined,
    canonicalName: row.canonical_name as string | undefined,
    externalSource: row.external_source as string | undefined,
    externalId: row.external_id as string | undefined,
    sourceUrl: row.source_url as string | undefined,
    license: row.license as string | undefined,
    confidence: row.confidence == null ? undefined : Number(row.confidence),
    needsReview: row.needs_review == null ? undefined : Boolean(row.needs_review)
  };
}

function mapSession(row: Record<string, unknown>): StoredSession {
  return {
    id: row.id as string,
    userId: row.user_id as string,
    refreshTokenHash: row.refresh_token_hash as string,
    expiresAt: toIso(row.expires_at),
    revokedAt: row.revoked_at ? toIso(row.revoked_at) : undefined,
    createdAt: toIso(row.created_at),
    rotatedAt: row.rotated_at ? toIso(row.rotated_at) : undefined
  };
}

function mapActionCall(row: Record<string, unknown>): ActionCallRecord {
  return {
    id: row.id as string,
    userId: row.user_id as string,
    actionId: row.action_id as string,
    source: row.source as string,
    input: row.input_json,
    output: row.output_json,
    error: row.error_json,
    confirmationStatus: row.confirmation_status as string,
    traceId: row.trace_id as string,
    latencyMs: Number(row.latency_ms),
    createdAt: toIso(row.created_at)
  };
}

function mapAuditEvent(row: Record<string, unknown>): AuditEventRecord {
  return {
    id: row.id as string,
    userId: row.user_id as string | undefined,
    eventType: row.event_type as string,
    metadata: row.metadata_json,
    traceId: row.trace_id as string,
    createdAt: toIso(row.created_at)
  };
}

function toIso(value: unknown): string {
  return value instanceof Date ? value.toISOString() : new Date(value as string).toISOString();
}

function toDateOnly(value: unknown): string {
  return value instanceof Date ? value.toISOString().slice(0, 10) : String(value).slice(0, 10);
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function previousDatesInWeek(date: string): string[] {
  const current = new Date(`${date}T00:00:00.000Z`);
  const weekday = current.getUTCDay() === 0 ? 7 : current.getUTCDay();
  const dates: string[] = [];
  for (let offset = weekday - 1; offset > 0; offset--) {
    const value = new Date(current);
    value.setUTCDate(current.getUTCDate() - offset);
    dates.push(value.toISOString().slice(0, 10));
  }
  return dates;
}

function stripFoodSearchCandidate(candidate: FoodSearchCandidate): FoodItemRecord {
  const {
    lexicalScore: _lexicalScore,
    vectorScore: _vectorScore,
    preferenceScore: _preferenceScore,
    finalScore: _finalScore,
    ...food
  } = candidate;
  return food;
}

function sanitizeLimit(limit?: number): number {
  if (!Number.isFinite(limit)) return DEFAULT_FOOD_SEARCH_LIMIT;
  return Math.max(1, Math.min(MAX_FOOD_SEARCH_LIMIT, Math.floor(limit as number)));
}

function clampScore(score: number): number {
  return clamp(score, 0, 1);
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, value));
}

function toVectorLiteral(embedding: number[]): string {
  if (embedding.length !== ACTIVE_EMBEDDING_MODEL.dimensions) {
    throw new Error("invalid_embedding_dimensions");
  }
  return `[${embedding.map((value) => {
    if (!Number.isFinite(value)) throw new Error("invalid_embedding_value");
    return String(value);
  }).join(",")}]`;
}

function foodFeedbackDelta(action: FoodFeedbackRecord["action"]): number {
  switch (action) {
    case "selected":
      return 1;
    case "logged":
      return 0.75;
    case "corrected":
      return 0.5;
    case "dismissed":
      return -0.5;
    case "rejected":
      return -1;
  }
}
