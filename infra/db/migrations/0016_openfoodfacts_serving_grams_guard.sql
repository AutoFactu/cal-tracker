CREATE OR REPLACE FUNCTION normalize_openfoodfacts_food_item_serving_grams()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.external_source = 'openfoodfacts' OR NEW.source = 'openfoodfacts' THEN
    NEW.serving_grams := 100.00;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS food_items_openfoodfacts_serving_grams_guard ON food_items;

CREATE TRIGGER food_items_openfoodfacts_serving_grams_guard
BEFORE INSERT OR UPDATE OF source, external_source, serving_grams
ON food_items
FOR EACH ROW
WHEN (NEW.external_source = 'openfoodfacts' OR NEW.source = 'openfoodfacts')
EXECUTE FUNCTION normalize_openfoodfacts_food_item_serving_grams();
