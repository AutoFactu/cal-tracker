CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  display_name text NOT NULL,
  trusted_mode_enabled boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS users_active_email_unique
  ON users (lower(email))
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS user_credentials (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  password_hash text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  rotated_at timestamptz
);

CREATE INDEX IF NOT EXISTS auth_sessions_active_idx
  ON auth_sessions (user_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS nutrition_targets (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS food_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  normalized_name text NOT NULL,
  canonical_name text,
  brand text,
  barcode text,
  source text NOT NULL,
  external_source text,
  external_id text,
  source_url text,
  license text,
  fetched_at timestamptz,
  serving_grams numeric(10,2) NOT NULL DEFAULT 100,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meal_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  phrase text NOT NULL,
  title text NOT NULL,
  status text NOT NULL,
  confidence numeric(5,4) NOT NULL,
  requires_confirmation boolean NOT NULL DEFAULT true,
  trusted_auto_commit_eligible boolean NOT NULL DEFAULT false,
  source text NOT NULL,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meal_proposal_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id uuid NOT NULL REFERENCES meal_proposals(id) ON DELETE CASCADE,
  food_item_id uuid REFERENCES food_items(id),
  name text NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit text NOT NULL,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  source text NOT NULL DEFAULT 'snapshot',
  original_text text,
  canonical_name text,
  external_source text,
  external_id text,
  source_url text,
  license text,
  confidence numeric(5,4),
  needs_review boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS meals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  proposal_id uuid REFERENCES meal_proposals(id),
  title text NOT NULL,
  occurred_at timestamptz NOT NULL,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS meals_user_occurred_at_idx
  ON meals (user_id, occurred_at DESC)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS meal_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id uuid NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
  name text NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit text NOT NULL,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  source text NOT NULL DEFAULT 'snapshot',
  original_text text,
  canonical_name text,
  external_source text,
  external_id text,
  source_url text,
  license text,
  confidence numeric(5,4),
  needs_review boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS meal_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  normalized_title text NOT NULL,
  trusted_auto_commit_enabled boolean NOT NULL DEFAULT false,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS meal_template_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES meal_templates(id) ON DELETE CASCADE,
  name text NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit text NOT NULL,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  source text NOT NULL DEFAULT 'snapshot',
  original_text text,
  canonical_name text,
  external_source text,
  external_id text,
  source_url text,
  license text,
  confidence numeric(5,4),
  needs_review boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS food_memories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  normalized_text text NOT NULL,
  label text NOT NULL,
  meal_template_id uuid REFERENCES meal_templates(id),
  usage_count integer NOT NULL DEFAULT 0,
  confidence numeric(5,4) NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS food_memories_user_normalized_unique
  ON food_memories (user_id, normalized_text);

CREATE TABLE IF NOT EXISTS embedding_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  model text NOT NULL,
  dimensions integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS food_memory_embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  food_memory_id uuid NOT NULL REFERENCES food_memories(id) ON DELETE CASCADE,
  embedding_model_id uuid NOT NULL REFERENCES embedding_models(id),
  embedding vector(1024) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meal_id uuid REFERENCES meals(id),
  proposal_id uuid REFERENCES meal_proposals(id),
  correction_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS confirmation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action_id text NOT NULL,
  input_json jsonb NOT NULL,
  status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE IF NOT EXISTS action_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action_id text NOT NULL,
  source text NOT NULL,
  input_json jsonb NOT NULL,
  output_json jsonb,
  error_json jsonb,
  confirmation_status text NOT NULL,
  trace_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  latency_ms integer NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  metadata_json jsonb NOT NULL,
  trace_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agent_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source text NOT NULL,
  scopes text[] NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS outbox_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type text NOT NULL,
  payload_json jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempts integer NOT NULL DEFAULT 0,
  run_after timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
