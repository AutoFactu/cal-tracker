import { describe, expect, it } from "vitest";
import type { AgentToolDecision, ChatAgentProvider } from "../agent/chatAgentProvider.js";
import { buildTestApp, FakeChatAgentProvider, registerAndAuth } from "./testApp.js";

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
  it("maps chicken and rice to propose_meal_log", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "propose_meal_log",
              arguments: JSON.stringify({ text: "chicken and rice" }),
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
      body: JSON.stringify({ text: "chicken and rice", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.kind).toBe("proposal");
    expect(body.proposal).toBeDefined();
    expect(body.message).toBe("Meal proposal created.");
  });

  it("forces a Spanish meal logging request to a meal proposal when the model chooses lookup", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "search_nutrition_database",
              arguments: JSON.stringify({ query: "pan mantequilla" }),
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
      body: JSON.stringify({ text: "quiero añadir un desayuno de 100g de pan y 20g de mantequilla", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { kind: string; proposal: { title: string; items: { name: string; quantity: number }[] } };
    expect(body.kind).toBe("proposal");
    expect(body.proposal.title).toBe("Bread and Butter");
    expect(body.proposal.items).toEqual(expect.arrayContaining([
      expect.objectContaining({ name: "Bread", quantity: 100 }),
      expect.objectContaining({ name: "Butter", quantity: 20 }),
    ]));
  });

  it("parses Spanish bread and ham quantities into a complete proposal", async () => {
    const { request } = buildTestApp({
      agentProvider: new FakeChatAgentProvider({
        toolCalls: [
          {
            id: "call_1",
            type: "function",
            function: {
              name: "propose_meal_log",
              arguments: JSON.stringify({ text: "Añade a mi desayuno 100 gramos de pan y 100 gramos de jamón." }),
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
      body: JSON.stringify({ text: "Añade a mi desayuno 100 gramos de pan y 100 gramos de jamón.", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { kind: string; proposal: { title: string; items: { name: string; quantity: number }[] } };
    expect(body.kind).toBe("proposal");
    expect(body.proposal.title).toBe("Bread and Ham");
    expect(body.proposal.items).toEqual(expect.arrayContaining([
      expect.objectContaining({ name: "Bread", quantity: 100 }),
      expect.objectContaining({ name: "Ham", quantity: 100 }),
    ]));
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
              arguments: JSON.stringify({ text: "Añade 100 gramos de pan y 100 gramos de queso." }),
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
      body: JSON.stringify({ text: "Añade 100 gramos de pan y 100 gramos de queso.", source: "flutter" }),
    });

    const body = await res.json() as { kind: string; options: Array<{ mention: { canonicalEnglishName: string } }> };
    expect(body.kind).toBe("clarification_required");
    expect(body.options).toEqual(expect.arrayContaining([
      expect.objectContaining({ mention: expect.objectContaining({ canonicalEnglishName: "cheese" }) }),
    ]));
  });

  it("falls back to deterministic meal logging when the agent provider is unavailable", async () => {
    const { request } = buildTestApp({ agentProvider: new ThrowingChatAgentProvider() });
    const { authHeader } = await registerAndAuth(request);
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "Añade 100 gramos de pan y 100 gramos de queso.", source: "flutter" }),
    });

    expect(res.status).toBe(200);
    const body = await res.json() as { kind: string; options: Array<{ mention: { canonicalEnglishName: string } }> };
    expect(body.kind).toBe("clarification_required");
    expect(body.options).toEqual(expect.arrayContaining([
      expect.objectContaining({ mention: expect.objectContaining({ canonicalEnglishName: "cheese" }) }),
    ]));
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
      body: JSON.stringify({ text: "how many calories do I have left", source: "flutter" }),
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
              arguments: JSON.stringify({ mealId: "00000000-0000-0000-0000-000000000001" }),
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
      body: JSON.stringify({ text: "delete the snack I just added", source: "flutter" }),
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
      body: JSON.stringify({ text: "search nutrition database for bread", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { kind: string; items: { name: string }[] };
    expect(body.kind).toBe("nutrition_search");
    expect(body.items.some((item) => item.name === "Bread")).toBe(true);
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
    const res = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "show my usual meals", source: "flutter" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { kind: string; templates: { title: string }[] };
    expect(body.kind).toBe("templates");
    expect(body.templates.some((template) => template.title === "Usual breakfast")).toBe(true);
  });

  it("maps memory lookup, history, and template mutations to explicit result kinds", async () => {
    const agentProvider = new QueueChatAgentProvider();
    const { request } = buildTestApp({ agentProvider });
    const { authHeader } = await registerAndAuth(request);

    agentProvider.push({
      toolCalls: [{
        id: "call_1",
        type: "function",
        function: { name: "query_food_memory", arguments: JSON.stringify({ text: "usual breakfast" }) },
      }],
      rawResponse: {},
    });
    const memory = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "look up usual breakfast memory", source: "flutter" }),
    }).then((response) => response.json() as Promise<{ kind: string; matches: unknown[] }>);
    expect(memory.kind).toBe("food_memory");
    expect(memory.matches.length).toBeGreaterThan(0);

    agentProvider.push({
      toolCalls: [{
        id: "call_2",
        type: "function",
        function: { name: "get_meal_history", arguments: JSON.stringify({ limit: 5 }) },
      }],
      rawResponse: {},
    });
    const history = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "show meal history", source: "flutter" }),
    }).then((response) => response.json() as Promise<{ kind: string; meals: unknown[] }>);
    expect(history.kind).toBe("history");
    expect(history.meals).toEqual([]);

    const breadItem = {
      name: "Bread",
      quantity: 100,
      unit: "g",
      calories: 265,
      proteinGrams: 9,
      carbsGrams: 49,
      fatGrams: 3.2,
      source: "generic_usda",
    };

    agentProvider.push({
      toolCalls: [{
        id: "call_3",
        type: "function",
        function: {
          name: "create_meal_template",
          arguments: JSON.stringify({ title: "Toast", trustedAutoCommitEnabled: false, items: [breadItem], aliases: ["toast"] }),
        },
      }],
      rawResponse: {},
    });
    const created = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "create usual toast", source: "flutter" }),
    }).then((response) => response.json() as Promise<{ kind: string; template: { id: string; title: string } }>);
    expect(created.kind).toBe("template_saved");
    expect(created.template.title).toBe("Toast");

    agentProvider.push({
      toolCalls: [{
        id: "call_4",
        type: "function",
        function: {
          name: "update_meal_template",
          arguments: JSON.stringify({ templateId: created.template.id, title: "Toast updated", items: [breadItem], aliases: ["toast"] }),
        },
      }],
      rawResponse: {},
    });
    const updated = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "rename toast", source: "flutter" }),
    }).then((response) => response.json() as Promise<{ kind: string; template: { title: string } }>);
    expect(updated.kind).toBe("template_saved");
    expect(updated.template.title).toBe("Toast updated");

    agentProvider.push({
      toolCalls: [{
        id: "call_5",
        type: "function",
        function: { name: "delete_meal_template", arguments: JSON.stringify({ templateId: created.template.id }) },
      }],
      rawResponse: {},
    });
    const deleted = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "delete toast usual meal", source: "flutter" }),
    }).then((response) => response.json() as Promise<{ kind: string; deleted: boolean }>);
    expect(deleted.kind).toBe("template_deleted");
    expect(deleted.deleted).toBe(true);
  });

  it("maps direct commit and correction action results", async () => {
    const agentProvider = new QueueChatAgentProvider();
    const { request } = buildTestApp({ agentProvider });
    const { authHeader } = await registerAndAuth(request);
    const proposal = await request("http://localhost/v1/actions/propose_meal_log/execute", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ input: { text: "Chicken and rice" }, source: "flutter" }),
    }).then((response) => response.json() as Promise<{ output: { proposal: { id: string } } }>);

    agentProvider.push({
      toolCalls: [
        {
          id: "call_1",
          type: "function",
          function: {
            name: "commit_meal",
            arguments: JSON.stringify({ proposalId: proposal.output.proposal.id }),
          },
        },
      ],
      rawResponse: {},
    });
    const committed = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "confirm that proposal", source: "flutter" }),
    });
    const committedBody = await committed.json() as { kind: string; meal: { id: string } };
    expect(committedBody.kind).toBe("meal_committed");

    agentProvider.push({
      toolCalls: [
        {
          id: "call_2",
          type: "function",
          function: {
            name: "correct_meal",
            arguments: JSON.stringify({ mealId: committedBody.meal.id, correctionText: "No, the chicken was 200 grams." }),
          },
        },
      ],
      rawResponse: {},
    });
    const corrected = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: authHeader,
      body: JSON.stringify({ text: "No, the chicken was 200 grams.", source: "flutter" }),
    });
    const correctedBody = await corrected.json() as { kind: string; meal: { items: { name: string; quantity: number }[] } };
    expect(correctedBody.kind).toBe("meal_corrected");
    expect(correctedBody.meal.items.find((item) => item.name === "Chicken breast")?.quantity).toBe(200);
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
    expect(actionCalls.some((call) => call.actionId === "get_daily_summary")).toBe(true);
  });
});
