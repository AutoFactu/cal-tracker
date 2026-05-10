import { relations, sql } from "drizzle-orm";
import { boolean, customType, date, index, integer, jsonb, numeric, pgTable, primaryKey, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";

const vector = customType<{ data: number[]; driverData: string }>({
  dataType() {
    return "vector(1024)";
  }
});

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull(),
  displayName: text("display_name").notNull(),
  trustedModeEnabled: boolean("trusted_mode_enabled").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp("deleted_at", { withTimezone: true })
});

export const userCredentials = pgTable("user_credentials", {
  userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  passwordHash: text("password_hash").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
});

export const authSessions = pgTable("auth_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  refreshTokenHash: text("refresh_token_hash").notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  revokedAt: timestamp("revoked_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  rotatedAt: timestamp("rotated_at", { withTimezone: true })
});

export const nutritionTargets = pgTable("nutrition_targets", {
  userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  calories: integer("calories").notNull(),
  proteinGrams: numeric("protein_grams", { precision: 10, scale: 2 }).notNull(),
  carbsGrams: numeric("carbs_grams", { precision: 10, scale: 2 }).notNull(),
  fatGrams: numeric("fat_grams", { precision: 10, scale: 2 }).notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
});

export const foodItems = pgTable("food_items", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  normalizedName: text("normalized_name").notNull(),
  canonicalName: text("canonical_name"),
  brand: text("brand"),
  barcode: text("barcode"),
  source: text("source").notNull(),
  externalSource: text("external_source"),
  externalId: text("external_id"),
  sourceUrl: text("source_url"),
  license: text("license"),
  fetchedAt: timestamp("fetched_at", { withTimezone: true }),
  dataType: text("data_type"),
  foodCategory: text("food_category"),
  publicationDate: date("publication_date"),
  ndbNumber: text("ndb_number"),
  foodKey: text("food_key"),
  ingredients: text("ingredients"),
  marketCountry: text("market_country"),
  householdServingFulltext: text("household_serving_fulltext"),
  nutrientsJson: jsonb("nutrients_json").notNull().default(sql`'{}'::jsonb`),
  servingGrams: numeric("serving_grams", { precision: 10, scale: 2 }).notNull().default("100"),
  calories: integer("calories").notNull(),
  proteinGrams: numeric("protein_grams", { precision: 10, scale: 2 }).notNull(),
  carbsGrams: numeric("carbs_grams", { precision: 10, scale: 2 }).notNull(),
  fatGrams: numeric("fat_grams", { precision: 10, scale: 2 }).notNull()
});

export const foodPortions = pgTable("food_portions", {
  id: uuid("id").primaryKey().defaultRandom(),
  foodItemId: uuid("food_item_id").notNull().references(() => foodItems.id, { onDelete: "cascade" }),
  usdaPortionId: text("usda_portion_id"),
  amount: numeric("amount", { precision: 10, scale: 4 }),
  unit: text("unit"),
  modifier: text("modifier"),
  description: text("description"),
  gramWeight: numeric("gram_weight", { precision: 10, scale: 4 }).notNull(),
  normalizedAliases: text("normalized_aliases").array().notNull().default(sql`'{}'::text[]`),
  kind: text("kind").notNull().default("serving"),
  sourceDescription: text("source_description").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
});

export const referenceDataImports = pgTable("reference_data_imports", {
  id: uuid("id").primaryKey().defaultRandom(),
  source: text("source").notNull(),
  targetSchema: text("target_schema").notNull(),
  manifestSha256: text("manifest_sha256").notNull(),
  manifestJson: jsonb("manifest_json").notNull(),
  foodCount: integer("food_count").notNull(),
  portionCount: integer("portion_count").notNull(),
  importedAt: timestamp("imported_at", { withTimezone: true }).notNull().defaultNow()
});

export const mealProposals = pgTable("meal_proposals", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  phrase: text("phrase").notNull(),
  title: text("title").notNull(),
  status: text("status").notNull(),
  confidence: numeric("confidence", { precision: 5, scale: 4 }).notNull(),
  requiresConfirmation: boolean("requires_confirmation").notNull().default(true),
  trustedAutoCommitEligible: boolean("trusted_auto_commit_eligible").notNull().default(false),
  source: text("source").notNull(),
  calories: integer("calories").notNull(),
  proteinGrams: numeric("protein_grams", { precision: 10, scale: 2 }).notNull(),
  carbsGrams: numeric("carbs_grams", { precision: 10, scale: 2 }).notNull(),
  fatGrams: numeric("fat_grams", { precision: 10, scale: 2 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
});

export const meals = pgTable("meals", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  proposalId: uuid("proposal_id").references(() => mealProposals.id),
  title: text("title").notNull(),
  occurredAt: timestamp("occurred_at", { withTimezone: true }).notNull(),
  mealType: text("meal_type"),
  mealTypeLabel: text("meal_type_label"),
  calories: integer("calories").notNull(),
  proteinGrams: numeric("protein_grams", { precision: 10, scale: 2 }).notNull(),
  carbsGrams: numeric("carbs_grams", { precision: 10, scale: 2 }).notNull(),
  fatGrams: numeric("fat_grams", { precision: 10, scale: 2 }).notNull(),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
});

