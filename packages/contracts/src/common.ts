import { z } from "zod";

export const isoDateTimeSchema = z.string().datetime();
export const uuidSchema = z.string().uuid();

export const nutritionSnapshotSchema = z.object({
  calories: z.number().int().nonnegative(),
  proteinGrams: z.number().nonnegative(),
  carbsGrams: z.number().nonnegative(),
  fatGrams: z.number().nonnegative()
});

export const mealItemSchema = z.object({
  id: uuidSchema.optional(),
  name: z.string().min(1),
  quantity: z.number().positive(),
  unit: z.string().min(1),
  calories: z.number().int().nonnegative(),
  proteinGrams: z.number().nonnegative(),
  carbsGrams: z.number().nonnegative(),
  fatGrams: z.number().nonnegative(),
  source: z.string().default("backend_estimate")
});

export const mealProposalSchema = z.object({
  id: uuidSchema,
  phrase: z.string(),
  title: z.string(),
  status: z.enum(["pending", "committed", "rejected", "corrected"]),
  confidence: z.number().min(0).max(1),
  requiresConfirmation: z.boolean(),
  trustedAutoCommitEligible: z.boolean(),
  source: z.string(),
  nutrition: nutritionSnapshotSchema,
  items: z.array(mealItemSchema),
  createdAt: isoDateTimeSchema
});

export const mealSchema = z.object({
  id: uuidSchema,
  title: z.string(),
  occurredAt: isoDateTimeSchema,
  nutrition: nutritionSnapshotSchema,
  items: z.array(mealItemSchema),
  createdAt: isoDateTimeSchema,
  deletedAt: isoDateTimeSchema.nullable().optional()
});

export const dailySummarySchema = z.object({
  date: z.string(),
  consumed: nutritionSnapshotSchema,
  target: nutritionSnapshotSchema,
  remaining: nutritionSnapshotSchema,
  meals: z.array(mealSchema)
});

export const mealTemplateSchema = z.object({
  id: uuidSchema,
  title: z.string(),
  trustedAutoCommitEnabled: z.boolean(),
  nutrition: nutritionSnapshotSchema,
  items: z.array(mealItemSchema),
  aliases: z.array(z.string()).default([])
});

export type NutritionSnapshot = z.infer<typeof nutritionSnapshotSchema>;
export type MealItem = z.infer<typeof mealItemSchema>;
export type MealProposal = z.infer<typeof mealProposalSchema>;
export type Meal = z.infer<typeof mealSchema>;
export type DailySummary = z.infer<typeof dailySummarySchema>;
export type MealTemplate = z.infer<typeof mealTemplateSchema>;
