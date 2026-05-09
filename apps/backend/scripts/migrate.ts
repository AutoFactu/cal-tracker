import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import postgres from "postgres";
import { loadConfig } from "../src/config/env.js";
import { databaseSchema, prepareSchema } from "./schema.js";

const config = loadConfig();
const sql = postgres(config.DATABASE_URL, { max: 1 });
const migrationDir = resolve(process.cwd(), "../../infra/db/migrations");
const schema = databaseSchema();

await prepareSchema(sql, schema);

await sql`CREATE TABLE IF NOT EXISTS schema_migrations (filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`;

for (const filename of readdirSync(migrationDir).filter((name) => name.endsWith(".sql")).sort()) {
  const applied = await sql`SELECT filename FROM schema_migrations WHERE filename = ${filename}`;
  if (applied.length > 0) continue;
  const body = readFileSync(resolve(migrationDir, filename), "utf8");
  await sql.begin(async (tx) => {
    await tx.unsafe(body);
    await tx`INSERT INTO schema_migrations (filename) VALUES (${filename})`;
  });
  console.log(`Applied ${filename} to ${schema}`);
}

await sql.end();
