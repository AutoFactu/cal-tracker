export type AgentMessage =
  | { role: "system"; content: string }
  | { role: "user"; content: string }
  | { role: "assistant"; content: string; toolCalls?: AgentToolCall[] }
  | { role: "tool"; toolCallId: string; content: string };

export type AgentToolCall = {
  id: string;
  type: "function";
  function: {
    name: string;
    arguments: string;
  };
};

export type AgentToolDefinition = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

export type AgentToolDecision = {
  toolCalls: AgentToolCall[];
  rawResponse: unknown;
};

export interface ChatAgentProvider {
  runWithTools(input: {
    messages: AgentMessage[];
    tools: AgentToolDefinition[];
    model: string;
    traceId: string;
  }): Promise<AgentToolDecision>;
}

export class RemoteChatAgentProvider implements ChatAgentProvider {
  constructor(
    private readonly apiKey: string,
    private readonly baseUrl: string = "https://openrouter.ai/api/v1",
    private readonly timeoutMs = 10000
  ) {}

  async runWithTools(input: {
    messages: AgentMessage[];
    tools: AgentToolDefinition[];
    model: string;
    traceId: string;
  }): Promise<AgentToolDecision> {
    const res = await fetch(`${this.baseUrl}/chat/completions`, {
      method: "POST",
      signal: timeoutSignal(this.timeoutMs),
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": process.env.APP_BASE_URL ?? "",
        "X-Title": "Cal Tracker Agent",
      },
      body: JSON.stringify({
        model: input.model,
        messages: input.messages,
        tools: input.tools,
        tool_choice: "auto",
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`LLM provider error: ${res.status} ${err}`);
    }

    const json = (await res.json()) as {
      choices: Array<{
        message: {
          role: string;
          content: string | null;
          tool_calls?: Array<{
            id: string;
            type: string;
            function: { name: string; arguments: string };
          }>;
        };
      }>;
    };

    const message = json.choices[0]?.message;
    if (!message) throw new Error("Empty response from LLM provider");

    return {
      toolCalls: (message.tool_calls ?? []).map((tc) => ({
        id: tc.id,
        type: "function",
        function: {
          name: tc.function.name,
          arguments: tc.function.arguments,
        },
      })),
      rawResponse: json,
    };
  }
}

function timeoutSignal(timeoutMs: number): AbortSignal | undefined {
  return (AbortSignal as typeof AbortSignal & { timeout?: (milliseconds: number) => AbortSignal }).timeout?.(timeoutMs);
}
