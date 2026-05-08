import { z } from "zod";
import {
  dailySummarySchema,
  foodCandidateSchema,
  mealItemSchema,
  mealProposalSchema,
  mealSchema,
  mealTemplateSchema,
  nutritionSnapshotSchema,
  uuidSchema
} from "./common.js";

export const errorResponseSchema = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    traceId: z.string().optional(),
    details: z.unknown().optional()
  })
});

export const executeActionRequestSchema = z.object({
  input: z.unknown().default({}),
  source: z.enum(["flutter", "internal_agent", "android_appfunctions", "ios_appintents", "rest"]).default("rest")
});

export const executeActionResponseSchema = z.object({
  actionCallId: uuidSchema,
  confirmationRequired: z.boolean(),
  output: z.unknown()
});

export const agentRunRequestSchema = z.object({
  text: z.string().min(1),
  source: z.enum(["flutter", "ios_appintents", "android_appfunctions"]).default("flutter")
});

export const agentRunResponseSchema = z.object({
  kind: z.enum([
    "proposal",
    "meal_committed",
    "meal_corrected",
    "summary",
    "remaining_targets",
    "history",
    "food_memory",
    "nutrition_search",
    "templates",
    "template_saved",
    "template_deleted",
    "confirmation_required",
    "meal_deleted",
    "clarification_required"
  ]),
  message: z.string(),
  proposal: mealProposalSchema.optional(),
  meal: mealSchema.optional(),
  summary: dailySummarySchema.optional(),
  remaining: nutritionSnapshotSchema.optional(),
  meals: z.array(mealSchema).optional(),
  items: z.array(mealItemSchema).optional(),
  templates: z.array(mealTemplateSchema).optional(),
  template: mealTemplateSchema.optional(),
  matches: z.array(z.unknown()).optional(),
  deleted: z.boolean().optional(),
  actionId: z.string().optional(),
  input: z.unknown().optional(),
  options: z.array(z.union([foodCandidateSchema, z.unknown()])).optional()
});

export const transcriptionResponseSchema = z.object({
  transcript: z.string(),
  provider: z.string(),
  model: z.string(),
  traceId: z.string()
});

export const settingsUpdateSchema = z.object({
  trustedModeEnabled: z.boolean()
});

export const dashboardResponseSchema = z.object({
  summary: dailySummarySchema
});

export const mealHistoryResponseSchema = z.object({
  meals: z.array(mealSchema)
});

export const templatesResponseSchema = z.object({
  templates: z.array(mealTemplateSchema)
});
