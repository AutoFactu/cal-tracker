import { serve } from "@hono/node-server";
import { ActionExecutor } from "./actions/executor.js";
import { AuthService } from "./auth/service.js";
import { loadConfig } from "./config/env.js";
import { LocalBgeM3EmbeddingProvider } from "./embeddings/provider.js";
import { createApp } from "./http/app.js";
import { MemoryRetrievalService } from "./memory/retrieval.js";
import {
  CompositeFoodTextExtractor,
  DeterministicFoodTextExtractor,
  FoodResolver,
  LocalFoodDataProvider,
  OpenFoodFactsFoodDataProvider,
  OpenRouterFoodTextExtractor,
  UsdaFoodDataProvider,
} from "./nutrition/foodResolver.js";
import { ResolverNutritionProvider } from "./nutrition/provider.js";
import { PostgresRepository } from "./repository/postgres.js";
import { RemoteSpeechToTextProvider } from "./stt/speechToTextProvider.js";

const config = loadConfig();
const repository = new PostgresRepository(config.DATABASE_URL);
const authService = new AuthService(config, repository);
const foodResolver = new FoodResolver(
  new CompositeFoodTextExtractor([
    new OpenRouterFoodTextExtractor(
      config.OPENROUTER_API_KEY,
      config.OPENROUTER_MODEL,
    ),
    new DeterministicFoodTextExtractor(),
  ]),
  [
    new LocalFoodDataProvider(repository),
    new OpenFoodFactsFoodDataProvider(
      config.OPENFOODFACTS_BASE_URL,
      config.OPENFOODFACTS_USER_AGENT,
    ),
    ...(config.USDA_LIVE_FALLBACK_ENABLED
      ? [new UsdaFoodDataProvider(config.USDA_FDC_API_KEY)]
      : []),
  ],
  repository,
  config.FOOD_RESOLVER_MIN_CONFIDENCE,
);
const nutritionProvider = new ResolverNutritionProvider(foodResolver);
const embeddingProvider = config.EMBEDDING_BASE_URL
  ? new LocalBgeM3EmbeddingProvider(
      config.EMBEDDING_BASE_URL,
      config.EMBEDDING_MODEL,
      config.EMBEDDING_DIMENSIONS,
    )
  : undefined;
const memoryRetrievalService = new MemoryRetrievalService(
  repository,
  embeddingProvider,
);
const actionExecutor = new ActionExecutor(
  config,
  repository,
  nutritionProvider,
  memoryRetrievalService,
);
const sttProvider = new RemoteSpeechToTextProvider(
  config.STT_API_KEY,
  config.STT_MODEL,
  config.STT_BASE_URL,
);
const app = createApp({
  config,
  repository,
  authService,
  actionExecutor,
  sttProvider,
});

serve({ fetch: app.fetch, port: config.PORT });
console.log(`Backend listening on ${config.APP_BASE_URL}`);
