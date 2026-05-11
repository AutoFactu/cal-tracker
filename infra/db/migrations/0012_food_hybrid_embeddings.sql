CREATE TABLE IF NOT EXISTS food_item_embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  food_item_id uuid NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
  embedding_model_id uuid NOT NULL REFERENCES embedding_models(id),
  embedded_text text NOT NULL,
  embedded_text_hash text NOT NULL,
  embedding vector(1024) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (food_item_id, embedding_model_id)
);

CREATE INDEX IF NOT EXISTS embedding_models_lookup_idx
  ON embedding_models (provider, model, dimensions);

CREATE INDEX IF NOT EXISTS food_item_embeddings_model_idx
  ON food_item_embeddings (embedding_model_id);

CREATE INDEX IF NOT EXISTS food_item_embeddings_hash_idx
  ON food_item_embeddings (embedding_model_id, embedded_text_hash);

CREATE TABLE IF NOT EXISTS user_food_feedback_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  food_item_id uuid NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
  query_text text NOT NULL,
  normalized_query text NOT NULL,
  action text NOT NULL,
  metadata_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_food_feedback_events_user_created_idx
  ON user_food_feedback_events (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS user_food_feedback_events_user_food_idx
  ON user_food_feedback_events (user_id, food_item_id, created_at DESC);

CREATE INDEX IF NOT EXISTS user_food_feedback_events_query_idx
  ON user_food_feedback_events (user_id, normalized_query);

CREATE TABLE IF NOT EXISTS user_food_preferences (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  food_item_id uuid NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
  affinity_score numeric(8,4) NOT NULL DEFAULT 0,
  positive_feedback_count integer NOT NULL DEFAULT 0,
  negative_feedback_count integer NOT NULL DEFAULT 0,
  last_feedback_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, food_item_id)
);

CREATE INDEX IF NOT EXISTS user_food_preferences_user_score_idx
  ON user_food_preferences (user_id, affinity_score DESC, updated_at DESC);

CREATE INDEX IF NOT EXISTS user_food_preferences_food_idx
  ON user_food_preferences (food_item_id);
