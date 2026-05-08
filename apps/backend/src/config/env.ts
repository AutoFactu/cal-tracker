import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_ACCESS_SECRET: z.string().min(32),
  SESSION_TOKEN_PEPPER: z.string().min(32),
  OPENROUTER_API_KEY: z.string().min(1),
  OPENROUTER_MODEL: z.string().min(1),
  STT_API_KEY: z.string().min(1),
  STT_MODEL: z.string().min(1).default("whisper-large-v3-turbo"),
  STT_BASE_URL: z.string().url().default("https://api.groq.com/openai/v1"),
  EMBEDDING_PROVIDER: z.string().min(1).default("local"),
  EMBEDDING_MODEL: z.string().min(1).default("bge-m3"),
  EMBEDDING_DIMENSIONS: z.coerce.number().int().positive().default(1024),
  EMBEDDING_BASE_URL: z.string().url().optional(),
  APP_BASE_URL: z.string().url(),
  CORS_ALLOWED_ORIGINS: z.string().min(1),
  TRUSTED_AUTO_COMMIT_THRESHOLD: z.coerce.number().min(0).max(1).default(0.92),
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z.string().default("development")
});

export type AppConfig = z.infer<typeof envSchema> & {
  corsAllowedOrigins: string[];
};

export function loadConfig(input: NodeJS.ProcessEnv = process.env): AppConfig {
  const isTest = input.NODE_ENV === "test";
  const defaults = isTest
    ? {
        DATABASE_URL: "postgres://cal_tracker:cal_tracker@localhost:5432/cal_tracker",
        JWT_ACCESS_SECRET: "test-access-secret-with-more-than-32-characters",
        SESSION_TOKEN_PEPPER: "test-session-pepper-with-more-than-32-characters",
        OPENROUTER_API_KEY: "test-openrouter-key",
        OPENROUTER_MODEL: "test-model",
        STT_API_KEY: "test-stt-key",
        STT_MODEL: "test-stt-model",
        STT_BASE_URL: "http://localhost:9999",
        EMBEDDING_PROVIDER: "local",
        EMBEDDING_MODEL: "bge-m3",
        EMBEDDING_DIMENSIONS: "1024",
        EMBEDDING_BASE_URL: "http://localhost:8081",
        APP_BASE_URL: "http://localhost:3000",
        CORS_ALLOWED_ORIGINS: "http://localhost:3000",
        TRUSTED_AUTO_COMMIT_THRESHOLD: "0.92",
        PORT: "3000",
        NODE_ENV: "test"
      }
    : {};

  const parsed = envSchema.parse({ ...defaults, ...input });
  return {
    ...parsed,
    corsAllowedOrigins: parsed.CORS_ALLOWED_ORIGINS.split(",").map((origin) => origin.trim())
  };
}
