ALTER TABLE food_items
  ADD COLUMN IF NOT EXISTS canonical_name text,
  ADD COLUMN IF NOT EXISTS external_source text,
  ADD COLUMN IF NOT EXISTS external_id text,
  ADD COLUMN IF NOT EXISTS source_url text,
  ADD COLUMN IF NOT EXISTS license text,
  ADD COLUMN IF NOT EXISTS fetched_at timestamptz;

CREATE INDEX IF NOT EXISTS food_items_external_source_id_idx
  ON food_items (external_source, external_id)
  WHERE external_source IS NOT NULL AND external_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS food_items_canonical_name_idx
  ON food_items (canonical_name)
  WHERE canonical_name IS NOT NULL;

CREATE TABLE IF NOT EXISTS food_aliases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  alias_text text NOT NULL,
  normalized_alias text NOT NULL,
  locale text NOT NULL DEFAULT 'und',
  canonical_english_name text NOT NULL,
  food_item_id uuid REFERENCES food_items(id) ON DELETE SET NULL,
  source text NOT NULL,
  confidence numeric(5,4) NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS food_aliases_normalized_alias_idx
  ON food_aliases (normalized_alias);

ALTER TABLE meal_proposal_items
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'snapshot',
  ADD COLUMN IF NOT EXISTS original_text text,
  ADD COLUMN IF NOT EXISTS canonical_name text,
  ADD COLUMN IF NOT EXISTS external_source text,
  ADD COLUMN IF NOT EXISTS external_id text,
  ADD COLUMN IF NOT EXISTS source_url text,
  ADD COLUMN IF NOT EXISTS license text,
  ADD COLUMN IF NOT EXISTS confidence numeric(5,4),
  ADD COLUMN IF NOT EXISTS needs_review boolean NOT NULL DEFAULT false;

ALTER TABLE meal_items
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'snapshot',
  ADD COLUMN IF NOT EXISTS original_text text,
  ADD COLUMN IF NOT EXISTS canonical_name text,
  ADD COLUMN IF NOT EXISTS external_source text,
  ADD COLUMN IF NOT EXISTS external_id text,
  ADD COLUMN IF NOT EXISTS source_url text,
  ADD COLUMN IF NOT EXISTS license text,
  ADD COLUMN IF NOT EXISTS confidence numeric(5,4),
  ADD COLUMN IF NOT EXISTS needs_review boolean NOT NULL DEFAULT false;

ALTER TABLE meal_template_items
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'snapshot',
  ADD COLUMN IF NOT EXISTS original_text text,
  ADD COLUMN IF NOT EXISTS canonical_name text,
  ADD COLUMN IF NOT EXISTS external_source text,
  ADD COLUMN IF NOT EXISTS external_id text,
  ADD COLUMN IF NOT EXISTS source_url text,
  ADD COLUMN IF NOT EXISTS license text,
  ADD COLUMN IF NOT EXISTS confidence numeric(5,4),
  ADD COLUMN IF NOT EXISTS needs_review boolean NOT NULL DEFAULT false;
