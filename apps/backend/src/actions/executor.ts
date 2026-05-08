import {
  actionById,
  actionDefinitions,
  commitMealInputSchema,
  correctMealInputSchema,
  createMealTemplateInputSchema,
  deleteMealInputSchema,
  deleteMealTemplateInputSchema,
  getDailySummaryInputSchema,
  getMealHistoryInputSchema,
  getRemainingTargetsInputSchema,
  proposeMealLogInputSchema,
  queryFoodMemoryInputSchema,
  searchNutritionDatabaseInputSchema,
  updateMealTemplateInputSchema,
  type ActionContext,
  type Meal,
  type MealItem,
  type MealProposal
} from "@cal-tracker/contracts";
import type { AppConfig } from "../config/env.js";
import type { NutritionProvider } from "../nutrition/provider.js";
import type { AppRepository } from "../repository/types.js";
import type { MemoryRetrievalService } from "../memory/retrieval.js";
import { newId } from "../utils/ids.js";
import { normalizeText } from "../utils/normalize.js";
import { sumNutrition } from "../utils/nutrition.js";

export type ExecuteActionResult = {
  actionCallId: string;
  confirmationRequired: boolean;
  output: unknown;
};

export class ActionExecutionError extends Error {
  constructor(public readonly code: string, message = code) {
    super(message);
  }
}

export class ActionExecutor {
  constructor(
    private readonly config: AppConfig,
    private readonly repository: AppRepository,
    private readonly nutritionProvider: NutritionProvider,
    private readonly memoryRetrievalService?: MemoryRetrievalService
  ) {}

  listActions() {
    return actionDefinitions.map(({ inputSchema: _inputSchema, outputSchema: _outputSchema, ...metadata }) => metadata);
  }

  async execute(actionId: string, rawInput: unknown, context: ActionContext): Promise<ExecuteActionResult> {
    const definition = actionById.get(actionId);
    if (!definition) throw new ActionExecutionError("unknown_action", `Unknown action: ${actionId}`);
    if (!context.scopes.includes(definition.permissionScope)) {
      throw new ActionExecutionError("permission_denied", `Missing scope: ${definition.permissionScope}`);
    }

    const started = Date.now();
    const input = definition.inputSchema.parse(rawInput);
    let actionCallId = newId();

    try {
      const output = await this.dispatch(actionId, input, context);
      const call = await this.repository.recordActionCall({
        userId: context.actorUserId,
        actionId,
        source: context.source,
        input,
        output,
        confirmationStatus: definition.confirmationPolicy,
        traceId: context.traceId,
        latencyMs: Date.now() - started
      });
      actionCallId = call.id;
      if (definition.sideEffect !== "none") {
        await this.repository.recordAuditEvent({
          userId: context.actorUserId,
          eventType: `action.${actionId}`,
          metadata: { input, output },
          traceId: context.traceId
        });
      }
      return {
        actionCallId,
        confirmationRequired: definition.confirmationPolicy === "required",
        output
      };
    } catch (error) {
      const call = await this.repository.recordActionCall({
        userId: context.actorUserId,
        actionId,
        source: context.source,
        input,
        error: error instanceof Error ? { message: error.message } : error,
        confirmationStatus: "error",
        traceId: context.traceId,
        latencyMs: Date.now() - started
      });
      throw Object.assign(error instanceof Error ? error : new Error("action_failed"), { actionCallId: call.id });
    }
  }

