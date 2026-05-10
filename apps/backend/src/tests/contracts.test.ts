import { describe, expect, it } from "vitest";
import { actionDefinitions, actionById } from "@cal-tracker/contracts";

describe("contracts", () => {
  it("defines all MVP actions with schemas and permissions", () => {
    const expected = [
      "query_food_memory",
      "search_nutrition_database",
      "propose_meal_log",
      "commit_meal",
      "create_meal_proposal_from_items",
      "correct_meal",
      "delete_meal",
      "get_daily_summary",
      "get_remaining_targets",
      "get_meal_history",
      "get_usual_meals",
      "create_meal_template",
      "update_meal_template",
      "delete_meal_template",
    ];
    expect(actionDefinitions.map((action) => action.id)).toEqual(expected);
    for (const id of expected) {
      const action = actionById.get(id)!;
      expect(action.inputSchema).toBeTruthy();
      expect(action.outputSchema).toBeTruthy();
      expect(action.permissionScope).toBeTruthy();
    }
  });
});
