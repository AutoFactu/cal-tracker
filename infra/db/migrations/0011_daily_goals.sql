ALTER TABLE nutrition_targets
  ADD COLUMN IF NOT EXISTS hydration_goal_glasses integer NOT NULL DEFAULT 12;

CREATE TABLE IF NOT EXISTS daily_goal_snapshots (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_date date NOT NULL,
  calories integer NOT NULL,
  protein_grams numeric(10,2) NOT NULL,
  carbs_grams numeric(10,2) NOT NULL,
  fat_grams numeric(10,2) NOT NULL,
  hydration_goal_glasses integer NOT NULL DEFAULT 12,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_date)
);

CREATE INDEX IF NOT EXISTS daily_goal_snapshots_user_date_idx
  ON daily_goal_snapshots (user_id, target_date DESC);

INSERT INTO daily_goal_snapshots (
  user_id,
  target_date,
  calories,
  protein_grams,
  carbs_grams,
  fat_grams,
  hydration_goal_glasses
)
SELECT
  user_id,
  CURRENT_DATE,
  calories,
  protein_grams,
  carbs_grams,
  fat_grams,
  hydration_goal_glasses
FROM nutrition_targets
ON CONFLICT (user_id, target_date) DO NOTHING;
