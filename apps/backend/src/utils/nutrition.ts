import type { MealItem, NutritionSnapshot } from "@cal-tracker/contracts";

export const emptyNutrition: NutritionSnapshot = {
  calories: 0,
  proteinGrams: 0,
  carbsGrams: 0,
  fatGrams: 0
};

export function sumNutrition(items: MealItem[]): NutritionSnapshot {
  return items.reduce<NutritionSnapshot>(
    (total, item) => ({
      calories: total.calories + item.calories,
      proteinGrams: round(total.proteinGrams + item.proteinGrams),
      carbsGrams: round(total.carbsGrams + item.carbsGrams),
      fatGrams: round(total.fatGrams + item.fatGrams)
    }),
    { ...emptyNutrition }
  );
}

export function subtractNutrition(target: NutritionSnapshot, consumed: NutritionSnapshot): NutritionSnapshot {
  return {
    calories: Math.max(0, target.calories - consumed.calories),
    proteinGrams: Math.max(0, round(target.proteinGrams - consumed.proteinGrams)),
    carbsGrams: Math.max(0, round(target.carbsGrams - consumed.carbsGrams)),
    fatGrams: Math.max(0, round(target.fatGrams - consumed.fatGrams))
  };
}

export function scaleFood(
  food: { name: string; servingGrams: number; calories: number; proteinGrams: number; carbsGrams: number; fatGrams: number; source: string },
  quantity: number,
  unit = "g"
): MealItem {
  const factor = quantity / food.servingGrams;
  return {
    name: food.name,
    quantity,
    unit,
    calories: Math.round(food.calories * factor),
    proteinGrams: round(food.proteinGrams * factor),
    carbsGrams: round(food.carbsGrams * factor),
    fatGrams: round(food.fatGrams * factor),
    source: food.source
  };
}

function round(value: number): number {
  return Math.round(value * 10) / 10;
}
