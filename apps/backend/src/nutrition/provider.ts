import type {
  FoodCandidateGroup,
  FoodMention,
  MealItem,
} from "@cal-tracker/contracts";
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
    locale?: string,
  ): Promise<MealItem[] | NutritionSearchResult>;
  estimateMeal(userId: string, text: string): Promise<MealItem[]>;
}

export interface MealTextResolutionProvider extends NutritionProvider {
  resolveMealText(userId: string, text: string, locale?: string): Promise<FoodResolutionResult>;
  resolveMealMentions(
    userId: string,
    mentions: FoodMention[],
    locale?: string,
  ): Promise<FoodResolutionResult>;
}

export class ResolverNutritionProvider implements MealTextResolutionProvider {
  constructor(private readonly resolver: FoodResolver) {}

  search(
    userId: string,
    query: string,
    barcode?: string,
    locale?: string,
  ): Promise<NutritionSearchResult> {
    return this.resolver.search(userId, query, barcode, locale);
  }

  async estimateMeal(userId: string, text: string): Promise<MealItem[]> {
    const result = await this.resolver.resolveMealText(userId, text);
    return result.clarificationRequired ? [] : result.items;
  }

  resolveMealText(userId: string, text: string, locale?: string): Promise<FoodResolutionResult> {
    return this.resolver.resolveMealText(userId, text, locale);
  }

  resolveMealMentions(
    userId: string,
    mentions: FoodMention[],
    locale?: string,
  ): Promise<FoodResolutionResult> {
    return this.resolver.resolveMealMentions(userId, mentions, locale);
  }
}
