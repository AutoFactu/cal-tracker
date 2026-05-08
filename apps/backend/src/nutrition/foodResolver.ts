import type { FoodCandidateGroup, FoodMention, MealItem } from "@cal-tracker/contracts";
import type { AppRepository, FoodItemRecord } from "../repository/types.js";
import { normalizeText } from "../utils/normalize.js";
import { scaleFood } from "../utils/nutrition.js";

export type FoodResolutionResult = {
  items: MealItem[];
  unresolvedMentions: FoodMention[];
  candidateGroups: FoodCandidateGroup[];
  clarificationRequired: boolean;
};

export interface FoodTextExtractor {
  extract(text: string): Promise<FoodMention[]>;
}

export interface FoodDataProvider {
  readonly id: string;
  resolve(userId: string, mention: FoodMention): Promise<MealItem[]>;
}

export class FoodResolver {
  constructor(
    private readonly extractor: FoodTextExtractor,
    private readonly providers: FoodDataProvider[],
    private readonly repository: AppRepository,
    private readonly minConfidence: number
  ) {}

  async resolveMealText(userId: string, text: string): Promise<FoodResolutionResult> {
    const mentions = await this.extractor.extract(text);
    const items: MealItem[] = [];
    const unresolvedMentions: FoodMention[] = [];
    const candidateGroups: FoodCandidateGroup[] = [];

    for (const mention of mentions) {
      const candidates = await this.resolveMention(userId, mention);
      candidateGroups.push({ mention, candidates });
      const selected = candidates[0];
      if (!selected || (selected.confidence ?? mention.confidence) < this.minConfidence) {
        unresolvedMentions.push(mention);
        continue;
      }
      items.push(selected);
      await this.cacheExternalCandidate(selected);
    }

    return {
      items,
      unresolvedMentions,
      candidateGroups,
      clarificationRequired: mentions.length === 0 || unresolvedMentions.length > 0
    };
  }

  async search(userId: string, query: string, barcode?: string): Promise<MealItem[]> {
    const mention: FoodMention = {
      originalText: query,
      canonicalEnglishName: normalizeAlias(query),
      quantity: 100,
      unit: "g",
      barcode,
      confidence: 0.95,
      marketProduct: Boolean(barcode)
    };
    const candidates = await this.resolveMention(userId, mention, { includeMarketSearch: true });
    for (const candidate of candidates.slice(0, 3)) {
      await this.cacheExternalCandidate(candidate);
    }
    return candidates;
  }

  private async resolveMention(
    userId: string,
    mention: FoodMention,
    options: { includeMarketSearch?: boolean } = {}
  ): Promise<MealItem[]> {
    const candidates: MealItem[] = [];
    for (const provider of this.providers) {
      if (provider.id === "openfoodfacts" && !options.includeMarketSearch && !mention.barcode && !mention.brand && !mention.marketProduct) {
        continue;
      }
      let resolved: MealItem[];
      try {
        resolved = await provider.resolve(userId, mention);
      } catch {
        resolved = [];
      }
      candidates.push(...resolved);
      if (resolved.some((item) => (item.confidence ?? 0) >= this.minConfidence)) break;
    }
    return candidates.sort((a, b) => (b.confidence ?? 0) - (a.confidence ?? 0));
  }

  private async cacheExternalCandidate(item: MealItem): Promise<void> {
    if (!item.externalSource || !item.externalId) return;
    await this.repository.upsertFoodItem({
      name: item.name,
      normalizedName: normalizeText(item.canonicalName ?? item.name),
      canonicalName: item.canonicalName ?? item.name,
      source: item.source,
      externalSource: item.externalSource,
      externalId: item.externalId,
      sourceUrl: item.sourceUrl,
      license: item.license,
      fetchedAt: new Date().toISOString(),
      servingGrams: item.unit === "g" ? item.quantity : 100,
      calories: item.calories,
      proteinGrams: item.proteinGrams,
      carbsGrams: item.carbsGrams,
      fatGrams: item.fatGrams
    });
  }
}

