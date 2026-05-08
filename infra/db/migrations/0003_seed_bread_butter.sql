INSERT INTO food_items (name, normalized_name, source, serving_grams, calories, protein_grams, carbs_grams, fat_grams)
SELECT *
FROM (
  VALUES
    ('Bread', 'bread', 'generic_usda', 100, 265, 9, 49, 3.2),
    ('Butter', 'butter', 'generic_usda', 100, 717, 0.9, 0.1, 81.1)
) AS food(name, normalized_name, source, serving_grams, calories, protein_grams, carbs_grams, fat_grams)
WHERE NOT EXISTS (
  SELECT 1
  FROM food_items
  WHERE user_id IS NULL
    AND normalized_name = food.normalized_name
);
