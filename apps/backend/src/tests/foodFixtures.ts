import type { InMemoryRepository } from "../repository/inMemory.js";

export function seedTestFoods(repository: InMemoryRepository): void {
  for (const food of [
    { name: "Egg", normalizedName: "egg", source: "test_fixture", servingGrams: 50, calories: 72, proteinGrams: 6.3, carbsGrams: 0.4, fatGrams: 4.8 },
    { name: "Chicken breast", normalizedName: "chicken breast", source: "test_fixture", servingGrams: 100, calories: 165, proteinGrams: 31, carbsGrams: 0, fatGrams: 3.6 },
    { name: "Cooked rice", normalizedName: "rice", source: "test_fixture", servingGrams: 100, calories: 130, proteinGrams: 2.7, carbsGrams: 28, fatGrams: 0.3 },
    { name: "Oats", normalizedName: "oats", source: "test_fixture", servingGrams: 100, calories: 389, proteinGrams: 16.9, carbsGrams: 66.3, fatGrams: 6.9 },
    { name: "Milk", normalizedName: "milk", source: "test_fixture", servingGrams: 250, calories: 122, proteinGrams: 8.1, carbsGrams: 12, fatGrams: 4.8 },
    { name: "Bread", normalizedName: "bread", source: "test_fixture", servingGrams: 100, calories: 265, proteinGrams: 9, carbsGrams: 49, fatGrams: 3.2 },
    { name: "Butter", normalizedName: "butter", source: "test_fixture", servingGrams: 100, calories: 717, proteinGrams: 0.9, carbsGrams: 0.1, fatGrams: 81.1 },
    { name: "Ham", normalizedName: "ham", source: "test_fixture", servingGrams: 100, calories: 145, proteinGrams: 21, carbsGrams: 1.5, fatGrams: 5.5 }
  ]) {
    void repository.upsertFoodItem(food);
  }
}
