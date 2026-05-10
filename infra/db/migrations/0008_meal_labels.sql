ALTER TABLE meals
  ADD COLUMN IF NOT EXISTS meal_type text,
  ADD COLUMN IF NOT EXISTS meal_type_label text;

ALTER TABLE meals
  DROP CONSTRAINT IF EXISTS meals_meal_type_check;

ALTER TABLE meals
  ADD CONSTRAINT meals_meal_type_check
  CHECK (
    (
      meal_type IS NULL
      AND meal_type_label IS NULL
    )
    OR (
      meal_type IN (
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'pre_workout',
        'post_workout',
        'other'
      )
      AND meal_type_label IS NOT NULL
      AND btrim(meal_type_label) <> ''
      AND char_length(meal_type_label) <= 40
    )
  );