export class DeterministicFoodTextExtractor implements FoodTextExtractor {
  async extract(text: string): Promise<FoodMention[]> {
    const normalized = normalizeText(text);
    const mentions = extractQuantityMentions(normalized);
    if (mentions.length > 0) return mentions;
    return extractUnquantifiedMentions(normalized);
  }
}

export class OpenRouterFoodTextExtractor implements FoodTextExtractor {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly baseUrl = "https://openrouter.ai/api/v1",
    private readonly timeoutMs = 10000
  ) {}

  async extract(text: string): Promise<FoodMention[]> {
    const response = await fetch(`${this.baseUrl}/chat/completions`, {
      method: "POST",
      signal: timeoutSignal(this.timeoutMs),
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: this.model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: [
              "Extract foods from meal text as JSON.",
              "Translate every food name to English in canonicalEnglishName.",
              "Return {\"mentions\":[{\"originalText\":\"...\",\"canonicalEnglishName\":\"...\",\"quantity\":100,\"unit\":\"g\",\"confidence\":0.9,\"marketProduct\":false}]}",
              "Use grams when the user gives gram quantities. Do not invent nutrition values."
            ].join(" ")
          },
          { role: "user", content: text }
        ]
      })
    });
    if (!response.ok) return [];
    const json = await response.json() as { choices?: Array<{ message?: { content?: string | null } }> };
    const content = json.choices?.[0]?.message?.content;
    if (!content) return [];
    try {
      const parsed = JSON.parse(content) as { mentions?: unknown[] };
      return (parsed.mentions ?? []).map(parseMention).filter((mention): mention is FoodMention => Boolean(mention));
    } catch {
      return [];
    }
  }
}

export class CompositeFoodTextExtractor implements FoodTextExtractor {
  constructor(private readonly extractors: FoodTextExtractor[]) {}

  async extract(text: string): Promise<FoodMention[]> {
    for (const extractor of this.extractors) {
      const mentions = await extractor.extract(text);
      if (mentions.length > 0) return mentions;
    }
    return [];
  }
}

export class LocalFoodDataProvider implements FoodDataProvider {
  readonly id = "local";

  constructor(private readonly repository: AppRepository) {}

  async resolve(userId: string, mention: FoodMention): Promise<MealItem[]> {
    const foods = await this.repository.searchFoods(userId, mention.canonicalEnglishName, mention.barcode);
    return foods.map((food) => itemFromFood(food, mention, {
      confidence: localConfidence(food, mention),
      source: food.source
    }));
  }
}

export class OpenFoodFactsFoodDataProvider implements FoodDataProvider {
  readonly id = "openfoodfacts";

  constructor(
    private readonly baseUrl: string,
    private readonly userAgent: string,
    private readonly timeoutMs = 5000
  ) {}

  async resolve(_userId: string, mention: FoodMention): Promise<MealItem[]> {
    const product = mention.barcode
      ? await this.fetchBarcode(mention.barcode)
      : await this.searchFirst(mention);
    const item = product ? mapOpenFoodFactsProduct(product, mention) : null;
    return item ? [item] : [];
  }

  private async fetchBarcode(barcode: string): Promise<OpenFoodFactsProduct | null> {
    const response = await fetch(`${this.baseUrl}/api/v2/product/${encodeURIComponent(barcode)}.json`, {
      signal: timeoutSignal(this.timeoutMs),
      headers: { "User-Agent": this.userAgent }
    });
    if (!response.ok) return null;
    const json = await response.json() as { status?: number; product?: OpenFoodFactsProduct };
    return json.status === 1 ? json.product ?? null : null;
  }

