import { ActionExecutor } from "../actions/executor.js";
import { AuthService } from "../auth/service.js";
import { loadConfig } from "../config/env.js";
import { createApp } from "../http/app.js";
import { LocalNutritionProvider, NutritionProviderChain, UsdaNutritionProvider } from "../nutrition/provider.js";
import { InMemoryRepository } from "../repository/inMemory.js";
import type { SpeechToTextProvider, TranscriptionResult } from "../stt/speechToTextProvider.js";
import type { ChatAgentProvider, AgentToolDecision } from "../agent/chatAgentProvider.js";

class FakeSpeechToTextProvider implements SpeechToTextProvider {
  async transcribe(): Promise<TranscriptionResult> {
    return { text: "fake transcript from test", provider: "test", model: "test-model" };
  }
}

export class FakeChatAgentProvider implements ChatAgentProvider {
  constructor(private readonly decision: AgentToolDecision) {}
  async runWithTools(): Promise<AgentToolDecision> {
    return this.decision;
  }
}

export function buildTestApp(options?: { agentProvider?: ChatAgentProvider }) {
  const config = loadConfig({ NODE_ENV: "test" } as NodeJS.ProcessEnv);
  const repository = InMemoryRepository.seeded();
  const authService = new AuthService(config, repository);
  const nutritionProvider = new NutritionProviderChain([
    new LocalNutritionProvider(repository),
    new UsdaNutritionProvider(),
  ]);
  const actionExecutor = new ActionExecutor(config, repository, nutritionProvider);
  const sttProvider = new FakeSpeechToTextProvider();
  const defaultAgentProvider = new FakeChatAgentProvider({
    toolCalls: [
      {
        id: "call_default",
        type: "function",
        function: {
          name: "propose_meal_log",
          arguments: JSON.stringify({ text: "usual breakfast" }),
        },
      },
    ],
    rawResponse: {},
  });
  const app = createApp({ config, repository, authService, actionExecutor, sttProvider, agentProvider: options?.agentProvider ?? defaultAgentProvider });
  const request = (input: string, init?: RequestInit) => Promise.resolve(app.request(input, init));
  return { app, request, config, repository, authService, actionExecutor, sttProvider };
}

export async function registerAndAuth(request: (input: string, init?: RequestInit) => Promise<Response>) {
  const response = await request("http://localhost/v1/auth/register", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "test@example.com", password: "password123", displayName: "Test User" })
  });
  const body = await response.json() as { accessToken: string; refreshToken: string; user: { id: string } };
  return {
    ...body,
    authHeader: { authorization: `Bearer ${body.accessToken}`, "content-type": "application/json" }
  };
}
