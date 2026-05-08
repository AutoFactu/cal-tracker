import { afterEach, describe, expect, it, vi } from "vitest";
import type { MealItem } from "@cal-tracker/contracts";
import {
  DeterministicFoodTextExtractor,
  FoodResolver,
  LocalFoodDataProvider,
  OpenFoodFactsFoodDataProvider,
  UsdaFoodDataProvider,
  type FoodDataProvider
} from "../nutrition/foodResolver.js";
import { InMemoryRepository } from "../repository/inMemory.js";

const originalFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = originalFetch;
});

describe("FoodResolver", () => {
  it("extracts Spanish ingredients, translates names, and keeps repeated quantities", async () => {
    const mentions = await new DeterministicFoodTextExtractor().extract(
      "Añade a mi desayuno 100 gramos de pan y 100 gramos de jamón."
    );

    expect(mentions).toEqual(expect.arrayContaining([
      expect.objectContaining({ originalText: "pan", canonicalEnglishName: "bread", quantity: 100, unit: "g" }),
      expect.objectContaining({ originalText: "jamon", canonicalEnglishName: "ham", quantity: 100, unit: "g" }),
    ]));
  });

  it("does not silently create a partial proposal when one extracted ingredient is unresolved", async () => {
    const repository = InMemoryRepository.seeded();
    const resolver = new FoodResolver(
      new DeterministicFoodTextExtractor(),
      [new LocalFoodDataProvider(repository)],
      repository,
      0.75
    );

    const result = await resolver.resolveMealText(
      "user-1",
      "Añade 100 gramos de pan y 100 gramos de queso."
    );

    expect(result.clarificationRequired).toBe(true);
    expect(result.items).toHaveLength(1);
    expect(result.items[0]?.name).toBe("Bread");
    expect(result.unresolvedMentions).toEqual(expect.arrayContaining([
      expect.objectContaining({ canonicalEnglishName: "cheese" }),
    ]));
  });

  it("resolves and caches a generic simple food from USDA FDC", async () => {
    globalThis.fetch = vi.fn(async () => new Response(JSON.stringify({
      foods: [{
        fdcId: 123,
        description: "Cheese, cheddar",
        dataType: "Foundation",
        foodNutrients: [
          { nutrientNumber: 1008, value: 403 },
          { nutrientNumber: 1003, value: 24.9 },
          { nutrientNumber: 1005, value: 1.3 },
          { nutrientNumber: 1004, value: 33.1 },
        ],
      }],
    }), { status: 200 })) as typeof fetch;
    const repository = InMemoryRepository.seeded();
    const resolver = new FoodResolver(
      new DeterministicFoodTextExtractor(),
      [new LocalFoodDataProvider(repository), new UsdaFoodDataProvider("test-key", "https://fdc.example.test")],
      repository,
      0.75
    );

    const result = await resolver.resolveMealText("user-1", "100 gramos de queso");

    expect(result.clarificationRequired).toBe(false);
    expect(result.items[0]).toEqual(expect.objectContaining({
      canonicalName: "cheese",
      externalSource: "usda_fdc",
      externalId: "123",
      calories: 403,
    }));
    expect(await repository.searchFoods("user-1", "cheese")).toEqual(expect.arrayContaining([
      expect.objectContaining({ externalSource: "usda_fdc", externalId: "123" }),
    ]));
  });

  it("uses Open Food Facts for barcode or market-product resolution", async () => {
    globalThis.fetch = vi.fn(async () => new Response(JSON.stringify({
      status: 1,
      product: {
        code: "8410000000000",
        url: "https://world.openfoodfacts.org/product/8410000000000",
        product_name: "Market Bread",
        brands: "Test Brand",
        nutriments: {
          "energy-kcal_100g": 250,
          "proteins_100g": 8,
          "carbohydrates_100g": 48,
          "fat_100g": 2,
        },
      },
    }), { status: 200 })) as typeof fetch;
    const provider = new OpenFoodFactsFoodDataProvider("https://off.example.test", "CalTrackerTests/1.0");

    const items = await provider.resolve("user-1", {
      originalText: "Market Bread",
      canonicalEnglishName: "bread",
      quantity: 100,
      unit: "g",
      barcode: "8410000000000",
      confidence: 0.95,
      marketProduct: true,
    });

    expect(items[0]).toEqual(expect.objectContaining({
      name: "Market Bread",
      source: "openfoodfacts",
      externalSource: "openfoodfacts",
      externalId: "8410000000000",
      license: "ODbL-1.0",
    }));
  });

  it("continues provider resolution when the local cache is below confidence", async () => {
    const lowConfidenceProvider: FoodDataProvider = {
      id: "low",
      async resolve(): Promise<MealItem[]> {
        return [{
          name: "Loose match",
          quantity: 100,
          unit: "g",
          calories: 1,
          proteinGrams: 0,
          carbsGrams: 0,
          fatGrams: 0,
          source: "test",
          confidence: 0.2,
        }];
      },
    };
    const highConfidenceProvider: FoodDataProvider = {
      id: "high",
      async resolve(): Promise<MealItem[]> {
        return [{
          name: "Cheese",
          quantity: 100,
          unit: "g",
          calories: 400,
          proteinGrams: 25,
          carbsGrams: 1,
          fatGrams: 33,
          source: "test",
          confidence: 0.95,
        }];
      },
    };
    const repository = InMemoryRepository.seeded();
    const resolver = new FoodResolver(
      new DeterministicFoodTextExtractor(),
      [lowConfidenceProvider, highConfidenceProvider],
      repository,
      0.75
    );

    const result = await resolver.resolveMealText("user-1", "100 gramos de queso");

    expect(result.clarificationRequired).toBe(false);
    expect(result.items[0]?.name).toBe("Cheese");
  });
});
