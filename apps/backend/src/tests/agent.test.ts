import { describe, expect, it } from "vitest";
import type { FoodMention } from "@cal-tracker/contracts";
import type {
  AgentToolDecision,
  ChatAgentProvider,
} from "../agent/chatAgentProvider.js";
import {
  buildTestApp,
  createTestUsualBreakfastTemplate,
  FakeChatAgentProvider,
  registerAndAuth,
  testBreadItem,
} from "./testApp.js";

class QueueChatAgentProvider implements ChatAgentProvider {
  constructor(private readonly decisions: AgentToolDecision[] = []) {}

  push(decision: AgentToolDecision): void {
    this.decisions.push(decision);
  }

  async runWithTools(): Promise<AgentToolDecision> {
    const decision = this.decisions.shift();
    if (!decision) throw new Error("missing_fake_agent_decision");
    return decision;
  }
}

class ThrowingChatAgentProvider implements ChatAgentProvider {
  async runWithTools(): Promise<AgentToolDecision> {
    throw new Error("provider_unavailable");
  }
}

describe("AgentService", () => {
  it("maps chicken and rice with quantities to propose_meal_log", async () => {
    const { request } = buildTestApp({
      foodTextExtractor: {
        async extract(): Promise<FoodMention[]> {
          throw new Error("text extractor should not be called");
        },
      },
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "propose_meal_log",
              arguments: JSON.stringify({
                text: "Add 100 grams of chicken breast and 100 grams of rice",
                mentions: [
                  {
                    originalText: "100 grams of chicken breast",
                    canonicalEnglishName: "chicken breast",
                    quantity: 100,
                    unit: "g",
                    rawUnitText: "grams",
                    unitKind: "metric",
                    confidence: 0.95,
                    marketProduct: false,
                  },
                  {
                    originalText: "100 grams of rice",
                    canonicalEnglishName: "rice",
                    quantity: 100,
                    unit: "g",
                    rawUnitText: "grams",
                    unitKind: "metric",
                    confidence: 0.95,
                    marketProduct: false,
                  },
                ],
              }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    await createTestUsualBreakfastTemplate(request, authHeader);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "Add 100 grams of chicken breast and 100 grams of rice",
        source: "flutter",
      }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      kind: string;
      proposal?: unknown;
      message: string;
      options: Array<{ mention: { canonicalEnglishName: string } }>;
    };
    expect(body.kind).toBe("proposal");
    expect(body.proposal).toBeDefined();
    expect(body.message).toBe("Meal proposal created.");
    expect(body.options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          mention: expect.objectContaining({
            canonicalEnglishName: "chicken breast",
          }),
        }),
        expect.objectContaining({
          mention: expect.objectContaining({ canonicalEnglishName: "rice" }),
        }),
      ]),
    );
  });

  it("forces a meal logging request to a meal proposal when the model chooses lookup", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "search_nutrition_database",
              arguments: JSON.stringify({ query: "bread butter" }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    await createTestUsualBreakfastTemplate(request, authHeader);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "I want to add a breakfast with 100g of bread and 20g of butter",
        source: "flutter",
      }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      kind: string;
      proposal: { title: string; items: { name: string; quantity: number }[] };
    };
    expect(body.kind).toBe("proposal");
    expect(body.proposal.title).toBe("Bread and Butter");
    expect(body.proposal.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: "Bread", quantity: 100 }),
        expect.objectContaining({ name: "Butter", quantity: 20 }),
      ]),
    );
  });

  it("parses bread and ham quantities into a complete proposal", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "propose_meal_log",
              arguments: JSON.stringify({
                text: "Add 100 grams of bread and 100 grams of ham.",
              }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "Add 100 grams of bread and 100 grams of ham.",
        source: "flutter",
      }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      kind: string;
      proposal: { title: string; items: { name: string; quantity: number }[] };
    };
    expect(body.kind).toBe("proposal");
    expect(body.proposal.title).toBe("Bread and Ham");
    expect(body.proposal.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: "Bread", quantity: 100 }),
        expect.objectContaining({ name: "Ham", quantity: 100 }),
      ]),
    );
  });

  it("returns clarification instead of dropping unresolved ingredients", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "propose_meal_log",
              arguments: JSON.stringify({
                text: "Add 100 grams of bread and 100 grams of cheese.",
              }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "Add 100 grams of bread and 100 grams of cheese.",
        source: "flutter",
      }),
    });

    const body = (await res.json()) as {
      kind: string;
      options: Array<{ mention: { canonicalEnglishName: string } }>;
    };
    expect(body.kind).toBe("clarification_required");
    expect(body.options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          mention: expect.objectContaining({ canonicalEnglishName: "cheese" }),
        }),
      ]),
    );
  });

  it("asks for clarification when a food uses an unsupported unit", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "propose_meal_log",
              arguments: JSON.stringify({ text: "Add 1 rice" }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "Add 1 rice", source: "flutter" }),
    });

    const body = (await res.json()) as {
      kind: string;
      message: string;
      options: Array<{ reason?: string }>;
    };
    expect(body.kind).toBe("clarification_required");
    expect(body.message).toContain("1 rice");
    expect(body.message).toContain("grams");
    expect(body.message).toContain("cups");
    expect(body.options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ reason: "unsupported_unit" }),
      ]),
    );
  });

  it("falls back to deterministic meal logging when the agent provider is unavailable", async () => {
    const { request } = buildTestApp({
      agentProvider: new ThrowingChatAgentProvider(),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "Add 100 grams of bread and 100 grams of cheese.",
        source: "flutter",
      }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      kind: string;
      options: Array<{ mention: { canonicalEnglishName: string } }>;
    };
    expect(body.kind).toBe("clarification_required");
    expect(body.options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          mention: expect.objectContaining({ canonicalEnglishName: "cheese" }),
        }),
      ]),
    );
  });

  it("maps calories left to get_remaining_targets", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "get_remaining_targets",
              arguments: JSON.stringify({}),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "how many calories do I have left",
        source: "flutter",
      }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.kind).toBe("remaining_targets");
    expect(body.remaining).toBeDefined();
    expect(body.message).toContain("remaining targets");
  });

  it("maps delete snack to confirmation_required", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "delete_meal",
              arguments: JSON.stringify({
                mealId: "00000000-0000-0000-0000-000000000001",
              }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "delete the snack I just added",
        source: "flutter",
      }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.kind).toBe("confirmation_required");
    expect(body.actionId).toBe("delete_meal");
    expect(body.message).toContain("confirm");
  });

  it("maps explicit nutrition search to nutrition_search", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "search_nutrition_database",
              arguments: JSON.stringify({ query: "bread" }),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "search nutrition database for bread",
        source: "flutter",
      }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      kind: string;
      items: { name: string }[];
      options: Array<{
        mention: { canonicalEnglishName: string };
        candidates: Array<{ name: string }>;
      }>;
    };
    expect(body.kind).toBe("nutrition_search");
    expect(body.items.some((item) => item.name === "Bread")).toBe(true);
    expect(body.options[0]).toEqual(
      expect.objectContaining({
        mention: expect.objectContaining({ canonicalEnglishName: "bread" }),
        candidates: expect.arrayContaining([
          expect.objectContaining({ name: "Bread" }),
        ]),
      }),
    );
  });

  it("maps usual meal listing to templates", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "get_usual_meals",
              arguments: JSON.stringify({}),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    await createTestUsualBreakfastTemplate(request, authHeader);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "show my usual meals", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      kind: string;
      templates: { title: string }[];
    };
    expect(body.kind).toBe("templates");
    expect(
      body.templates.some((template) => template.title === "Usual breakfast"),
    ).toBe(true);
  });

  it("maps memory lookup, history, and template mutations to explicit result kinds", async () => {
    const agentProvider = new QueueChatAgentProvider();
    const { request } = buildTestApp({ agentProvider });
    const { authHeader } = await registerAndAuth(request);
    await createTestUsualBreakfastTemplate(request, authHeader);

    agentProvider.push({
      toolCalls: [
        {
          id: "call_1",
          type: "function",
          function: {
            name: "query_food_memory",
            arguments: JSON.stringify({ text: "usual breakfast" }),
          },
        },
      ],
      rawResponse: {},
    });
    const memory = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "look up usual breakfast memory",
        source: "flutter",
      }),
    }).then(
      (response) =>
        response.json() as Promise<{ kind: string; matches: unknown[] }>,
    );
    expect(memory.kind).toBe("food_memory");
    expect(memory.matches.length).toBeGreaterThan(0);

    agentProvider.push({
      toolCalls: [
        {
          id: "call_2",
          type: "function",
          function: {
            name: "get_meal_history",
            arguments: JSON.stringify({ limit: 5 }),
          },
        },
      ],
      rawResponse: {},
    });
    const history = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "show meal history", source: "flutter" }),
    }).then(
      (response) =>
        response.json() as Promise<{ kind: string; meals: unknown[] }>,
    );
    expect(history.kind).toBe("history");
    expect(history.meals).toEqual([]);

    agentProvider.push({
      toolCalls: [
        {
          id: "call_3",
          type: "function",
          function: {
            name: "create_meal_template",
            arguments: JSON.stringify({
              title: "Toast",
              trustedAutoCommitEnabled: false,
              items: [testBreadItem],
              aliases: ["toast"],
            }),
          },
        },
      ],
      rawResponse: {},
    });
    const created = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "create usual toast", source: "flutter" }),
    }).then(
      (response) =>
        response.json() as Promise<{
          kind: string;
          template: { id: string; title: string };
        }>,
    );
    expect(created.kind).toBe("template_saved");
    expect(created.template.title).toBe("Toast");

    agentProvider.push({
      toolCalls: [
        {
          id: "call_4",
          type: "function",
          function: {
            name: "update_meal_template",
            arguments: JSON.stringify({
              templateId: created.template.id,
              title: "Toast updated",
              items: [testBreadItem],
              aliases: ["toast"],
            }),
          },
        },
      ],
      rawResponse: {},
    });
    const updated = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "rename toast", source: "flutter" }),
    }).then(
      (response) =>
        response.json() as Promise<{
          kind: string;
          template: { title: string };
        }>,
    );
    expect(updated.kind).toBe("template_saved");
    expect(updated.template.title).toBe("Toast updated");

    agentProvider.push({
      toolCalls: [
        {
          id: "call_5",
          type: "function",
          function: {
            name: "delete_meal_template",
            arguments: JSON.stringify({ templateId: created.template.id }),
          },
        },
      ],
      rawResponse: {},
    });
    const deleted = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "delete toast usual meal",
        source: "flutter",
      }),
    }).then(
      (response) =>
        response.json() as Promise<{ kind: string; deleted: boolean }>,
    );
    expect(deleted.kind).toBe("template_deleted");
    expect(deleted.deleted).toBe(true);
  });

  it("maps direct commit and correction action results", async () => {
    const agentProvider = new QueueChatAgentProvider();
    const { request } = buildTestApp({ agentProvider });
    const { authHeader } = await registerAndAuth(request);
    const proposal = await request(
      "http://localhost/v1/actions/propose_meal_log/execute",
      {
        method: "POST",
        headers: authHeader,
        body: JSON.stringify({
          input: {
            text: "Add 100 grams of chicken breast and 100 grams of rice",
          },
          source: "flutter",
        }),
      },
    ).then(
      (response) =>
        response.json() as Promise<{ output: { proposal: { id: string } } }>,
    );

    agentProvider.push({
      toolCalls: [
        {
          id: "call_1",
          type: "function",
          function: {
            name: "commit_meal",
            arguments: JSON.stringify({
              proposalId: proposal.output.proposal.id,
            }),
          },
        },
      ],
      rawResponse: {},
    });
    const committed = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "confirm that proposal",
        source: "flutter",
      }),
    });
    const committedBody = (await committed.json()) as {
      kind: string;
      meal: { id: string; items: Array<Record<string, unknown>> };
    };
    expect(committedBody.kind).toBe("meal_committed");

    const editedItems = committedBody.meal.items.map((item) => {
      if (item.name !== "Chicken breast") return item;
      return {
        ...item,
        quantity: 200,
        calories: 330,
        proteinGrams: 62,
        carbsGrams: 0,
        fatGrams: 7.2,
      };
    });

    agentProvider.push({
      toolCalls: [
        {
          id: "call_2",
          type: "function",
          function: {
            name: "correct_meal",
            arguments: JSON.stringify({
              mealId: committedBody.meal.id,
              items: editedItems,
            }),
          },
        },
      ],
      rawResponse: {},
    });
    const corrected = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({
        text: "No, the chicken was 200 grams.",
        source: "flutter",
      }),
    });
    const correctedBody = (await corrected.json()) as {
      kind: string;
      meal: { items: { name: string; quantity: number }[] };
    };
    expect(correctedBody.kind).toBe("meal_corrected");
    expect(
      correctedBody.meal.items.find((item) => item.name === "Chicken breast")
        ?.quantity,
    ).toBe(200);
  });

  it("rejects unknown model-selected actions", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "nonexistent_action",
              arguments: JSON.stringify({}),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "do something weird", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.kind).toBe("clarification_required");
  });

  it("records action calls through executor", async () => {
    const { request, repository } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "get_daily_summary",
              arguments: JSON.stringify({}),
            },
          },
        ],
        rawResponse: {},
      }),
    });
    const { authHeader, user } = await registerAndAuth(request);
    await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "daily summary", source: "flutter" }),
    });

    const actionCalls = await repository.listActionCalls(user.id);
    expect(
      actionCalls.some((call) => call.actionId === "get_daily_summary"),
    ).toBe(true);
  });
});