  private async searchFirst(mention: FoodMention): Promise<OpenFoodFactsProduct | null> {
    const url = new URL(`${this.baseUrl}/cgi/search.pl`);
    url.searchParams.set("search_terms", [mention.brand, mention.canonicalEnglishName].filter(Boolean).join(" "));
    url.searchParams.set("search_simple", "1");
    url.searchParams.set("action", "process");
    url.searchParams.set("json", "1");
    url.searchParams.set("page_size", "1");
    const response = await fetch(url, { signal: timeoutSignal(this.timeoutMs), headers: { "User-Agent": this.userAgent } });
    if (!response.ok) return null;
    const json = await response.json() as { products?: OpenFoodFactsProduct[] };
    return json.products?.[0] ?? null;
  }
}

export class UsdaFoodDataProvider implements FoodDataProvider {
  readonly id = "usda_fdc";

  constructor(
    private readonly apiKey?: string,
    private readonly baseUrl = "https://api.nal.usda.gov/fdc/v1",
    private readonly timeoutMs = 5000
  ) {}

  async resolve(_userId: string, mention: FoodMention): Promise<MealItem[]> {
    if (!this.apiKey) return [];
    const url = new URL(`${this.baseUrl}/foods/search`);
    url.searchParams.set("api_key", this.apiKey);
    url.searchParams.set("query", mention.canonicalEnglishName);
    url.searchParams.set("pageSize", "5");
    url.searchParams.append("dataType", "Foundation");
    url.searchParams.append("dataType", "SR Legacy");
    url.searchParams.append("dataType", "Survey (FNDDS)");
    const response = await fetch(url, { signal: timeoutSignal(this.timeoutMs) });
    if (!response.ok) return [];
    const json = await response.json() as { foods?: UsdaFood[] };
    return (json.foods ?? [])
      .map((food) => mapUsdaFood(food, mention))
      .filter((item): item is MealItem => Boolean(item))
      .sort((a, b) => (b.confidence ?? 0) - (a.confidence ?? 0));
  }
}

function extractQuantityMentions(text: string): FoodMention[] {
  const mentions: FoodMention[] = [];
  const unit = "(g|gr|gramo|gramos|gram|grams|kg|oz)";
  const quantityBefore = new RegExp(`(\\d+(?:[\\.,]\\d+)?)\\s*${unit}\\b\\s*(?:de\\s+|of\\s+)?([a-z][a-z\\s]{0,40}?)(?=\\s+(?:y|and)\\s+\\d|,|\\.|$)`, "g");
  for (const match of text.matchAll(quantityBefore)) {
    const quantity = normalizeQuantity(Number(match[1]!.replace(",", ".")), match[2]!);
    const unitValue = normalizeUnit(match[2]!);
    const originalText = match[3]!.trim();
    mentions.push(buildMention(originalText, quantity, unitValue));
  }
  return mergeDuplicateMentions(mentions);
}

function extractUnquantifiedMentions(text: string): FoodMention[] {
  const mentions: FoodMention[] = [];
  for (const [alias, canonical] of aliasEntries()) {
    if (new RegExp(`\\b${escapeRegExp(alias)}\\b`).test(text)) {
      mentions.push({
        originalText: alias,
        canonicalEnglishName: canonical,
        quantity: defaultQuantity(canonical),
        unit: "g",
        confidence: 0.82,
        marketProduct: false
      });
    }
  }
  return mergeDuplicateMentions(mentions);
}

function defaultQuantity(canonicalName: string): number {
  if (canonicalName === "milk") return 250;
  if (canonicalName === "chicken breast" || canonicalName === "rice") return 150;
  if (canonicalName === "butter") return 10;
  return 100;
}

function buildMention(originalText: string, quantity: number, unit: string): FoodMention {
  const canonicalEnglishName = normalizeAlias(originalText);
  return {
    originalText,
    canonicalEnglishName,
    quantity,
    unit,
    confidence: canonicalEnglishName === normalizeText(originalText) ? 0.72 : 0.92,
    marketProduct: false
  };
}

