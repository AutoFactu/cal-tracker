import postgres, { type Sql } from "postgres";
import { defaultUserScopes, type Meal, type MealItem, type MealProposal, type MealTemplate, type NutritionSnapshot, type PermissionScope } from "@cal-tracker/contracts";
import { newId } from "../utils/ids.js";
import { normalizeText } from "../utils/normalize.js";
import { subtractNutrition, sumNutrition } from "../utils/nutrition.js";
import type {
  ActionCallRecord,
  AppRepository,
  AuditEventRecord,
  FoodItemRecord,
  MemoryMatch,
  StoredSession,
  StoredUser
} from "./types.js";

export class PostgresRepository implements AppRepository {
  private readonly sql: Sql;

  constructor(databaseUrl: string) {
    this.sql = postgres(databaseUrl);
  }

  async createUser(input: { email: string; displayName: string; passwordHash: string; scopes: PermissionScope[] }): Promise<StoredUser> {
    const [row] = await this.sql`
      INSERT INTO users (email, display_name)
      VALUES (${input.email.toLowerCase()}, ${input.displayName})
      RETURNING id, email, display_name, trusted_mode_enabled, created_at
    `;
    await this.sql`INSERT INTO user_credentials (user_id, password_hash) VALUES (${row.id}, ${input.passwordHash})`;
    await this.sql`
      INSERT INTO nutrition_targets (user_id, calories, protein_grams, carbs_grams, fat_grams)
      VALUES (${row.id}, 2200, 160, 240, 70)
    `;
    const user = this.mapUser(row, input.passwordHash, input.scopes);
    await this.createDefaultTemplate(user.id);
    return user;
  }

  async findUserByEmail(email: string): Promise<StoredUser | undefined> {
    const [row] = await this.sql`
      SELECT u.id, u.email, u.display_name, u.trusted_mode_enabled, u.created_at, c.password_hash
      FROM users u
      JOIN user_credentials c ON c.user_id = u.id
      WHERE lower(u.email) = lower(${email}) AND u.deleted_at IS NULL
    `;
    return row ? this.mapUser(row, row.password_hash, defaultUserScopes) : undefined;
  }

  async findUserById(id: string): Promise<StoredUser | undefined> {
    const [row] = await this.sql`
      SELECT u.id, u.email, u.display_name, u.trusted_mode_enabled, u.created_at, c.password_hash
      FROM users u
      JOIN user_credentials c ON c.user_id = u.id
      WHERE u.id = ${id} AND u.deleted_at IS NULL
    `;
    return row ? this.mapUser(row, row.password_hash, defaultUserScopes) : undefined;
  }

  async updateTrustedMode(userId: string, enabled: boolean): Promise<StoredUser> {
    await this.sql`UPDATE users SET trusted_mode_enabled = ${enabled} WHERE id = ${userId}`;
    const user = await this.findUserById(userId);
    if (!user) throw new Error("user_not_found");
    return user;
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
    return rows.map(mapFood);
  }

  async searchFoods(userId: string, query: string, barcode?: string): Promise<FoodItemRecord[]> {
    const normalized = normalizeText(query);
    const rows = barcode
      ? await this.sql`SELECT * FROM food_items WHERE (user_id IS NULL OR user_id = ${userId}) AND barcode = ${barcode}`
      : await this.sql`
          SELECT * FROM food_items
          WHERE (user_id IS NULL OR user_id = ${userId})
            AND (${normalized} LIKE '%' || normalized_name || '%' OR normalized_name LIKE '%' || ${normalized} || '%')
        `;
    return rows.map(mapFood);
  }