  private async dispatch(actionId: string, input: unknown, context: ActionContext): Promise<unknown> {
    switch (actionId) {
      case "query_food_memory": {
        const parsed = queryFoodMemoryInputSchema.parse(input);
        const memory = await this.queryMemory(context.actorUserId, parsed.text);
        const matches = memory.matches;
        return { matches, needsClarification: matches.length === 0 || matches[0]!.confidence < 0.75 };
      }
      case "search_nutrition_database": {
        const parsed = searchNutritionDatabaseInputSchema.parse(input);
        return { items: await this.nutritionProvider.search(context.actorUserId, parsed.query, parsed.barcode) };
      }
      case "propose_meal_log":
        return this.proposeMeal(input, context);
      case "commit_meal": {
        const parsed = commitMealInputSchema.parse(input);
        const proposal = await this.requireProposal(context.actorUserId, parsed.proposalId);
        const meal = await this.repository.createMealFromProposal(context.actorUserId, proposal, parsed.occurredAt ?? new Date().toISOString(), parsed.items);
        return { meal };
      }
      case "correct_meal":
        return this.correctMeal(input, context);
      case "delete_meal": {
        const parsed = deleteMealInputSchema.parse(input);
        if (parsed.confirmationToken !== "DELETE") {
          return { deleted: false, confirmationRequired: true };
        }
        return { deleted: await this.repository.softDeleteMeal(context.actorUserId, parsed.mealId), confirmationRequired: false };
      }
      case "get_daily_summary": {
        const parsed = getDailySummaryInputSchema.parse(input);
        return { summary: await this.repository.getDailySummary(context.actorUserId, parsed.date ?? today()) };
      }
      case "get_remaining_targets": {
        const parsed = getRemainingTargetsInputSchema.parse(input);
        const summary = await this.repository.getDailySummary(context.actorUserId, parsed.date ?? today());
        return { remaining: summary.remaining };
      }
      case "get_meal_history": {
        const parsed = getMealHistoryInputSchema.parse(input);
        return { meals: await this.repository.listMeals(context.actorUserId, parsed.limit) };
      }
      case "get_usual_meals":
        return { templates: await this.repository.listTemplates(context.actorUserId) };
      case "create_meal_template": {
        const parsed = createMealTemplateInputSchema.parse(input);
        const nutrition = sumNutrition(parsed.items);
        const template = await this.repository.createTemplate(context.actorUserId, { ...parsed, nutrition });
        return { template };
      }
      case "update_meal_template": {
        const parsed = updateMealTemplateInputSchema.parse(input);
        const templates = await this.repository.listTemplates(context.actorUserId);
        const existing = templates.find((template) => template.id === parsed.templateId);
        if (!existing) throw new ActionExecutionError("template_not_found");
        const items = parsed.items ?? existing.items;
        const template = await this.repository.updateTemplate(context.actorUserId, {
          ...existing,
          ...parsed,
          id: parsed.templateId,
          items,
          aliases: parsed.aliases ?? existing.aliases,
          trustedAutoCommitEnabled: parsed.trustedAutoCommitEnabled ?? existing.trustedAutoCommitEnabled,
          nutrition: sumNutrition(items)
        });
        return { template };
      }
      case "delete_meal_template": {
        const parsed = deleteMealTemplateInputSchema.parse(input);
        return { deleted: await this.repository.deleteTemplate(context.actorUserId, parsed.templateId) };
      }
      default:
        throw new ActionExecutionError("unimplemented_action", actionId);
    }
  }