function normalizeAlias(value: string): string {
  const normalized = normalizeText(value)
    .replace(/\b(de|del|a|mi|my|the|fresh|cooked|raw|sliced)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  const exact = aliasMap.get(normalized);
  if (exact) return exact;
  const tokenMatch = normalized.split(" ").find((token) => aliasMap.has(token));
  return tokenMatch ? aliasMap.get(tokenMatch)! : normalized;
}

function itemFromFood(
  food: FoodItemRecord,
  mention: FoodMention,
  options: { confidence: number; source: string }
): MealItem {
  return {
    ...scaleFood(food, mention.quantity, mention.unit),
    source: options.source,
    originalText: mention.originalText,
    canonicalName: mention.canonicalEnglishName,
    externalSource: food.externalSource,
    externalId: food.externalId,
    sourceUrl: food.sourceUrl,
    license: food.license,
    confidence: Math.min(mention.confidence, options.confidence),
    needsReview: Math.min(mention.confidence, options.confidence) < 0.9
  };
}

function localConfidence(food: FoodItemRecord, mention: FoodMention): number {
  const canonical = normalizeText(food.canonicalName ?? food.normalizedName);
  if (canonical === normalizeText(mention.canonicalEnglishName)) return 0.96;
  if (food.normalizedName === normalizeText(mention.canonicalEnglishName)) return 0.94;
  return 0.78;
}

function mapOpenFoodFactsProduct(product: OpenFoodFactsProduct, mention: FoodMention): MealItem | null {
  const nutriments = product.nutriments;
  const calories = nutriments?.["energy-kcal_100g"];
  const proteinGrams = nutriments?.["proteins_100g"];
  const carbsGrams = nutriments?.["carbohydrates_100g"];
  const fatGrams = nutriments?.["fat_100g"];
  if (!isNumber(calories) || !isNumber(proteinGrams) || !isNumber(carbsGrams) || !isNumber(fatGrams)) return null;
  const base: FoodItemRecord = {
    id: product.code ?? mention.canonicalEnglishName,
    name: product.product_name || product.product_name_en || product.brands || mention.canonicalEnglishName,
    normalizedName: normalizeText(mention.canonicalEnglishName),
    canonicalName: mention.canonicalEnglishName,
    brand: product.brands,
    barcode: product.code,
    source: "openfoodfacts",
    externalSource: "openfoodfacts",
    externalId: product.code,
    sourceUrl: product.url,
    license: "ODbL-1.0",
    servingGrams: 100,
    calories,
    proteinGrams,
    carbsGrams,
    fatGrams
  };
  return itemFromFood(base, mention, { confidence: mention.barcode ? 0.98 : 0.86, source: "openfoodfacts" });
}

function mapUsdaFood(food: UsdaFood, mention: FoodMention): MealItem | null {
  const calories = findUsdaNutrient(food, 1008);
  const proteinGrams = findUsdaNutrient(food, 1003);
  const carbsGrams = findUsdaNutrient(food, 1005);
  const fatGrams = findUsdaNutrient(food, 1004);
  if (!isNumber(calories) || !isNumber(proteinGrams) || !isNumber(carbsGrams) || !isNumber(fatGrams)) return null;
  const dataTypeBonus = food.dataType === "Foundation" ? 0.08 : food.dataType === "SR Legacy" ? 0.05 : 0;
  const description = food.description ?? mention.canonicalEnglishName;
  const exactBonus = normalizeText(description).includes(normalizeText(mention.canonicalEnglishName)) ? 0.08 : 0;
  const base: FoodItemRecord = {
    id: String(food.fdcId),
    name: titleCase(description),
    normalizedName: normalizeText(mention.canonicalEnglishName),
    canonicalName: mention.canonicalEnglishName,
    source: "usda_fdc",
    externalSource: "usda_fdc",
    externalId: String(food.fdcId),
    sourceUrl: `https://fdc.nal.usda.gov/fdc-app.html#/food-details/${food.fdcId}/nutrients`,
    license: "CC0-1.0",
    servingGrams: 100,
    calories,
    proteinGrams,
    carbsGrams,
    fatGrams
  };
  return itemFromFood(base, mention, { confidence: Math.min(0.97, 0.78 + dataTypeBonus + exactBonus), source: "usda_fdc" });
}

function findUsdaNutrient(food: UsdaFood, nutrientNumber: number): number | undefined {
  const match = food.foodNutrients?.find((nutrient) => nutrient.nutrientNumber === nutrientNumber || nutrient.nutrientId === nutrientNumber);
  return isNumber(match?.value) ? match!.value : undefined;
}

function parseMention(input: unknown): FoodMention | null {
  if (!input || typeof input !== "object") return null;
  const value = input as Record<string, unknown>;
  const originalText = typeof value.originalText === "string" ? value.originalText : undefined;
  const canonicalEnglishName = typeof value.canonicalEnglishName === "string" ? value.canonicalEnglishName : undefined;
  const quantity = typeof value.quantity === "number" ? value.quantity : undefined;
  const unit = typeof value.unit === "string" ? value.unit : undefined;
  if (!originalText || !canonicalEnglishName || !quantity || !unit) return null;
  return {
    originalText,
    canonicalEnglishName: normalizeText(canonicalEnglishName),
    quantity,
    unit: normalizeUnit(unit),
    brand: typeof value.brand === "string" ? value.brand : undefined,
    barcode: typeof value.barcode === "string" ? value.barcode : undefined,
    confidence: typeof value.confidence === "number" ? value.confidence : 0.78,
    marketProduct: Boolean(value.marketProduct)
  };
}

function normalizeQuantity(quantity: number, unit: string): number {
  if (unit === "kg") return quantity * 1000;
  if (unit === "oz") return Math.round(quantity * 28.3495 * 10) / 10;
  return quantity;
}

function normalizeUnit(unit: string): string {
  if (unit === "kg" || unit === "oz") return "g";
  return "g";
}

function mergeDuplicateMentions(mentions: FoodMention[]): FoodMention[] {
  const deduped = new Map<string, FoodMention>();
  for (const mention of mentions) {
    const key = `${mention.canonicalEnglishName}:${mention.quantity}:${mention.unit}`;
    if (!deduped.has(key)) deduped.set(key, mention);
  }
  return [...deduped.values()];
}

function aliasEntries(): [string, string][] {
  return [...aliasMap.entries()].sort((a, b) => b[0].length - a[0].length);
}

const aliasMap = new Map<string, string>([
  ["pan", "bread"],
  ["bread", "bread"],
  ["jamon", "ham"],
  ["ham", "ham"],
  ["mantequilla", "butter"],
  ["butter", "butter"],
  ["pollo", "chicken breast"],
  ["pechuga de pollo", "chicken breast"],
  ["carne", "chicken breast"],
  ["chicken", "chicken breast"],
  ["chicken breast", "chicken breast"],
  ["arroz", "rice"],
  ["rice", "rice"],
  ["huevo", "egg"],
  ["huevos", "egg"],
  ["egg", "egg"],
  ["eggs", "egg"],
  ["avena", "oats"],
  ["oats", "oats"],
  ["leche", "milk"],
  ["milk", "milk"],
  ["queso", "cheese"],
  ["cheese", "cheese"],
  ["manzana", "apple"],
  ["apple", "apple"],
  ["platano", "banana"],
  ["banana", "banana"]
]);

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function isNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function titleCase(value: string): string {
  return value.toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function timeoutSignal(timeoutMs: number): AbortSignal | undefined {
  return (AbortSignal as typeof AbortSignal & { timeout?: (milliseconds: number) => AbortSignal }).timeout?.(timeoutMs);
}

type OpenFoodFactsProduct = {
  code?: string;
  url?: string;
  product_name?: string;
  product_name_en?: string;
  brands?: string;
  nutriments?: {
    "energy-kcal_100g"?: number;
    "proteins_100g"?: number;
    "carbohydrates_100g"?: number;
    "fat_100g"?: number;
  };
};

type UsdaFood = {
  fdcId: number;
  description?: string;
  dataType?: string;
  foodNutrients?: Array<{
    nutrientId?: number;
    nutrientNumber?: number;
    value?: number;
  }>;
};
