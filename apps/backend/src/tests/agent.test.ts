import { describe, expect, it } from "vitest";
import { buildTestApp, FakeChatAgentProvider, registerAndAuth } from "./testApp.js";

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
