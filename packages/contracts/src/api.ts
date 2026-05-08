import { z } from "zod";
import {
  dailySummarySchema,
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
    "summary",
    "remaining_targets",
    "history",
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
  actionId: z.string().optional(),
  input: z.unknown().optional(),
  options: z.array(z.unknown()).optional()
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
