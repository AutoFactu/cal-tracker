import { serve } from "@hono/node-server";
import { ActionExecutor } from "./actions/executor.js";
import { AuthService } from "./auth/service.js";
import { loadConfig } from "./config/env.js";
import { LocalBgeM3EmbeddingProvider } from "./embeddings/provider.js";
import { createApp } from "./http/app.js";
import { MemoryRetrievalService } from "./memory/retrieval.js";
import { LocalNutritionProvider, NutritionProviderChain, OpenFoodFactsProvider, UsdaNutritionProvider } from "./nutrition/provider.js";
import { PostgresRepository } from "./repository/postgres.js";
import { RemoteSpeechToTextProvider } from "./stt/speechToTextProvider.js";

const config = loadConfig();
const repository = new PostgresRepository(config.DATABASE_URL);
const authService = new AuthService(config, repository);
const nutritionProvider = new NutritionProviderChain([
  new OpenFoodFactsProvider(),
  new LocalNutritionProvider(repository),
  new UsdaNutritionProvider(),
]);
const embeddingProvider = config.EMBEDDING_BASE_URL
  ? new LocalBgeM3EmbeddingProvider(config.EMBEDDING_BASE_URL, config.EMBEDDING_MODEL, config.EMBEDDING_DIMENSIONS)
  : undefined;
const memoryRetrievalService = new MemoryRetrievalService(repository, embeddingProvider);
const actionExecutor = new ActionExecutor(config, repository, nutritionProvider, memoryRetrievalService);
const sttProvider = new RemoteSpeechToTextProvider(config.STT_API_KEY, config.STT_MODEL, config.STT_BASE_URL);
const app = createApp({ config, repository, authService, actionExecutor, sttProvider });

serve({ fetch: app.fetch, port: config.PORT });
console.log(`Backend listening on ${config.APP_BASE_URL}`);