  async getNutritionTarget(userId: string): Promise<NutritionSnapshot> {
    const [row] = await this.sql`SELECT * FROM nutrition_targets WHERE user_id = ${userId}`;
    return row ? mapNutrition(row) : { calories: 2200, proteinGrams: 160, carbsGrams: 240, fatGrams: 70 };
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
        INSERT INTO meal_proposals (id, user_id, phrase, status, confidence, requires_confirmation, trusted_auto_commit_eligible, source, calories, protein_grams, carbs_grams, fat_grams)
        VALUES (${id}, ${userId}, ${proposal.phrase}, ${proposal.status}, ${proposal.confidence}, ${proposal.requiresConfirmation}, ${proposal.trustedAutoCommitEligible}, ${proposal.source}, ${proposal.nutrition.calories}, ${proposal.nutrition.proteinGrams}, ${proposal.nutrition.carbsGrams}, ${proposal.nutrition.fatGrams})
        RETURNING *
      `;
      for (const item of proposal.items) {
        await insertProposalItem(tx, id, item);
      }
      return this.mapProposal(row, proposal.title);
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

  async createMealFromProposal(userId: string, proposal: MealProposal, occurredAt: string, items = proposal.items): Promise<Meal> {
    return this.sql.begin(async (tx) => {
      const id = newId();
      const nutrition = sumNutrition(items);
      const [row] = await tx`
        INSERT INTO meals (id, user_id, proposal_id, title, occurred_at, calories, protein_grams, carbs_grams, fat_grams)
        VALUES (${id}, ${userId}, ${proposal.id}, ${proposal.title}, ${occurredAt}, ${nutrition.calories}, ${nutrition.proteinGrams}, ${nutrition.carbsGrams}, ${nutrition.fatGrams})
        RETURNING *
      `;
      for (const item of items) await insertMealItem(tx, id, item);
      await tx`UPDATE meal_proposals SET status = 'committed' WHERE id = ${proposal.id}`;
      return this.mapMeal(row);
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
    const target = await this.getNutritionTarget(userId);
    return { date, consumed, target, remaining: subtractNutrition(target, consumed), meals };
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

  private async createDefaultTemplate(userId: string): Promise<void> {
    const foods = await this.listFoods(userId);
    const items: MealItem[] = [
      { name: "Oats", quantity: 60, unit: "g", calories: 233, proteinGrams: 10.1, carbsGrams: 39.8, fatGrams: 4.1, source: foods.find((food) => food.normalizedName === "oats")?.source ?? "generic_usda" },
      { name: "Milk", quantity: 250, unit: "ml", calories: 122, proteinGrams: 8.1, carbsGrams: 12, fatGrams: 4.8, source: "generic_usda" },
      { name: "Egg", quantity: 2, unit: "egg", calories: 144, proteinGrams: 12.6, carbsGrams: 0.8, fatGrams: 9.6, source: "generic_usda" }
    ];
    await this.createTemplate(userId, {
      title: "Usual breakfast",
      trustedAutoCommitEnabled: false,
      nutrition: sumNutrition(items),
      items,
      aliases: ["usual breakfast", "normal breakfast"]
    });
  }

  private async mapMeal(row: Record<string, unknown>): Promise<Meal> {
    const items = await this.sql`SELECT * FROM meal_items WHERE meal_id = ${row.id as string}`;
    return {
      id: row.id as string,
      title: row.title as string,
      occurredAt: toIso(row.occurred_at),
      nutrition: mapNutrition(row),
      items: items.map(mapItem),
      createdAt: toIso(row.created_at),
      deletedAt: row.deleted_at ? toIso(row.deleted_at) : undefined
    };
  }

  private async mapProposal(row: Record<string, unknown>, fallbackTitle = "Meal"): Promise<MealProposal> {
    const items = await this.sql`SELECT * FROM meal_proposal_items WHERE proposal_id = ${row.id as string}`;
    return {
      id: row.id as string,
      phrase: row.phrase as string,
      title: fallbackTitle,
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

  private mapUser(row: Record<string, unknown>, passwordHash: string, scopes: PermissionScope[]): StoredUser {
    return {
      id: row.id as string,
      email: row.email as string,
      displayName: row.display_name as string,
      trustedModeEnabled: Boolean(row.trusted_mode_enabled),
      createdAt: toIso(row.created_at),
      passwordHash,
      scopes
    };
  }
}

async function insertProposalItem(sql: Sql | any, proposalId: string, item: MealItem) {
  await sql`
    INSERT INTO meal_proposal_items (proposal_id, name, quantity, unit, calories, protein_grams, carbs_grams, fat_grams)
    VALUES (${proposalId}, ${item.name}, ${item.quantity}, ${item.unit}, ${item.calories}, ${item.proteinGrams}, ${item.carbsGrams}, ${item.fatGrams})
  `;
}

async function insertMealItem(sql: Sql | any, mealId: string, item: MealItem) {
  await sql`
    INSERT INTO meal_items (meal_id, name, quantity, unit, calories, protein_grams, carbs_grams, fat_grams)
    VALUES (${mealId}, ${item.name}, ${item.quantity}, ${item.unit}, ${item.calories}, ${item.proteinGrams}, ${item.carbsGrams}, ${item.fatGrams})
  `;
}

async function insertTemplateItem(sql: Sql | any, templateId: string, item: MealItem) {
  await sql`
    INSERT INTO meal_template_items (template_id, name, quantity, unit, calories, protein_grams, carbs_grams, fat_grams)
    VALUES (${templateId}, ${item.name}, ${item.quantity}, ${item.unit}, ${item.calories}, ${item.proteinGrams}, ${item.carbsGrams}, ${item.fatGrams})
  `;
}

function mapFood(row: Record<string, unknown>): FoodItemRecord {
  return {
    id: row.id as string,
    userId: row.user_id as string | undefined,
    name: row.name as string,
    normalizedName: row.normalized_name as string,
    brand: row.brand as string | undefined,
    barcode: row.barcode as string | undefined,
    source: row.source as string,
    servingGrams: Number(row.serving_grams),
    calories: Number(row.calories),
    proteinGrams: Number(row.protein_grams),
    carbsGrams: Number(row.carbs_grams),
    fatGrams: Number(row.fat_grams)
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

function mapItem(row: Record<string, unknown>): MealItem {
  return {
    name: row.name as string,
    quantity: Number(row.quantity),
    unit: row.unit as string,
    calories: Number(row.calories),
    proteinGrams: Number(row.protein_grams),
    carbsGrams: Number(row.carbs_grams),
    fatGrams: Number(row.fat_grams),
    source: "snapshot"
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
