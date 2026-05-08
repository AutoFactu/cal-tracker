import { relations, sql } from "drizzle-orm";
import { boolean, customType, integer, jsonb, numeric, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

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
  brand: text("brand"),
  barcode: text("barcode"),
  source: text("source").notNull(),
  servingGrams: numeric("serving_grams", { precision: 10, scale: 2 }).notNull().default("100"),
  calories: integer("calories").notNull(),
  proteinGrams: numeric("protein_grams", { precision: 10, scale: 2 }).notNull(),
  carbsGrams: numeric("carbs_grams", { precision: 10, scale: 2 }).notNull(),
  fatGrams: numeric("fat_grams", { precision: 10, scale: 2 }).notNull()
});

export const mealProposals = pgTable("meal_proposals", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  phrase: text("phrase").notNull(),
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
});

export const foodMemoryEmbeddings = pgTable("food_memory_embeddings", {
  id: uuid("id").primaryKey().defaultRandom(),
  foodMemoryId: uuid("food_memory_id").notNull().references(() => foodMemories.id, { onDelete: "cascade" }),
  embeddingModelId: uuid("embedding_model_id").notNull().references(() => embeddingModels.id),
  embedding: vector("embedding").notNull()
});

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
