import { randomUUID } from "node:crypto";
import type { Context, Next } from "hono";

export async function requestIdMiddleware(c: Context, next: Next) {
  const traceId = c.req.header("x-request-id") ?? randomUUID();
  c.set("traceId", traceId);
  c.header("x-request-id", traceId);
  await next();
}

export function getTraceId(c: Context): string {
  return c.get("traceId") ?? randomUUID();
}
