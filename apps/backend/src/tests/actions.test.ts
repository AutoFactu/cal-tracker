import { describe, expect, it } from "vitest";
import { buildTestApp, registerAndAuth } from "./testApp.js";

describe("action loop", () => {
  it("creates a chicken and rice proposal, commits it, and includes it in the daily summary", async () => {
    const { request, repository } = buildTestApp();
    const auth = await registerAndAuth(request);

    const proposalResponse = await request("http://localhost/v1/actions/propose_meal_log/execute", {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({ input: { text: "Chicken and rice" }, source: "flutter" })
    });
    expect(proposalResponse.status).toBe(200);
    const proposalEnvelope = await proposalResponse.json() as { output: { proposal: { id: string; title: string; items: unknown[] } } };
    expect(proposalEnvelope.output.proposal.title).toBe("Chicken and rice");
    expect(proposalEnvelope.output.proposal.items).toHaveLength(2);

    const commitResponse = await request(`http://localhost/v1/meals/proposals/${proposalEnvelope.output.proposal.id}/commit`, {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({})
    });
    expect(commitResponse.status).toBe(200);
    const committed = await commitResponse.json() as { output: { meal: { id: string; nutrition: { calories: number } } } };
    expect(committed.output.meal.nutrition.calories).toBeGreaterThan(400);

    const summary = await request(`http://localhost/v1/summary/daily?date=${new Date().toISOString().slice(0, 10)}`, {
      headers: auth.authHeader
    });
    const summaryBody = await summary.json() as { output: { summary: { meals: unknown[]; consumed: { calories: number } } } };
    expect(summaryBody.output.summary.meals).toHaveLength(1);
    expect(summaryBody.output.summary.consumed.calories).toBe(committed.output.meal.nutrition.calories);

    const calls = await repository.listActionCalls(auth.user.id);
    const audits = await repository.listAuditEvents(auth.user.id);
    expect(calls.some((call) => call.actionId === "commit_meal")).toBe(true);
    expect(audits.some((event) => event.eventType === "action.commit_meal")).toBe(true);
  });

  it("preserves explicit Spanish gram quantities for meat and rice", async () => {
    const { request } = buildTestApp();
    const auth = await registerAndAuth(request);

    const proposalResponse = await request("http://localhost/v1/actions/propose_meal_log/execute", {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({
        input: {
          text: "Añada al almuerzo 100 gramos de carne y 100 gramos de arroz",
        },
        source: "flutter",
      }),
    });

    expect(proposalResponse.status).toBe(200);
    const body = await proposalResponse.json() as {
      output: {
        proposal: {
          items: { name: string; quantity: number }[];
        };
      };
    };
    expect(body.output.proposal.items).toEqual(expect.arrayContaining([
      expect.objectContaining({ name: "Chicken breast", quantity: 100 }),
      expect.objectContaining({ name: "Cooked rice", quantity: 100 }),
    ]));
  });

  it("corrects chicken grams on a committed meal", async () => {
    const { request } = buildTestApp();
    const auth = await registerAndAuth(request);
    const proposal = await request("http://localhost/v1/actions/propose_meal_log/execute", {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({ input: { text: "Chicken and rice" }, source: "flutter" })
    }).then((response) => response.json() as Promise<{ output: { proposal: { id: string } } }>);
    const meal = await request(`http://localhost/v1/meals/proposals/${proposal.output.proposal.id}/commit`, {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({})
    }).then((response) => response.json() as Promise<{ output: { meal: { id: string; nutrition: { calories: number } } } }>);

    const corrected = await request(`http://localhost/v1/meals/${meal.output.meal.id}/correct`, {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({ correctionText: "No, the chicken was 200 grams." })
    });
    expect(corrected.status).toBe(200);
    const body = await corrected.json() as { output: { meal: { nutrition: { calories: number }; items: { name: string; quantity: number }[] } } };
    expect(body.output.meal.items.find((item) => item.name === "Chicken breast")?.quantity).toBe(200);
    expect(body.output.meal.nutrition.calories).toBeGreaterThan(meal.output.meal.nutrition.calories);
  });

  it("requires confirmation token before deleting a meal", async () => {
    const { request } = buildTestApp();
    const auth = await registerAndAuth(request);
    const proposal = await request("http://localhost/v1/actions/propose_meal_log/execute", {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({ input: { text: "two eggs" }, source: "flutter" })
    }).then((response) => response.json() as Promise<{ output: { proposal: { id: string } } }>);
    const meal = await request(`http://localhost/v1/meals/proposals/${proposal.output.proposal.id}/commit`, {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({})
    }).then((response) => response.json() as Promise<{ output: { meal: { id: string } } }>);

    const firstDelete = await request(`http://localhost/v1/meals/${meal.output.meal.id}`, { method: "DELETE", headers: auth.authHeader });
    const firstBody = await firstDelete.json() as { output: { deleted: boolean; confirmationRequired: boolean } };
    expect(firstBody.output).toEqual({ deleted: false, confirmationRequired: true });

    const confirmedDelete = await request(`http://localhost/v1/meals/${meal.output.meal.id}?confirmationToken=DELETE`, { method: "DELETE", headers: auth.authHeader });
    const confirmedBody = await confirmedDelete.json() as { output: { deleted: boolean; confirmationRequired: boolean } };
    expect(confirmedBody.output).toEqual({ deleted: true, confirmationRequired: false });
  });

  it("auto-commits a trusted usual breakfast only after both trusted switches are enabled", async () => {
    const { request, repository } = buildTestApp();
    const auth = await registerAndAuth(request);

    const settings = await request("http://localhost/v1/settings", {
      method: "PUT",
      headers: auth.authHeader,
      body: JSON.stringify({ trustedModeEnabled: true })
    });
    expect(settings.status).toBe(200);

    const templates = await request("http://localhost/v1/meal-templates", { headers: auth.authHeader })
      .then((response) => response.json() as Promise<{ output: { templates: { id: string; items: unknown[]; aliases: string[] }[] } }>);
    const breakfast = templates.output.templates[0]!;

    const update = await request("http://localhost/v1/actions/update_meal_template/execute", {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({
        input: {
          templateId: breakfast.id,
          trustedAutoCommitEnabled: true,
          aliases: breakfast.aliases,
          items: breakfast.items
        },
        source: "flutter"
      })
    });
    expect(update.status).toBe(200);

    const run = await request("http://localhost/v1/agent/runs", {
      method: "POST",
      headers: auth.authHeader,
      body: JSON.stringify({ text: "I had my usual breakfast.", source: "flutter" })
    });
    expect(run.status).toBe(200);
    const body = await run.json() as { meal?: { id: string }; message: string };
    expect(body.meal?.id).toBeTruthy();
    expect(body.message).toMatch(/trusted template/);

    const audits = await repository.listAuditEvents(auth.user.id);
    expect(audits.some((event) => event.eventType === "trusted_auto_commit.meal_committed")).toBe(true);
  });
});
