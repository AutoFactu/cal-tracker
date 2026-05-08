import postgres from "postgres";
import { loadConfig } from "../src/config/env.js";

const config = loadConfig();
const sql = postgres(config.DATABASE_URL, { max: 1 });

await sql`
  INSERT INTO embedding_models (provider, model, dimensions)
  SELECT ${config.EMBEDDING_PROVIDER}, ${config.EMBEDDING_MODEL}, ${config.EMBEDDING_DIMENSIONS}
  WHERE NOT EXISTS (
    SELECT 1 FROM embedding_models
    WHERE provider = ${config.EMBEDDING_PROVIDER}
      AND model = ${config.EMBEDDING_MODEL}
      AND dimensions = ${config.EMBEDDING_DIMENSIONS}
  )
`;

await sql`
  INSERT INTO food_items (name, normalized_name, source, serving_grams, calories, protein_grams, carbs_grams, fat_grams)
  VALUES
    ('Egg', 'egg', 'generic_usda', 50, 72, 6.3, 0.4, 4.8),
    ('Chicken breast', 'chicken breast', 'generic_usda', 100, 165, 31, 0, 3.6),
    ('Cooked rice', 'rice', 'generic_usda', 100, 130, 2.7, 28, 0.3),
    ('Oats', 'oats', 'generic_usda', 100, 389, 16.9, 66.3, 6.9),
    ('Milk', 'milk', 'generic_usda', 250, 122, 8.1, 12, 4.8)
  ON CONFLICT DO NOTHING
`;

console.log("Seeded generic food items and embedding model metadata.");
await sql.end();
