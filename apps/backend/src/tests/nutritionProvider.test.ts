import { describe, expect, it } from "vitest";
import { FoodResolver, type FoodTextExtractor } from "../nutrition/foodResolver.js";
import { ResolverNutritionProvider } from "../nutrition/provider.js";
import { InMemoryRepository } from "../repository/inMemory.js";
import { seedTestFoods } from "./foodFixtures.js";

describe("ResolverNutritionProvider", () => {
  it("does not fall back to legacy hardcoded ingredient aliases", async () => {
    const repository = InMemoryRepository.seeded();
    seedTestFoods(repository);
    const extractor: FoodTextExtractor = {
      async extract() {
        return [];
      },
    };
    const resolver = new FoodResolver(extractor, [], repository, 0.75);
    const provider = new ResolverNutritionProvider(resolver);

    await expect(
      provider.estimateMeal("user-id", "pollo con arroz"),
    ).resolves.toEqual([]);
  });
});
