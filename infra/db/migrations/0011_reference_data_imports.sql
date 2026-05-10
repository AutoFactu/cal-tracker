CREATE TABLE IF NOT EXISTS reference_data_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL,
  target_schema text NOT NULL,
  manifest_sha256 text NOT NULL,
  manifest_json jsonb NOT NULL,
  food_count integer NOT NULL,
  portion_count integer NOT NULL,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS reference_data_imports_source_schema_manifest_unique
  ON reference_data_imports (source, target_schema, manifest_sha256);

CREATE INDEX IF NOT EXISTS reference_data_imports_source_imported_at_idx
  ON reference_data_imports (source, imported_at DESC);
