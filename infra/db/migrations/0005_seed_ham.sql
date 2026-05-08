INSERT INTO food_items (name, normalized_name, source, serving_grams, calories, protein_grams, carbs_grams, fat_grams)
SELECT 'Ham', 'ham', 'generic_usda', 100, 145, 21, 1.5, 5.5
WHERE NOT EXISTS (
  SELECT 1
  FROM food_items
  WHERE user_id IS NULL
    AND normalized_name = 'ham'
);
