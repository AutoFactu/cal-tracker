import type { FoodCandidateGroup, MealItem } from "@cal-tracker/contracts";
import type { FoodResolutionResult, FoodResolver } from "./foodResolver.js";

export type NutritionSearchResult = {
  items: MealItem[];
  candidates?: FoodCandidateGroup[];
  candidateGroups?: FoodCandidateGroup[];
};

export interface NutritionProvider {
  search(
    userId: string,
    query: string,
    barcode?: string,
  ): Promise<MealItem[] | NutritionSearchResult>;
  estimateMeal(userId: string, text: string): Promise<MealItem[]>;
}

export interface MealTextResolutionProvider extends NutritionProvider {
  resolveMealText(userId: string, text: string): Promise<FoodResolutionResult>;
}

export class ResolverNutritionProvider implements MealTextResolutionProvider {
  constructor(private readonly resolver: FoodResolver) {}

  search(
    userId: string,
    query: string,
    barcode?: string,
  ): Promise<NutritionSearchResult> {
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
