CREATE TABLE IF NOT EXISTS food_search_documents (
  food_item_id uuid PRIMARY KEY REFERENCES food_items(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  locale text NOT NULL,
  scope text NOT NULL,
  search_text text NOT NULL,
  rank_bucket integer NOT NULL,
  source text NOT NULL,
  external_source text,
  data_type text,
  food_key text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO food_search_documents (
  food_item_id,
  user_id,
  locale,
  scope,
  search_text,
  rank_bucket,
  source,
  external_source,
  data_type,
  food_key,
  updated_at
)
SELECT
  id,
  user_id,
  CASE
    WHEN food_key IN ('es', 'en') THEN food_key
    WHEN external_source = 'usda_fdc' THEN 'en'
    ELSE 'any'
  END AS locale,
  CASE
    WHEN user_id IS NOT NULL THEN 'generic'
    WHEN source = 'openfoodfacts' AND food_key = 'es' THEN 'generic'
    WHEN source = 'openfoodfacts' THEN 'market'
    WHEN data_type = 'Branded' OR source = 'usda_branded' THEN 'market'
    ELSE 'generic'
  END AS scope,
  trim(regexp_replace(concat_ws(' ', normalized_name, canonical_name, brand, food_category), '\s+', ' ', 'g')) AS search_text,
  CASE
    WHEN user_id IS NOT NULL THEN 0
    WHEN source = 'openfoodfacts' AND food_key = 'es' THEN 1
    WHEN data_type = 'SR Legacy' THEN 2
    WHEN data_type = 'Foundation' THEN 3
    WHEN data_type = 'Survey (FNDDS)' THEN 4
    WHEN source = 'openfoodfacts' AND food_key = 'en' THEN 7
    WHEN data_type = 'Branded' THEN 8
    ELSE 6
  END AS rank_bucket,
  source,
  external_source,
  data_type,
  food_key,
  now()
FROM food_items
WHERE trim(regexp_replace(concat_ws(' ', normalized_name, canonical_name, brand, food_category), '\s+', ' ', 'g')) <> ''
ON CONFLICT (food_item_id) DO UPDATE SET
  user_id = EXCLUDED.user_id,
  locale = EXCLUDED.locale,
  scope = EXCLUDED.scope,
  search_text = EXCLUDED.search_text,
  rank_bucket = EXCLUDED.rank_bucket,
  source = EXCLUDED.source,
  external_source = EXCLUDED.external_source,
  data_type = EXCLUDED.data_type,
  food_key = EXCLUDED.food_key,
  updated_at = now();

CREATE INDEX IF NOT EXISTS food_search_documents_generic_es_trgm_idx
  ON food_search_documents USING gin (search_text gin_trgm_ops)
  WHERE scope = 'generic' AND locale = 'es';

CREATE INDEX IF NOT EXISTS food_search_documents_generic_en_trgm_idx
  ON food_search_documents USING gin (search_text gin_trgm_ops)
  WHERE scope = 'generic' AND locale = 'en';

CREATE INDEX IF NOT EXISTS food_search_documents_market_trgm_idx
  ON food_search_documents USING gin (search_text gin_trgm_ops)
  WHERE scope = 'market';

CREATE INDEX IF NOT EXISTS food_search_documents_scope_locale_rank_idx
  ON food_search_documents (scope, locale, rank_bucket);

CREATE INDEX IF NOT EXISTS food_search_documents_user_idx
  ON food_search_documents (user_id)
  WHERE user_id IS NOT NULL;
