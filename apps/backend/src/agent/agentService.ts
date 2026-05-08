import {
  type ActionContext,
  type DailySummary,
  type Meal,
  type NutritionSnapshot,
  type MealProposal,
  actionDefinitions
} from "@cal-tracker/contracts";
import { ActionExecutor, type ExecuteActionResult } from "../actions/executor.js";
import type { AgentMessage, AgentToolCall, AgentToolDecision, ChatAgentProvider } from "./chatAgentProvider.js";
import { buildSystemMessage } from "./agentMessages.js";
import { buildToolSchemas } from "./toolSchemas.js";
import { filterToolsByPolicy } from "./agentPolicy.js";

export type AgentRunResult =
  | { kind: "proposal"; proposal: MealProposal; message: string }
  | { kind: "meal_committed"; meal: Meal; message: string }
  | { kind: "summary"; summary: DailySummary; message: string }
  | { kind: "remaining_targets"; remaining: NutritionSnapshot; message: string }
  | { kind: "history"; meals: Meal[]; message: string }
  | { kind: "confirmation_required"; actionId: string; input: unknown; message: string }
  | { kind: "meal_deleted"; message: string }
  | { kind: "clarification_required"; message: string; options?: unknown[] };

export class AgentService {
  constructor(
    private readonly agentProvider: ChatAgentProvider,
    private readonly actionExecutor: ActionExecutor,
    private readonly model: string
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
        parameters: buildToolSchemas().find((t) => t.function.name === action.id)?.function.parameters ?? {},
      },
    }));

    const decision = await this.agentProvider.runWithTools({
      messages,
      tools,
      model: this.model,
      traceId: context.traceId,
    });

    if (decision.toolCalls.length === 0) {
      return {
        kind: "clarification_required",
        message: "I'm not sure what you'd like to do. Could you rephrase?",
      };
    }

    const toolCall = decision.toolCalls[0]!;
    const actionId = toolCall.function.name;

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
        message: "I didn't understand the parameters for that action. Could you rephrase?",
      };
    }

    const result = await this.actionExecutor.execute(actionId, parsedInput, {
      ...context,
      source: "internal_agent",
    });

    return this.mapResult(actionId, result, text);
  }

  private mapResult(actionId: string, result: ExecuteActionResult, originalText: string): AgentRunResult {
    const output = result.output as Record<string, unknown>;

    switch (actionId) {
      case "propose_meal_log": {
        const proposal = output.proposal as MealProposal;
        const meal = output.autoCommittedMeal as Meal | undefined;
        if (meal) {
          return { kind: "meal_committed", meal, message: "Meal logged from trusted template." };
        }
        return { kind: "proposal", proposal, message: "Meal proposal created." };
      }
      case "get_daily_summary":
        return { kind: "summary", summary: output.summary as DailySummary, message: "Here is your daily summary." };
      case "get_remaining_targets":
        return { kind: "remaining_targets", remaining: output.remaining as NutritionSnapshot, message: "Here are your remaining targets." };
      case "get_meal_history":
        return { kind: "history", meals: output.meals as Meal[], message: "Here is your meal history." };
      case "delete_meal": {
        const confirmationRequired = (output as { confirmationRequired?: boolean }).confirmationRequired;
        if (confirmationRequired) {
          return { kind: "confirmation_required", actionId: "delete_meal", input: output, message: "Please confirm deletion." };
        }
        return { kind: "meal_deleted", message: "Meal deleted." };
      }
      default:
        return { kind: "clarification_required", message: "Action completed but I don't know how to display the result." };
    }
  }
}
