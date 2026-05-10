CREATE INDEX IF NOT EXISTS food_items_usda_normalized_name_trgm_idx
  ON food_items USING gin (normalized_name gin_trgm_ops)
  WHERE external_source = 'usda_fdc';

CREATE INDEX IF NOT EXISTS food_items_usda_canonical_name_trgm_idx
  ON food_items USING gin (canonical_name gin_trgm_ops)
  WHERE external_source = 'usda_fdc' AND canonical_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_usda_brand_trgm_idx
  ON food_items USING gin (brand gin_trgm_ops)
  WHERE external_source = 'usda_fdc' AND brand IS NOT NULL;
