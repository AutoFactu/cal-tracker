import type { MealItem } from "@cal-tracker/contracts";
import type { AppRepository, FoodItemRecord } from "../repository/types.js";
import type { FoodResolutionResult, FoodResolver } from "./foodResolver.js";
import { normalizeText } from "../utils/normalize.js";
import { scaleFood } from "../utils/nutrition.js";

export interface NutritionProvider {
  search(userId: string, query: string, barcode?: string): Promise<MealItem[]>;
  estimateMeal(userId: string, text: string): Promise<MealItem[]>;
}

export interface MealTextResolutionProvider extends NutritionProvider {
  resolveMealText(userId: string, text: string): Promise<FoodResolutionResult>;
}

export class ResolverNutritionProvider implements MealTextResolutionProvider {
  constructor(private readonly resolver: FoodResolver) {}

  search(userId: string, query: string, barcode?: string): Promise<MealItem[]> {
    return this.resolver.search(userId, query, barcode);
  }

  async estimateMeal(userId: string, text: string): Promise<MealItem[]> {
    const result = await this.resolver.resolveMealText(userId, text);
    return result.clarificationRequired ? [] : result.items;
  }

  resolveMealText(userId: string, text: string): Promise<FoodResolutionResult> {
    return this.resolver.resolveMealText(userId, text);
  }
}

export class NutritionProviderChain implements NutritionProvider {
  constructor(private readonly providers: NutritionProvider[]) {}

  async search(userId: string, query: string, barcode?: string): Promise<MealItem[]> {
    for (const provider of this.providers) {
      const items = await provider.search(userId, query, barcode);
      if (items.length > 0) return items;
    }
    return [];
  }

  async estimateMeal(userId: string, text: string): Promise<MealItem[]> {
    for (const provider of this.providers) {
      const items = await provider.estimateMeal(userId, text);
      if (items.length > 0) return items;
    }
    return [];
  }
}

export class LocalNutritionProvider implements NutritionProvider {
  constructor(private readonly repository: AppRepository) {}

  async search(userId: string, query: string, barcode?: string): Promise<MealItem[]> {
    const foods = await this.repository.searchFoods(userId, query, barcode);
    return foods.map((food) => scaleFood(food, food.servingGrams));
  }

  async estimateMeal(userId: string, text: string): Promise<MealItem[]> {
    const normalized = normalizeText(text);
    const foods = await this.repository.listFoods(userId);
    const items: MealItem[] = [];

    const chicken = findFood(foods, "chicken breast");
    const rice = findFood(foods, "rice");
    const egg = findFood(foods, "egg");
    const oats = findFood(foods, "oats");
    const milk = findFood(foods, "milk");
    const bread = findFood(foods, "bread");
    const butter = findFood(foods, "butter");
    const ham = findFood(foods, "ham");

    addFoodIfMentioned(items, chicken, normalized, ["chicken breast", "chicken", "pechuga de pollo", "pechuga", "pollo", "carne"], 150);
    addFoodIfMentioned(items, rice, normalized, ["cooked rice", "rice", "arroz"], 150);
    if (includesAny(normalized, ["egg", "huevo"])) {
      const count = normalized.includes("two egg") || normalized.includes("2 egg") ? 2 : 1;
      items.push({
        ...scaleFood(egg, 50 * count, "egg"),
        quantity: count,
        unit: "egg"
      });
    }
    addFoodIfMentioned(items, oats, normalized, ["oats", "oat", "avena"], 60);
    if (includesAny(normalized, ["milk", "leche"])) {
      items.push(scaleFood(milk, 250, "ml"));
    }
    if (includesAny(normalized, ["bread", "pan"])) {
      items.push(scaleFood(bread, extractGramsNearAny(normalized, ["bread", "pan"]) ?? 100));
    }
    if (includesAny(normalized, ["butter", "mantequilla"])) {
      items.push(scaleFood(butter, extractGramsNearAny(normalized, ["butter", "mantequilla"]) ?? 10));
    }
    if (includesAny(normalized, ["ham", "jamon"])) {
      items.push(scaleFood(ham, extractGramsNearAny(normalized, ["ham", "jamon"]) ?? 50));
    }

    if (items.length === 0) {
      items.push(scaleFood(chicken, 150));
      items.push(scaleFood(rice, 150));
    }

    return items;
  }
}

export class OpenFoodFactsProvider implements NutritionProvider {
  constructor(private readonly baseUrl = "https://world.openfoodfacts.org") {}

