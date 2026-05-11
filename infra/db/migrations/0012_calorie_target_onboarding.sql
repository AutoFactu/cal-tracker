ALTER TABLE nutrition_targets
  ADD COLUMN IF NOT EXISTS calorie_target_configured boolean,
  ADD COLUMN IF NOT EXISTS calorie_target_source text,
  ADD COLUMN IF NOT EXISTS calorie_target_configured_at timestamptz;

UPDATE nutrition_targets
SET
  calorie_target_configured = TRUE,
  calorie_target_source = COALESCE(calorie_target_source, 'manual'),
  calorie_target_configured_at = COALESCE(calorie_target_configured_at, updated_at, now())
WHERE calorie_target_configured IS NULL;

UPDATE nutrition_targets
SET calorie_target_source = 'manual'
WHERE calorie_target_source IS NULL;

ALTER TABLE nutrition_targets
  ALTER COLUMN calorie_target_configured SET DEFAULT FALSE,
  ALTER COLUMN calorie_target_configured SET NOT NULL,
  ALTER COLUMN calorie_target_source SET DEFAULT 'default',
  ALTER COLUMN calorie_target_source SET NOT NULL;

ALTER TABLE daily_goal_snapshots
  ADD COLUMN IF NOT EXISTS calorie_target_configured boolean,
  ADD COLUMN IF NOT EXISTS calorie_target_source text,
  ADD COLUMN IF NOT EXISTS calorie_target_configured_at timestamptz;

UPDATE daily_goal_snapshots
SET
  calorie_target_configured = TRUE,
  calorie_target_source = COALESCE(calorie_target_source, 'manual'),
  calorie_target_configured_at = COALESCE(calorie_target_configured_at, updated_at, created_at, now())
WHERE calorie_target_configured IS NULL;

UPDATE daily_goal_snapshots
SET calorie_target_source = 'manual'
WHERE calorie_target_source IS NULL;

ALTER TABLE daily_goal_snapshots
  ALTER COLUMN calorie_target_configured SET DEFAULT FALSE,
  ALTER COLUMN calorie_target_configured SET NOT NULL,
  ALTER COLUMN calorie_target_source SET DEFAULT 'default',
  ALTER COLUMN calorie_target_source SET NOT NULL;
