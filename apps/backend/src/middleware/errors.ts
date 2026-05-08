import type { Context } from "hono";
import { HTTPException } from "hono/http-exception";
import { ZodError } from "zod";
import { ActionExecutionError } from "../actions/executor.js";
import { AuthError } from "../auth/service.js";
import { getTraceId } from "./requestContext.js";

export function formatErrorResponse(c: Context, error: unknown) {
  const traceId = getTraceId(c);
  if (error instanceof ZodError) {
    return c.json({ error: { code: "validation_error", message: "Invalid request", traceId, details: error.flatten() } }, 400);
  }
  if (error instanceof AuthError) {
    return c.json({ error: { code: error.code, message: error.message, traceId } }, 401);
  }
  if (error instanceof ActionExecutionError) {
    const status = error.code === "permission_denied" ? 403 : 400;
    return c.json({ error: { code: error.code, message: error.message, traceId } }, status);
  }
  if (error instanceof HTTPException) {
    return c.json({ error: { code: "http_error", message: error.message, traceId } }, error.status);
  }
  const message = error instanceof Error ? error.message : "Unexpected error";
  return c.json({ error: { code: "internal_error", message, traceId } }, 500);
}