export const mealTemplates = pgTable("meal_templates", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  title: text("title").notNull(),
  normalizedTitle: text("normalized_title").notNull(),
  trustedAutoCommitEnabled: boolean("trusted_auto_commit_enabled").notNull().default(false),
  calories: integer("calories").notNull(),
  proteinGrams: numeric("protein_grams", { precision: 10, scale: 2 }).notNull(),
  carbsGrams: numeric("carbs_grams", { precision: 10, scale: 2 }).notNull(),
  fatGrams: numeric("fat_grams", { precision: 10, scale: 2 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp("deleted_at", { withTimezone: true })
});

export const foodMemories = pgTable("food_memories", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  normalizedText: text("normalized_text").notNull(),
  label: text("label").notNull(),
  mealTemplateId: uuid("meal_template_id").references(() => mealTemplates.id),
  usageCount: integer("usage_count").notNull().default(0),
  confidence: numeric("confidence", { precision: 5, scale: 4 }).notNull().default("1")
});

export const embeddingModels = pgTable("embedding_models", {
  id: uuid("id").primaryKey().defaultRandom(),
  provider: text("provider").notNull(),
  model: text("model").notNull(),
  dimensions: integer("dimensions").notNull()
}, (table) => [
  index("embedding_models_lookup_idx").on(table.provider, table.model, table.dimensions)
]);

export const foodMemoryEmbeddings = pgTable("food_memory_embeddings", {
  id: uuid("id").primaryKey().defaultRandom(),
  foodMemoryId: uuid("food_memory_id").notNull().references(() => foodMemories.id, { onDelete: "cascade" }),
  embeddingModelId: uuid("embedding_model_id").notNull().references(() => embeddingModels.id),
  embedding: vector("embedding").notNull()
});

export const foodItemEmbeddings = pgTable("food_item_embeddings", {
  id: uuid("id").primaryKey().defaultRandom(),
  foodItemId: uuid("food_item_id").notNull().references(() => foodItems.id, { onDelete: "cascade" }),
  embeddingModelId: uuid("embedding_model_id").notNull().references(() => embeddingModels.id),
  embeddedText: text("embedded_text").notNull(),
  embeddedTextHash: text("embedded_text_hash").notNull(),
  embedding: vector("embedding").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
}, (table) => [
  uniqueIndex("food_item_embeddings_food_model_unique").on(table.foodItemId, table.embeddingModelId),
  index("food_item_embeddings_model_idx").on(table.embeddingModelId),
  index("food_item_embeddings_hash_idx").on(table.embeddingModelId, table.embeddedTextHash)
]);

export const userFoodFeedbackEvents = pgTable("user_food_feedback_events", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  foodItemId: uuid("food_item_id").notNull().references(() => foodItems.id, { onDelete: "cascade" }),
  queryText: text("query_text").notNull(),
  normalizedQuery: text("normalized_query").notNull(),
  action: text("action").notNull(),
  metadataJson: jsonb("metadata_json").notNull().default(sql`'{}'::jsonb`),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
}, (table) => [
  index("user_food_feedback_events_user_created_idx").on(table.userId, table.createdAt),
  index("user_food_feedback_events_user_food_idx").on(table.userId, table.foodItemId, table.createdAt),
  index("user_food_feedback_events_query_idx").on(table.userId, table.normalizedQuery)
]);

export const userFoodPreferences = pgTable("user_food_preferences", {
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  foodItemId: uuid("food_item_id").notNull().references(() => foodItems.id, { onDelete: "cascade" }),
  affinityScore: numeric("affinity_score", { precision: 8, scale: 4 }).notNull().default("0"),
  positiveFeedbackCount: integer("positive_feedback_count").notNull().default(0),
  negativeFeedbackCount: integer("negative_feedback_count").notNull().default(0),
  lastFeedbackAt: timestamp("last_feedback_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
}, (table) => [
  primaryKey({ columns: [table.userId, table.foodItemId] }),
  index("user_food_preferences_user_score_idx").on(table.userId, table.affinityScore, table.updatedAt),
  index("user_food_preferences_food_idx").on(table.foodItemId)
]);

export const actionCalls = pgTable("action_calls", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  actionId: text("action_id").notNull(),
  source: text("source").notNull(),
  inputJson: jsonb("input_json").notNull(),
  outputJson: jsonb("output_json"),
  errorJson: jsonb("error_json"),
  confirmationStatus: text("confirmation_status").notNull(),
  traceId: text("trace_id").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  latencyMs: integer("latency_ms").notNull()
});

export const auditEvents = pgTable("audit_events", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
  eventType: text("event_type").notNull(),
  metadataJson: jsonb("metadata_json").notNull().default(sql`'{}'::jsonb`),
  traceId: text("trace_id").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
});

export const userRelations = relations(users, ({ one, many }) => ({
  credential: one(userCredentials),
  sessions: many(authSessions),
  meals: many(meals)
}));
