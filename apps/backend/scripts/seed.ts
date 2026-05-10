import postgres from "postgres";
import { loadConfig } from "../src/config/env.js";
import { databaseSchema, prepareSchema } from "./schema.js";

const config = loadConfig();
const sql = postgres(config.DATABASE_URL, { max: 1 });
const schema = databaseSchema();

await prepareSchema(sql, schema);

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

console.log("Seeded embedding model metadata. Food items must be imported from a trusted provider with provenance.");
await sql.end();