  private async proposeMeal(input: unknown, context: ActionContext): Promise<{ proposal: MealProposal; autoCommittedMeal: Meal | null }> {
    const parsed = proposeMealLogInputSchema.parse(input);
    const normalized = normalizeText(parsed.text);
    const memories = (await this.queryMemory(context.actorUserId, normalized)).matches;
    const memory = memories[0];
    const template = memory?.template ?? null;
    const fromTemplate = Boolean(template && memory && memory.confidence >= 0.75);
    const items: MealItem[] = template ? template.items : await this.nutritionProvider.estimateMeal(context.actorUserId, parsed.text);
    const nutrition = sumNutrition(items);
    const trustedAutoCommitEligible = Boolean(
      template &&
      memory &&
      context.trustedModeEnabled &&
      template.trustedAutoCommitEnabled &&
      memory.confidence >= this.config.TRUSTED_AUTO_COMMIT_THRESHOLD &&
      items.every((item) => item.source !== "llm_estimate")
    );
    const proposal = await this.repository.createProposal(context.actorUserId, {
      phrase: parsed.text,
      title: template?.title ?? inferTitle(parsed.text, items),
      status: "pending",
      confidence: fromTemplate ? memory!.confidence : 0.68,
      requiresConfirmation: !trustedAutoCommitEligible,
      trustedAutoCommitEligible,
      source: fromTemplate ? "user_template" : "backend_estimate",
      nutrition,
      items
    });

    let autoCommittedMeal: Meal | null = null;
    if (trustedAutoCommitEligible) {
      autoCommittedMeal = await this.repository.createMealFromProposal(
        context.actorUserId,
        proposal,
        parsed.occurredAt ?? new Date().toISOString()
      );
      await this.repository.recordAuditEvent({
        userId: context.actorUserId,
        eventType: "trusted_auto_commit.meal_committed",
        metadata: { proposalId: proposal.id, mealId: autoCommittedMeal.id, phrase: parsed.text, confidence: memory!.confidence },
        traceId: context.traceId
      });
    }

    return { proposal, autoCommittedMeal };
  }

  private async correctMeal(input: unknown, context: ActionContext) {
    const parsed = correctMealInputSchema.parse(input);
    if (parsed.proposalId) {
      const proposal = await this.requireProposal(context.actorUserId, parsed.proposalId);
      const correctedItems = parsed.items ?? applyCorrection(proposal.items, parsed.correctionText);
      const corrected = await this.repository.updateProposal(context.actorUserId, {
        ...proposal,
        status: "corrected",
        items: correctedItems,
        nutrition: sumNutrition(correctedItems)
      });
      return { proposal: corrected };
    }

    const meal = await this.repository.getMeal(context.actorUserId, parsed.mealId!);
    if (!meal) throw new ActionExecutionError("meal_not_found");
    const correctedItems = parsed.items ?? applyCorrection(meal.items, parsed.correctionText);
    const corrected = await this.repository.updateMeal(context.actorUserId, {
      ...meal,
      items: correctedItems,
      nutrition: sumNutrition(correctedItems)
    });
    return { meal: corrected };
  }

  private async requireProposal(userId: string, proposalId: string): Promise<MealProposal> {
    const proposal = await this.repository.getProposal(userId, proposalId);
    if (!proposal) throw new ActionExecutionError("proposal_not_found");
    return proposal;
  }

  private async queryMemory(userId: string, text: string) {
    if (this.memoryRetrievalService) {
      return this.memoryRetrievalService.query(userId, text);
    }
    return {
      matches: await this.repository.queryMemory(userId, normalizeText(text)),
      vectorUnavailable: true,
    };
  }
}

function applyCorrection(items: MealItem[], correctionText: string): MealItem[] {
  const normalized = normalizeText(correctionText);
  const chickenGrams = /chicken\D{0,20}(\d{2,4})\s*(g|gram|grams)|(\d{2,4})\s*(g|gram|grams)\D{0,20}chicken/.exec(normalized);
  const grams = chickenGrams ? Number(chickenGrams[1] ?? chickenGrams[3]) : undefined;
  if (!grams) return items;
  return items.map((item) => {
    if (!normalizeText(item.name).includes("chicken")) return item;
    const factor = grams / item.quantity;
    return {
      ...item,
      quantity: grams,
      calories: Math.round(item.calories * factor),
      proteinGrams: Math.round(item.proteinGrams * factor * 10) / 10,
      carbsGrams: Math.round(item.carbsGrams * factor * 10) / 10,
      fatGrams: Math.round(item.fatGrams * factor * 10) / 10
    };
  });
}

function inferTitle(text: string, items: MealItem[]): string {
  if (items.length === 1) return items[0]!.name;
  if (normalizeText(text).includes("chicken") && normalizeText(text).includes("rice")) return "Chicken and rice";
  return "Meal";
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}
