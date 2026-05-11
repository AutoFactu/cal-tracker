import { actionDefinitions } from "@cal-tracker/contracts";
import { zodToJsonSchema } from "zod-to-json-schema";
import type { AgentToolDefinition } from "./chatAgentProvider.js";

let cachedToolSchemas: AgentToolDefinition[] | undefined;

export function buildToolSchemas(): AgentToolDefinition[] {
  cachedToolSchemas ??= actionDefinitions.map((action) => ({
    type: "function",
    function: {
      name: action.id,
      description: `${action.title}. ${action.description}`,
      parameters: zodToJsonSchema(action.inputSchema) as Record<string, unknown>,
    },
  }));
  return cachedToolSchemas;
}