  async search(_userId: string, query: string, barcode?: string): Promise<MealItem[]> {
    const product = barcode
      ? await this.fetchByBarcode(barcode)
      : await this.searchFirstProduct(query);
    if (!product) return [];
    const item = mapOpenFoodFactsProduct(product);
    return item ? [item] : [];
  }

  async estimateMeal(): Promise<MealItem[]> {
    return [];
  }

  private async fetchByBarcode(barcode: string): Promise<OpenFoodFactsProduct | null> {
    const response = await fetch(`${this.baseUrl}/api/v2/product/${encodeURIComponent(barcode)}.json`);
    if (!response.ok) return null;
    const json = await response.json() as { status?: number; product?: OpenFoodFactsProduct };
    return json.status === 1 ? json.product ?? null : null;
  }

  private async searchFirstProduct(query: string): Promise<OpenFoodFactsProduct | null> {
    const url = new URL(`${this.baseUrl}/cgi/search.pl`);
    url.searchParams.set("search_terms", query);
    url.searchParams.set("search_simple", "1");
    url.searchParams.set("action", "process");
    url.searchParams.set("json", "1");
    url.searchParams.set("page_size", "1");
    const response = await fetch(url);
    if (!response.ok) return null;
    const json = await response.json() as { products?: OpenFoodFactsProduct[] };
    return json.products?.[0] ?? null;
  }
}

export class UsdaNutritionProvider implements NutritionProvider {
  async search(): Promise<MealItem[]> {
    return [];
  }

  async estimateMeal(): Promise<MealItem[]> {
    return [];
  }
}

type OpenFoodFactsProduct = {
  product_name?: string;
  product_name_en?: string;
  brands?: string;
  serving_quantity?: number | string;
  nutriments?: {
    "energy-kcal_100g"?: number;
    "proteins_100g"?: number;
    "carbohydrates_100g"?: number;
    "fat_100g"?: number;
  };
};

function mapOpenFoodFactsProduct(product: OpenFoodFactsProduct): MealItem | null {
  const nutriments = product.nutriments;
  const calories = nutriments?.["energy-kcal_100g"];
  const proteinGrams = nutriments?.["proteins_100g"];
  const carbsGrams = nutriments?.["carbohydrates_100g"];
  const fatGrams = nutriments?.["fat_100g"];
  if (
    typeof calories !== "number" ||
    typeof proteinGrams !== "number" ||
    typeof carbsGrams !== "number" ||
    typeof fatGrams !== "number"
  ) {
    return null;
  }

  return {
    name: product.product_name || product.product_name_en || product.brands || "OpenFoodFacts product",
    quantity: Number(product.serving_quantity) || 100,
    unit: "g",
    calories: Math.round(calories),
    proteinGrams,
    carbsGrams,
    fatGrams,
    source: "openfoodfacts",
  };
}

function findFood(foods: FoodItemRecord[], normalizedName: string): FoodItemRecord {
  const food = foods.find((candidate) => candidate.normalizedName === normalizedName);
  if (!food) throw new Error(`seed_food_missing:${normalizedName}`);
  return food;
}

function extractGramsNear(text: string, keyword: string): number | undefined {
  const unit = "(?:gramos|gramo|grams|gram|gr|g)";
  const escaped = escapeRegExp(keyword);
  const before = new RegExp(`(\\d{1,4})\\s*${unit}\\b\\D{0,30}\\b${escaped}\\b`).exec(text);
  if (before) return Number(before[1]);
  const after = new RegExp(`\\b${escaped}\\b\\D{0,30}(\\d{1,4})\\s*${unit}\\b`).exec(text);
  if (after) return Number(after[1]);
  return undefined;
}

function includesAny(text: string, keywords: string[]): boolean {
  return keywords.some((keyword) => new RegExp(`\\b${escapeRegExp(keyword)}\\b`).test(text));
}

function extractGramsNearAny(text: string, keywords: string[]): number | undefined {
  for (const keyword of keywords) {
    const grams = extractGramsNear(text, keyword);
    if (grams) return grams;
  }
  return undefined;
}

function addFoodIfMentioned(
  items: MealItem[],
  food: FoodItemRecord,
  normalizedText: string,
  aliases: string[],
  defaultGrams: number
) {
  if (!includesAny(normalizedText, aliases)) return;
  const grams = extractGramsNearAny(normalizedText, aliases) ?? defaultGrams;
  items.push(scaleFood(food, grams));
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
