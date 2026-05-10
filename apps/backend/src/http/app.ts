import {
  agentRunRequestSchema,
  executeActionRequestSchema,
  loginRequestSchema,
  logoutRequestSchema,
  passwordResetConfirmSchema,
  passwordResetRequestSchema,
  refreshRequestSchema,
  registerRequestSchema,
  settingsUpdateSchema,
  type ActionContext,
  type ActionSource
} from "@cal-tracker/contracts";
import { cors } from "hono/cors";
import { Hono, type Context } from "hono";
import { ActionExecutor } from "../actions/executor.js";
import { AuthService } from "../auth/service.js";
import type { AppConfig } from "../config/env.js";
import { authMiddleware } from "../middleware/auth.js";
import { formatErrorResponse } from "../middleware/errors.js";
import { getTraceId, requestIdMiddleware } from "../middleware/requestContext.js";
import type { AppRepository, StoredUser } from "../repository/types.js";
import type { SpeechToTextProvider, TranscriptionResult } from "../stt/speechToTextProvider.js";
import { readAudioBuffer, validateAudioUpload } from "../stt/audioValidation.js";
import { AgentService } from "../agent/agentService.js";
import type { ChatAgentProvider } from "../agent/chatAgentProvider.js";
import { RemoteChatAgentProvider } from "../agent/chatAgentProvider.js";

