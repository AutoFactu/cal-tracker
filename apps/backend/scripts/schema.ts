import type { Sql } from "postgres";

export function databaseSchema(input: NodeJS.ProcessEnv = process.env): string {
  const schema = input.DATABASE_SCHEMA?.trim() || "public";
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(schema)) {
    throw new Error(`Invalid DATABASE_SCHEMA: ${schema}`);
  }
  return schema;
}

export async function prepareSchema(sql: Sql, schema: string): Promise<void> {
  if (schema === "public") return;
  const identifier = quoteIdentifier(schema);
  await sql.unsafe(`CREATE SCHEMA IF NOT EXISTS ${identifier}`);
  await sql.unsafe(`SET search_path TO ${identifier}, public`);
}

function quoteIdentifier(value: string): string {
  return `"${value.replaceAll('"', '""')}"`;
}
