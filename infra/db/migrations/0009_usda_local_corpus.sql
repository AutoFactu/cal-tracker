CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

ALTER TABLE food_items
  ADD COLUMN IF NOT EXISTS data_type text,
  ADD COLUMN IF NOT EXISTS food_category text,
  ADD COLUMN IF NOT EXISTS publication_date date,
  ADD COLUMN IF NOT EXISTS ndb_number text,
  ADD COLUMN IF NOT EXISTS food_key text,
  ADD COLUMN IF NOT EXISTS ingredients text,
  ADD COLUMN IF NOT EXISTS market_country text,
  ADD COLUMN IF NOT EXISTS household_serving_fulltext text,
  ADD COLUMN IF NOT EXISTS nutrients_json jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS food_items_external_source_id_lookup_idx
  ON food_items (external_source, external_id)
  WHERE external_source IS NOT NULL AND external_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_barcode_lookup_idx
  ON food_items (barcode)
  WHERE barcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_data_type_lookup_idx
  ON food_items (data_type)
  WHERE data_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_food_key_lookup_idx
  ON food_items (food_key)
  WHERE food_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_ndb_number_lookup_idx
  ON food_items (ndb_number)
  WHERE ndb_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_normalized_name_trgm_idx
  ON food_items USING gin (normalized_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS food_items_canonical_name_trgm_idx
  ON food_items USING gin (canonical_name gin_trgm_ops)
  WHERE canonical_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_brand_trgm_idx
  ON food_items USING gin (brand gin_trgm_ops)
  WHERE brand IS NOT NULL;

CREATE TABLE IF NOT EXISTS food_portions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  food_item_id uuid NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
  usda_portion_id text,
  amount numeric(10,4),
  unit text,
  modifier text,
  description text,
  gram_weight numeric(10,4) NOT NULL,
  normalized_aliases text[] NOT NULL DEFAULT '{}'::text[],
  kind text NOT NULL DEFAULT 'serving',
  source_description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS food_portions_food_usda_portion_unique
  ON food_portions (food_item_id, usda_portion_id)
  WHERE usda_portion_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_portions_food_item_id_idx
  ON food_portions (food_item_id);

CREATE INDEX IF NOT EXISTS food_portions_aliases_gin_idx
  ON food_portions USING gin (normalized_aliases);