export function createApp(input: {
  config: AppConfig;
  repository: AppRepository;
  authService: AuthService;
  actionExecutor: ActionExecutor;
  sttProvider: SpeechToTextProvider;
  agentProvider?: ChatAgentProvider;
}) {
  const app = new Hono<{ Variables: { authUser: StoredUser; traceId: string } }>();
  const { config, repository, authService, actionExecutor, sttProvider, agentProvider } = input;

  const resolvedAgentProvider = agentProvider ?? new RemoteChatAgentProvider(config.OPENROUTER_API_KEY);
  const agentService = new AgentService(resolvedAgentProvider, actionExecutor, config.OPENROUTER_MODEL);

  app.use("*", requestIdMiddleware);
  app.use("*", cors({
    origin: (origin) => {
      if (!origin) return "";
      return config.corsAllowedOrigins.includes(origin) ? origin : "";
    },
    allowHeaders: ["Authorization", "Content-Type", "X-Request-Id"],
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  }));

  app.onError((err, c) => {
    return formatErrorResponse(c, err);
  });

  app.get("/v1/health", (c) => c.json({ ok: true, service: "cal-tracker-backend" }));

  app.post("/v1/auth/register", async (c) => c.json(await authService.register(registerRequestSchema.parse(await c.req.json()))));
  app.post("/v1/auth/login", async (c) => c.json(await authService.login(loginRequestSchema.parse(await c.req.json()))));
  app.post("/v1/auth/refresh", async (c) => {
    const body = refreshRequestSchema.parse(await c.req.json());
    return c.json(await authService.refresh(body.refreshToken));
  });
  app.post("/v1/auth/logout", async (c) => {
    const body = logoutRequestSchema.parse(await c.req.json().catch(() => ({})));
    await authService.logout(body.refreshToken);
    return c.json({ ok: true });
  });
  app.post("/v1/auth/password-reset/request", async (c) => {
    const body = passwordResetRequestSchema.parse(await c.req.json());
    return c.json(await authService.requestPasswordReset(body.email));
  });
  app.post("/v1/auth/password-reset/confirm", async (c) => {
    const body = passwordResetConfirmSchema.parse(await c.req.json());
    return c.json({ ok: await authService.confirmPasswordReset(body.token, body.newPassword) });
  });

  app.use("/v1/*", async (c, next) => {
    const publicPaths = ["/v1/health", "/v1/auth/register", "/v1/auth/login", "/v1/auth/refresh", "/v1/auth/logout", "/v1/auth/password-reset/request", "/v1/auth/password-reset/confirm"];
    if (publicPaths.includes(new URL(c.req.url).pathname)) return next();
    return authMiddleware(config, repository)(c, next);
  });

  app.get("/v1/auth/me", (c) => c.json(publicUser(c.get("authUser"))));
  app.post("/v1/auth/logout-all", async (c) => {
    const user = c.get("authUser");
    await authService.logoutAll(user.id);
    return c.json({ ok: true });
  });
  app.put("/v1/settings", async (c) => {
    const user = c.get("authUser");
    const body = settingsUpdateSchema.parse(await c.req.json());
    return c.json({ user: publicUser(await repository.updateTrustedMode(user.id, body.trustedModeEnabled)) });
  });

  app.get("/v1/actions", (c) => c.json({ actions: actionExecutor.listActions() }));
  app.post("/v1/actions/:actionId/execute", async (c) => {
    const user = c.get("authUser");
    const body = executeActionRequestSchema.parse(await c.req.json());
    const context = buildActionContext(c, user, body.source);
    return c.json(await actionExecutor.execute(c.req.param("actionId"), body.input, context));
  });

  app.post("/v1/agent/runs", async (c) => {
    const user = c.get("authUser");
    const body = agentRunRequestSchema.parse(await c.req.json());
    const context = buildActionContext(c, user, body.source);
    const result = await agentService.run(body.text, context);
    return c.json(result);
  });

  app.post("/v1/stt/transcriptions", async (c) => {
    const user = c.get("authUser");
    const traceId = getTraceId(c);
    let body: Record<string, unknown>;
    try {
      body = await c.req.parseBody({ all: true });
    } catch (error) {
      console.warn("stt.transcription.invalid_multipart", {
        traceId,
        userId: user.id,
        error: error instanceof Error ? error.message : String(error),
      });
      return c.json({
        error: {
          code: "validation_error",
          message: "Invalid multipart/form-data request.",
          traceId,
        },
      }, 400);
    }
    const audioField = body.audio;
    if (!audioField || (Array.isArray(audioField) && audioField.length === 0)) {
      console.warn("stt.transcription.missing_audio", {
        traceId,
        userId: user.id,
      });
      return c.json({
        error: {
          code: "validation_error",
          message: "Missing audio file.",
          traceId,
        },
      }, 400);
    }
    const file = Array.isArray(audioField) ? audioField[0] : audioField;

    const validation = validateAudioUpload(file);
    if (!validation.ok) {
      console.warn("stt.transcription.invalid_audio", {
        traceId,
        userId: user.id,
        status: validation.status,
        error: validation.error,
      });
      return c.json({ error: { code: "validation_error", message: validation.error, traceId } }, validation.status);
    }

    const buffer = await readAudioBuffer(file);
    console.info("stt.transcription.started", {
      traceId,
      userId: user.id,
      filename: validation.filename,
      mimeType: validation.mimeType,
      bytes: buffer.byteLength,
    });

    let result: TranscriptionResult;
    try {
      result = await sttProvider.transcribe({
        audio: buffer,
        filename: validation.filename,
        mimeType: validation.mimeType,
        userId: user.id,
        traceId,
      });
    } catch (error) {
      console.error("stt.transcription.failed", {
        traceId,
        userId: user.id,
        filename: validation.filename,
        mimeType: validation.mimeType,
        bytes: buffer.byteLength,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }

    console.info("stt.transcription.completed", {
      traceId,
      userId: user.id,
      provider: result.provider,
      model: result.model,
      transcriptLength: result.text.length,
    });

    return c.json({
      transcript: result.text,
      provider: result.provider,
      model: result.model,
      traceId,
    });
  });

  app.post("/v1/meals/proposals", async (c) => {
    const user = c.get("authUser");
    const body = await c.req.json();
    return c.json(await actionExecutor.execute("propose_meal_log", body, buildActionContext(c, user, "flutter")));
  });
  app.post("/v1/meals/proposals/:id/commit", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("commit_meal", { ...(await c.req.json().catch(() => ({}))), proposalId: c.req.param("id") }, buildActionContext(c, user, "flutter")));
  });
  app.post("/v1/meals/:id/correct", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("correct_meal", { ...(await c.req.json()), mealId: c.req.param("id") }, buildActionContext(c, user, "flutter")));
  });
  app.delete("/v1/meals/:id", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("delete_meal", { mealId: c.req.param("id"), confirmationToken: c.req.query("confirmationToken") }, buildActionContext(c, user, "flutter")));
  });
  app.get("/v1/summary/daily", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("get_daily_summary", { date: c.req.query("date") }, buildActionContext(c, user, "flutter")));
  });
  app.get("/v1/meals", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("get_meal_history", { limit: Number(c.req.query("limit") ?? 25) }, buildActionContext(c, user, "flutter")));
  });
  app.get("/v1/meal-templates", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("get_usual_meals", {}, buildActionContext(c, user, "flutter")));
  });
  app.post("/v1/meal-templates", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute("create_meal_template", await c.req.json(), buildActionContext(c, user, "flutter")));
  });
  app.put("/v1/meal-templates/:id", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute(
      "update_meal_template",
      { ...(await c.req.json()), templateId: c.req.param("id") },
      buildActionContext(c, user, "flutter")
    ));
  });
  app.delete("/v1/meal-templates/:id", async (c) => {
    const user = c.get("authUser");
    return c.json(await actionExecutor.execute(
      "delete_meal_template",
      { templateId: c.req.param("id") },
      buildActionContext(c, user, "flutter")
    ));
  });

  return app;
}

function buildActionContext(c: Context, user: StoredUser, source: ActionSource): ActionContext {
  return {
    actorUserId: user.id,
    actorType: source === "internal_agent" ? "internal_agent" : "user",
    source,
    scopes: user.scopes,
    timezone: c.req.header("x-user-timezone") ?? "UTC",
    locale: c.req.header("accept-language")?.split(",")[0] ?? "en-US",
    trustedModeEnabled: user.trustedModeEnabled,
    traceId: getTraceId(c)
  };
}

function publicUser(user: StoredUser) {
  const { passwordHash: _passwordHash, scopes: _scopes, ...publicValue } = user;
  return publicValue;
}
