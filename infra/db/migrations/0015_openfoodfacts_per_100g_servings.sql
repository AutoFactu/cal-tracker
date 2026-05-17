-- Open Food Facts nutriment fields imported by this project come from *_100g
-- values. Keep the primary food row on a 100 g basis; packaged serving sizes
-- belong in food_portions.
UPDATE food_items
SET serving_grams = 100.00
WHERE (external_source = 'openfoodfacts' OR source = 'openfoodfacts')
  AND serving_grams IS DISTINCT FROM 100.00;
