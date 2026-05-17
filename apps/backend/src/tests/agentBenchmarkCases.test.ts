import { describe, expect, it } from "vitest";
import { agentFoodBenchmarkCases } from "../../scripts/agent-food-benchmark-cases.js";
import { validateCases } from "../../scripts/benchmark-agent-foods.js";

describe("agent food benchmark cases", () => {
  it("keeps the live benchmark at 100 hand-authored ES/EN cases", () => {
    validateCases();

    expect(agentFoodBenchmarkCases).toHaveLength(100);
    expect(agentFoodBenchmarkCases.filter((item) => item.language === "es")).toHaveLength(50);
    expect(agentFoodBenchmarkCases.filter((item) => item.language === "en")).toHaveLength(50);
    expect(new Set(agentFoodBenchmarkCases.map((item) => item.id)).size).toBe(100);
  });

  it("does not include BEDCA expectations or sources", () => {
    for (const item of agentFoodBenchmarkCases) {
      expect(JSON.stringify(item).toLowerCase()).not.toContain("bedca");
      expect(item.expectedFoods.length).toBeGreaterThan(0);
      expect(["propose_meal_log", "search_nutrition_database"]).toContain(item.expectedTool);
    }
  });
});
