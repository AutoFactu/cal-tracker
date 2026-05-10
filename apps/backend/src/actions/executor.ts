import {
  actionById,
  actionDefinitions,
  commitMealInputSchema,
  correctMealInputSchema,
  createMealProposalFromItemsInputSchema,
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
  type FoodCandidateGroup,
  type Meal,
  type MealItem,
  type MealLabel,
  type MealProposal,
} from "@cal-tracker/contracts";
import type { AppConfig } from "../config/env.js";
import type {
  MealTextResolutionProvider,
  NutritionProvider,
} from "../nutrition/provider.js";
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
  constructor(
    public readonly code: string,
    message = code,
  ) {
    super(message);
  }
}

export class ActionExecutor {
  constructor(
    private readonly config: AppConfig,
    private readonly repository: AppRepository,
    private readonly nutritionProvider: NutritionProvider,
    private readonly memoryRetrievalService?: MemoryRetrievalService,
  ) {}

  listActions() {
    return actionDefinitions.map(
      ({
        inputSchema: _inputSchema,
        outputSchema: _outputSchema,
        ...metadata
      }) => metadata,
    );
  }

  async execute(
    actionId: string,
    rawInput: unknown,
    context: ActionContext,
  ): Promise<ExecuteActionResult> {
    const definition = actionById.get(actionId);
    if (!definition)
      throw new ActionExecutionError(
        "unknown_action",
        `Unknown action: ${actionId}`,
      );
    if (!context.scopes.includes(definition.permissionScope)) {
      throw new ActionExecutionError(
        "permission_denied",
        `Missing scope: ${definition.permissionScope}`,
      );
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
        latencyMs: Date.now() - started,
      });
      actionCallId = call.id;
      if (definition.sideEffect !== "none") {
        await this.repository.recordAuditEvent({
          userId: context.actorUserId,
          eventType: `action.${actionId}`,
          metadata: { input, output },
          traceId: context.traceId,
        });
      }
      return {
        actionCallId,
        confirmationRequired: definition.confirmationPolicy === "required",
        output,
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
        latencyMs: Date.now() - started,
      });
      throw Object.assign(
        error instanceof Error ? error : new Error("action_failed"),
        { actionCallId: call.id },
      );
    }
  }

  private async dispatch(
    actionId: string,
    input: unknown,
    context: ActionContext,
  ): Promise<unknown> {
    switch (actionId) {
      case "query_food_memory": {
        const parsed = queryFoodMemoryInputSchema.parse(input);
        const memory = await this.queryMemory(context.actorUserId, parsed.text);
        const matches = memory.matches;
        return {
          matches,
          needsClarification:
            matches.length === 0 || matches[0]!.confidence < 0.75,
        };
      }
      case "search_nutrition_database": {
        const parsed = searchNutritionDatabaseInputSchema.parse(input);
        return {
          items: await this.nutritionProvider.search(
            context.actorUserId,
            parsed.query,
            parsed.barcode,
          ),
        };
      }
      case "propose_meal_log":
        return this.proposeMeal(input, context);
      case "create_meal_proposal_from_items":
        return this.createMealProposalFromItems(input, context);
      case "commit_meal": {
        const parsed = commitMealInputSchema.parse(input);
        const proposal = await this.requireProposal(
          context.actorUserId,
          parsed.proposalId,
        );
        const mealLabel = normalizeMealLabel(parsed.mealLabel);
        const meal = await this.repository.createMealFromProposal(
          context.actorUserId,
          proposal,
          parsed.occurredAt ?? new Date().toISOString(),
          parsed.items,
          mealLabel,
        );
        return { meal };
      }
      case "correct_meal":
        return this.correctMeal(input, context);
      case "delete_meal": {
        const parsed = deleteMealInputSchema.parse(input);
        if (parsed.confirmationToken !== "DELETE") {
          return { deleted: false, confirmationRequired: true };
        }
        return {
          deleted: await this.repository.softDeleteMeal(
            context.actorUserId,
            parsed.mealId,
          ),
          confirmationRequired: false,
        };
      }
      case "get_daily_summary": {
        const parsed = getDailySummaryInputSchema.parse(input);
        return {
          summary: await this.repository.getDailySummary(
            context.actorUserId,
            parsed.date ?? today(),
          ),
        };
      }
      case "get_remaining_targets": {
        const parsed = getRemainingTargetsInputSchema.parse(input);
        const summary = await this.repository.getDailySummary(
          context.actorUserId,
          parsed.date ?? today(),
        );
        return { remaining: summary.remaining };
      }
      case "get_meal_history": {
        const parsed = getMealHistoryInputSchema.parse(input);
        return {
          meals: await this.repository.listMeals(
            context.actorUserId,
            parsed.limit,
          ),
        };
      }
      case "get_usual_meals":
        return {
          templates: await this.repository.listTemplates(context.actorUserId),
        };
      case "create_meal_template": {
        const parsed = createMealTemplateInputSchema.parse(input);
        const nutrition = sumNutrition(parsed.items);
        const template = await this.repository.createTemplate(
          context.actorUserId,
          { ...parsed, nutrition },
        );
        return { template };
      }
      case "update_meal_template": {
        const parsed = updateMealTemplateInputSchema.parse(input);
        const templates = await this.repository.listTemplates(
          context.actorUserId,
        );
        const existing = templates.find(
          (template) => template.id === parsed.templateId,
        );
        if (!existing) throw new ActionExecutionError("template_not_found");
        const items = parsed.items ?? existing.items;
        const template = await this.repository.updateTemplate(
          context.actorUserId,
          {
            ...existing,
            ...parsed,
            id: parsed.templateId,
            items,
            aliases: parsed.aliases ?? existing.aliases,
            trustedAutoCommitEnabled:
              parsed.trustedAutoCommitEnabled ??
              existing.trustedAutoCommitEnabled,
            nutrition: sumNutrition(items),
          },
        );
        return { template };
      }
      case "delete_meal_template": {
        const parsed = deleteMealTemplateInputSchema.parse(input);
        return {
          deleted: await this.repository.deleteTemplate(
            context.actorUserId,
            parsed.templateId,
          ),
        };
      }
      default:
        throw new ActionExecutionError("unimplemented_action", actionId);
    }
  }

  private async proposeMeal(
    input: unknown,
    context: ActionContext,
  ): Promise<Record<string, unknown>> {
    const parsed = proposeMealLogInputSchema.parse(input);
    const normalized = normalizeText(parsed.text);
    const memories = (await this.queryMemory(context.actorUserId, normalized))
      .matches;
    const memory = memories[0];
    const template = memory?.template ?? null;
    const fromTemplate = Boolean(
      template && memory && memory.confidence >= 0.75,
    );
    const resolution = template
      ? null
      : await this.resolveMealText(context.actorUserId, parsed.text);
    if (resolution?.clarificationRequired) {
      const unsupportedUnitMessage = unsupportedUnitClarification(
        resolution.candidateGroups,
      );
      return {
        clarificationRequired: true,
        resolvedItems: resolution.items,
        unresolvedMentions: resolution.unresolvedMentions,
        options: resolution.candidateGroups,
        message:
          unsupportedUnitMessage ??
          (resolution.unresolvedMentions.length > 0
            ? "I could not confidently match every ingredient. Please choose a food match or rephrase the meal."
            : "I could not identify the ingredients in that meal. Please add quantities and food names."),
      };
    }
    const items: MealItem[] = template
      ? template.items
      : (resolution?.items ??
        (await this.nutritionProvider.estimateMeal(
          context.actorUserId,
          parsed.text,
        )));
    const nutrition = sumNutrition(items);
    const trustedAutoCommitEligible = false;
    const proposal = await this.repository.createProposal(context.actorUserId, {
      phrase: parsed.text,
      title: template?.title ?? inferTitle(parsed.text, items),
      status: "pending",
      confidence: fromTemplate ? memory!.confidence : 0.68,
      requiresConfirmation: true,
      trustedAutoCommitEligible,
      source: fromTemplate ? "user_template" : "backend_estimate",
      nutrition,
      items,
    });

    return { proposal, autoCommittedMeal: null };
  }

  private async createMealProposalFromItems(
    input: unknown,
    context: ActionContext,
  ): Promise<Record<string, unknown>> {
    const parsed = createMealProposalFromItemsInputSchema.parse(input);
    const proposal = await this.repository.createProposal(context.actorUserId, {
      phrase: parsed.phrase,
      title: parsed.title ?? inferTitle(parsed.phrase, parsed.items),
      status: "pending",
      confidence: Math.min(
        ...parsed.items.map((item) => item.confidence ?? 0.78),
        0.9,
      ),
      requiresConfirmation: true,
      trustedAutoCommitEligible: false,
      source: "backend_estimate",
      nutrition: sumNutrition(parsed.items),
      items: parsed.items,
    });
    return { proposal };
  }

  private async resolveMealText(userId: string, text: string) {
    if (hasMealTextResolution(this.nutritionProvider)) {
      return this.nutritionProvider.resolveMealText(userId, text);
    }
    return {
      items: await this.nutritionProvider.estimateMeal(userId, text),
      unresolvedMentions: [],
      candidateGroups: [],
      clarificationRequired: false,
    };
  }

  private async correctMeal(input: unknown, context: ActionContext) {
    const parsed = correctMealInputSchema.parse(input);
    if (parsed.proposalId) {
      const proposal = await this.requireProposal(
        context.actorUserId,
        parsed.proposalId,
      );
      const corrected = await this.repository.updateProposal(
        context.actorUserId,
        {
          ...proposal,
          status: "corrected",
          items: parsed.items,
          nutrition: sumNutrition(parsed.items),
        },
      );
      return { proposal: corrected };
    }

    const meal = await this.repository.getMeal(
      context.actorUserId,
      parsed.mealId!,
    );
    if (!meal) throw new ActionExecutionError("meal_not_found");
    const corrected = await this.repository.updateMeal(context.actorUserId, {
      ...meal,
      items: parsed.items,
      nutrition: sumNutrition(parsed.items),
    });
    return { meal: corrected };
  }

  private async requireProposal(
    userId: string,
    proposalId: string,
  ): Promise<MealProposal> {
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

function hasMealTextResolution(
  provider: NutritionProvider,
): provider is MealTextResolutionProvider {
  return (
    typeof (provider as Partial<MealTextResolutionProvider>).resolveMealText ===
    "function"
  );
}

function unsupportedUnitClarification(
  candidateGroups: FoodCandidateGroup[],
): string | undefined {
  const group = candidateGroups.find(
    (candidateGroup) =>
      candidateGroup.reason === "unsupported_unit" ||
      candidateGroup.reason === "ambiguous_portion",
  );
  if (!group) return undefined;
  const mention = group.mention;
  if (group.reason === "ambiguous_portion") {
    return `Which ${mention.canonicalEnglishName} portion did you mean?`;
  }
  const unit = mention.rawUnitText ?? mention.unit;
  const unitAlreadyNamesFood =
    normalizeText(unit) === normalizeText(mention.canonicalEnglishName);
  const phrase =
    `${mention.quantity} ${unit}${unitAlreadyNamesFood ? "" : ` ${mention.canonicalEnglishName}`}`
      .replace(/\s+/g, " ")
      .trim();
  const alternatives = group.portionOptions?.length
    ? " Choose one of the supported portions or use grams."
    : "";
  return `I could not validate "${phrase}" as a supported portion.${alternatives || ` Please use grams, cups, or another serving size for ${mention.canonicalEnglishName}.`}`;
}

function inferTitle(text: string, items: MealItem[]): string {
  if (items.length === 1) return items[0]!.name;
  if (
    normalizeText(text).includes("chicken") &&
    normalizeText(text).includes("rice")
  )
    return "Chicken and rice";
  if (items.length === 2) return `${items[0]!.name} and ${items[1]!.name}`;
  return "Meal";
}

const fixedMealLabels: Record<Exclude<MealLabel["type"], "other">, string> = {
  breakfast: "Breakfast",
  lunch: "Lunch",
  dinner: "Dinner",
  snack: "Snack",
  pre_workout: "Pre-workout",
  post_workout: "Post-workout",
};

function normalizeMealLabel(
  input: { type: MealLabel["type"]; label?: string } | null | undefined,
): MealLabel | null {
  if (!input) return null;
  if (input.type === "other") {
    const label = input.label?.trim();
    if (!label) {
      throw new ActionExecutionError(
        "invalid_meal_label",
        "Other meal labels require a custom label.",
      );
    }
    return { type: "other", label };
  }
  return { type: input.type, label: fixedMealLabels[input.type] };
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}
