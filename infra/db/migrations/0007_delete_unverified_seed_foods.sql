WITH unverified_default_templates AS (
  SELECT template.id
  FROM meal_templates template
  WHERE template.deleted_at IS NULL
    AND template.normalized_title = 'usual breakfast'
    AND EXISTS (
      SELECT 1
      FROM meal_template_items item
      WHERE item.template_id = template.id
        AND item.external_source IS NULL
        AND item.external_id IS NULL
        AND item.name IN ('Oats', 'Milk', 'Egg')
    )
)
DELETE FROM food_memories memory
WHERE memory.meal_template_id IN (SELECT id FROM unverified_default_templates);

WITH unverified_default_templates AS (
  SELECT template.id
  FROM meal_templates template
  WHERE template.deleted_at IS NULL
    AND template.normalized_title = 'usual breakfast'
    AND EXISTS (
      SELECT 1
      FROM meal_template_items item
      WHERE item.template_id = template.id
        AND item.external_source IS NULL
        AND item.external_id IS NULL
        AND item.name IN ('Oats', 'Milk', 'Egg')
    )
)
DELETE FROM meal_templates template
WHERE template.id IN (SELECT id FROM unverified_default_templates);

DELETE FROM food_items
WHERE source = 'generic_usda'
  AND external_source IS NULL
  AND external_id IS NULL;
