import {
  type ActionContext,
  type DailySummary,
  type Meal,
  type MealItem,
  type NutritionSnapshot,
  type MealProposal,
  type MealTemplate,
  actionDefinitions,
} from "@cal-tracker/contracts";
import {
  ActionExecutor,
  type ExecuteActionResult,
} from "../actions/executor.js";
import type {
  AgentMessage,
  AgentToolCall,
  AgentToolDecision,
  ChatAgentProvider,
} from "./chatAgentProvider.js";
import { buildSystemMessage } from "./agentMessages.js";
import { buildToolSchemas } from "./toolSchemas.js";
import { filterToolsByPolicy } from "./agentPolicy.js";

export type AgentRunResult =
  | {
      kind: "proposal";
      proposal: MealProposal;
      message: string;
      options?: unknown[];
    }
  | { kind: "meal_committed"; meal: Meal; message: string; options?: unknown[] }
  | {
      kind: "meal_corrected";
      meal?: Meal;
      proposal?: MealProposal;
      message: string;
    }
  | { kind: "summary"; summary: DailySummary; message: string }
  | { kind: "remaining_targets"; remaining: NutritionSnapshot; message: string }
  | { kind: "history"; meals: Meal[]; message: string }
  | {
      kind: "food_memory";
      matches: unknown[];
      message: string;
      options?: unknown[];
    }
  | {
      kind: "nutrition_search";
      items: MealItem[];
      message: string;
      options?: unknown[];
    }
  | { kind: "templates"; templates: MealTemplate[]; message: string }
  | { kind: "template_saved"; template: MealTemplate; message: string }
  | { kind: "template_deleted"; deleted: boolean; message: string }
  | {
      kind: "confirmation_required";
      actionId: string;
      input: unknown;
      message: string;
    }
  | { kind: "meal_deleted"; message: string }
  | {
      kind: "clarification_required";
      message: string;
      options?: unknown[];
      resolvedItems?: MealItem[];
    };

export class AgentService {
  constructor(
    private readonly agentProvider: ChatAgentProvider,
    private readonly actionExecutor: ActionExecutor,
    private readonly model: string,
  ) {}

  async run(text: string, context: ActionContext): Promise<AgentRunResult> {
    const messages: AgentMessage[] = [
      buildSystemMessage(context),
      { role: "user", content: text },
    ];

    const allowedActions = filterToolsByPolicy(actionDefinitions, context);
    const tools = allowedActions.map((action) => ({
      type: "function" as const,
      function: {
        name: action.id,
        description: `${action.title}. ${action.description}`,
        parameters:
          buildToolSchemas().find((t) => t.function.name === action.id)
            ?.function.parameters ?? {},
      },
    }));

    let decision: AgentToolDecision;
    try {
      decision = await this.agentProvider.runWithTools({
        messages,
        tools,
        model: this.model,
        traceId: context.traceId,
      });
    } catch {
      const fallbackToolCall = fallbackToolCallForText(text);
      if (fallbackToolCall) {
        const result = await this.actionExecutor.execute(
          fallbackToolCall.function.name,
          JSON.parse(fallbackToolCall.function.arguments),
          {
            ...context,
            source: "internal_agent",
          },
        );
        return this.mapResult(fallbackToolCall.function.name, result, text);
      }
      return {
        kind: "clarification_required",
        message:
          "The agent provider is unavailable. Please rephrase or try again.",
      };
    }

    if (decision.toolCalls.length === 0) {
      const fallbackToolCall = fallbackToolCallForText(text);
      if (fallbackToolCall) {
        const result = await this.actionExecutor.execute(
          fallbackToolCall.function.name,
          JSON.parse(fallbackToolCall.function.arguments),
          {
            ...context,
            source: "internal_agent",
          },
        );
        return this.mapResult(fallbackToolCall.function.name, result, text);
      }
      return {
        kind: "clarification_required",
        message: "I'm not sure what you'd like to do. Could you rephrase?",
      };
    }

    const toolCall = decision.toolCalls[0]!;
    let actionId = toolCall.function.name;

    if (!allowedActions.some((a) => a.id === actionId)) {
      return {
        kind: "clarification_required",
        message: `I'm not able to perform that action (${actionId}).`,
      };
    }

    let parsedInput: unknown;
    try {
      parsedInput = JSON.parse(toolCall.function.arguments);
    } catch {
      return {
        kind: "clarification_required",
        message:
          "I didn't understand the parameters for that action. Could you rephrase?",
      };
    }

    if (isMealLoggingIntent(text) && actionId !== "propose_meal_log") {
      actionId = "propose_meal_log";
      parsedInput = { text };
    }

    const result = await this.actionExecutor.execute(actionId, parsedInput, {
      ...context,
      source: "internal_agent",
    });

    return this.mapResult(actionId, result, text);
  }

  private mapResult(
    actionId: string,
    result: ExecuteActionResult,
    originalText: string,
  ): AgentRunResult {
    const output = result.output as Record<string, unknown>;

    switch (actionId) {
      case "query_food_memory": {
        const matches = (output.matches as unknown[]) ?? [];
        return {
          kind: "food_memory",
          matches,
          options: matches,
          message:
            matches.length > 0
              ? "I found matching food memories."
              : "I couldn't find matching food memories.",
        };
      }
      case "search_nutrition_database": {
        const items = (output.items as MealItem[]) ?? [];
        const options =
          (output.candidateGroups as unknown[] | undefined) ??
          (output.candidates as unknown[] | undefined) ??
          [];
        return {
          kind: "nutrition_search",
          items,
          options,
          message:
            items.length > 0
              ? "I found matching nutrition items."
              : "I couldn't find matching nutrition items.",
        };
      }
      case "propose_meal_log": {
        if (output.clarificationRequired) {
          const options = output.options as unknown[] | undefined;
          const resolvedItems = output.resolvedItems as MealItem[] | undefined;
          return {
            kind: "clarification_required",
            options,
            resolvedItems,
            message:
              typeof output.message === "string"
                ? output.message
                : "I could not confidently match every ingredient.",
          };
        }
        const proposal = output.proposal as MealProposal;
        const meal = output.autoCommittedMeal as Meal | undefined;
        const options =
          (output.options as unknown[] | undefined) ??
          (output.candidateGroups as unknown[] | undefined) ??
          [];
        if (meal) {
          return {
            kind: "meal_committed",
            meal,
            options,
            message: "Meal logged from trusted template.",
          };
        }
        return {
          kind: "proposal",
          proposal,
          options,
          message: "Meal proposal created.",
        };
      }
      case "create_meal_proposal_from_items":
        return {
          kind: "proposal",
          proposal: output.proposal as MealProposal,
          message: "Meal proposal created.",
        };
      case "commit_meal":
        return {
          kind: "meal_committed",
          meal: output.meal as Meal,
          message: "Meal logged.",
        };
      case "correct_meal": {
        const meal = output.meal as Meal | undefined;
        const proposal = output.proposal as MealProposal | undefined;
        if (meal)
          return { kind: "meal_corrected", meal, message: "Meal corrected." };
        return {
          kind: "meal_corrected",
          proposal,
          message: "Meal proposal corrected.",
        };
      }
      case "get_daily_summary":
        return {
          kind: "summary",
          summary: output.summary as DailySummary,
          message: "Here is your daily summary.",
        };
      case "get_remaining_targets":
        return {
          kind: "remaining_targets",
          remaining: output.remaining as NutritionSnapshot,
          message: "Here are your remaining targets.",
        };
      case "get_meal_history":
        return {
          kind: "history",
          meals: output.meals as Meal[],
          message: "Here is your meal history.",
        };
      case "get_usual_meals":
        return {
          kind: "templates",
          templates: output.templates as MealTemplate[],
          message: "Here are your usual meals.",
        };
      case "create_meal_template":
        return {
          kind: "template_saved",
          template: output.template as MealTemplate,
          message: "Usual meal created.",
        };
      case "update_meal_template":
        return {
          kind: "template_saved",
          template: output.template as MealTemplate,
          message: "Usual meal updated.",
        };
      case "delete_meal_template":
        return {
          kind: "template_deleted",
          deleted: Boolean(output.deleted),
          message: output.deleted
            ? "Usual meal deleted."
            : "Usual meal was not found.",
        };
      case "delete_meal": {
        const confirmationRequired = (
          output as { confirmationRequired?: boolean }
        ).confirmationRequired;
        if (confirmationRequired) {
          return {
            kind: "confirmation_required",
            actionId: "delete_meal",
            input: { ...output, originalText },
            message: "Please confirm deletion.",
          };
        }
        return { kind: "meal_deleted", message: "Meal deleted." };
      }
      default:
        return {
          kind: "clarification_required",
          message:
            "Action completed but I don't know how to display the result.",
        };
    }
  }
}

function isMealLoggingIntent(text: string): boolean {
  const normalized = normalizeIntentText(text);

  if (/^(how|cuanto|cuanta|cuantas|cuantos|que|what)\b/.test(normalized))
    return false;
  if (
    /\b(delete|remove|borrar|eliminar|corrige|correct|corregir)\b/.test(
      normalized,
    )
  )
    return false;
  return /\b(log|add|ate|had|consumed|record|registrar|registro|anade|anadir|agrega|agregar|apunta|apuntar|comi|comido|tome|consumi|desayuno|almuerzo|comida|cena|merienda|snack)\b/.test(
    normalized,
  );
}

function fallbackToolCallForText(text: string): AgentToolCall | null {
  const normalized = normalizeIntentText(text);
  if (isMealLoggingIntent(text)) return toolCall("propose_meal_log", { text });
  if (
    /\b(remaining|left|quedan|restan|calorias restantes|calories left)\b/.test(
      normalized,
    )
  ) {
    return toolCall("get_remaining_targets", {});
  }
  if (/\b(summary|resumen|today|hoy)\b/.test(normalized))
    return toolCall("get_daily_summary", {});
  if (/\b(history|historial|ultimas comidas|recent meals)\b/.test(normalized))
    return toolCall("get_meal_history", { limit: 10 });
  if (
    /\b(usual meals|templates|plantillas|comidas habituales|habituales)\b/.test(
      normalized,
    )
  )
    return toolCall("get_usual_meals", {});

  const nutritionSearch =
    /\b(?:search|buscar|lookup|consulta|consultar)\b.*\b(?:nutrition|nutricion|food|alimento|database|base)\b(?:\s+(?:for|de|para))?\s*(.*)$/.exec(
      normalized,
    );
  if (nutritionSearch?.[1])
    return toolCall("search_nutrition_database", {
      query: nutritionSearch[1].trim(),
    });

  return null;
}

function toolCall(name: string, input: unknown): AgentToolCall {
  return {
    id: `fallback_${name}`,
    type: "function",
    function: {
      name,
      arguments: JSON.stringify(input),
    },
  };
}

function normalizeIntentText(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
