````markdown
## Project Summary

This project is a **Flutter mobile calorie tracking application** designed around an **agent-first architecture**.

The app is not just a traditional calorie tracker with an AI chatbot added on top. The main product idea is to build a calorie/nutrition tracking system where the user can interact naturally through voice/text, and an agent decides which app action/tool to execute.

The product must support:

1. **An internal app agent now**
   - The internal agent will live in our backend.
   - It will use an external LLM provider, initially something like OpenRouter with DeepSeek Flash/V4 or another low-latency model.
   - The agent will receive user requests, inspect available tools/actions, choose the right action, and execute it through the backend tool/action layer.

2. **Future mobile OS agents later**
   - Android: Gemini or other Android system agents via Android AppFunctions.
   - iOS: Siri / Apple Intelligence via iOS App Intents.
   - The app must be architected so future mobile agent integrations are thin adapters over the same internal action/tool system.

3. **Flutter as the mobile frontend**
   - Flutter/Dart is used for the UI and client-side app code.
   - Flutter should not own the core agent/nutrition logic.
   - Flutter should call backend APIs and handle user-facing interactions.

4. **Bun + TypeScript backend**
   - The backend owns the agent, action registry, tool execution, meal memory, nutrition logic, persistence, and safety policies.

5. **`flutter_intents` / `app_intents` package**
   - The Flutter intents package is used as a bridge to expose app actions/intents from Flutter/Dart to Android AppFunctions and iOS App Intents where possible.
   - It should be treated as an adapter, not as the core architecture.
   - The real source of truth must remain the backend action/tool layer.

---

## Core Product Vision

The long-term vision is:

```text
User
  ↓
Preferred agent
  ↓
Declared app actions/tools
  ↓
Calorie tracker action layer
  ↓
Nutrition memory + structured meal logs
````

For the MVP, because OS-level mobile agents are not fully open/reliable yet, we simulate that future flow with our own internal backend agent:

```text
User
  ↓
Flutter app voice/text input
  ↓
Backend internal agent
  ↓
Canonical action/tool registry
  ↓
Tool executor
  ↓
Database + nutrition memory
```

Future mobile-agent flow:

```text
User
  ↓
Gemini / Siri / Apple Intelligence
  ↓
Android AppFunctions / iOS App Intents
  ↓
Flutter intents bridge / native adapter
  ↓
Backend action/tool API
  ↓
Same tool executor
  ↓
Same database + nutrition memory
```

The critical principle:

> One canonical app action layer, many interfaces.

The same app capabilities must be usable by:

* Flutter UI
* backend internal agent
* Android AppFunctions
* iOS App Intents
* future mobile agents
* possibly REST integrations

MCP is not part of the current MVP. The app is not currently intended to expose tools to desktop or third-party external agents outside the mobile/internal-agent context.

---

## Main User Experience

The user should be able to interact naturally:

```text
“I had my usual breakfast.”
“Log 150 grams of chicken and rice.”
“Same lunch as yesterday.”
“I had two eggs, toast, and a protein shake.”
“After the gym I ate my normal chicken meal.”
“Actually, the chicken was 200 grams, not 150.”
“Delete the snack I just added.”
“How many calories do I have left today?”
```

The ideal flow:

```text
User speaks or types
  ↓
Agent understands intent
  ↓
Agent retrieves user-specific meal memory
  ↓
Agent creates structured meal proposal
  ↓
User confirms/corrects
  ↓
Meal is committed
  ↓
System learns from corrections
```

The app should minimize manual UI control. The UI exists mainly for:

* voice/text input,
* confirmation,
* correction,
* dashboard,
* meal history,
* permissions,
* user trust.

---

## Tech Stack

### Mobile Frontend

```text
Flutter
Dart
flutter_intents / app_intents package
```

Flutter responsibilities:

* mobile UI,
* voice/text input screen,
* meal proposal confirmation screen,
* correction UI,
* dashboard,
* meal history,
* usual meals/templates UI,
* settings,
* agent permissions UI,
* platform intent/action bridge.

Flutter must not contain the core nutrition reasoning or agent execution logic.

---

### Backend

```text
Bun
TypeScript
PostgreSQL
pgvector
Optional Redis
Docker
```

Backend responsibilities:

* internal agent orchestration,
* LLM provider integration,
* canonical action/tool registry,
* action execution,
* nutrition lookup,
* meal proposal creation,
* meal commit/correction/delete workflow,
* user-specific meal memory,
* vector retrieval,
* audit logging,
* confirmation policy,
* API endpoints,
* future mobile-agent adapter support.

---

### LLM Provider

Initial provider:

```text
OpenRouter
DeepSeek Flash / DeepSeek V4 / similar fast model
```

The backend must not be hardcoded to one provider.

Use a provider abstraction:

```ts
interface LLMProvider {
  runToolCalling(input: ToolCallingInput): Promise<ToolCallingResult>;
}
```

Possible implementations:

```text
OpenRouterProvider
GeminiProvider
OpenAIProvider
AnthropicProvider
LocalProvider
```

---

### Speech-to-Text

Initial options:

```text
Whisper-compatible API
OpenAI Whisper
Groq Whisper
Deepgram
Native mobile speech APIs later if useful
```

Speech-to-text should be abstracted behind an interface:

```ts
interface STTProvider {
  transcribe(audio: AudioInput): Promise<TranscriptionResult>;
}
```

The MVP can also support text input to validate the agent/tool flow before perfecting voice.

---

## Repository Structure

Recommended monorepo:

```text
nutrition-agent/
  README.md
  AGENTS.md
  .gitignore
  .env.example
  docker-compose.yml

  docs/
    product/
      prd.md
      mvp-scope.md
      positioning.md

    architecture/
      overview.md
      action-layer.md
      data-model.md
      safety-model.md
      mobile-agent-integrations.md
      flutter-intents.md

    api/
      rest-api.md
      action-schemas.md

    agents/
      internal-agent.md
      prompt-contracts.md
      evaluation.md

  apps/
    mobile/
      # Flutter app

    backend/
      # Bun + TypeScript backend

  packages/
    shared/
      # Canonical shared schemas, action definitions, DTOs, permissions

    prompts/
      # Versioned prompts/system instructions

  infra/
    nginx/
    docker/
    scripts/
    db/

  .github/
    workflows/
```

Do not add an MCP server unless the product direction changes to support external desktop/third-party agents.

---

## Architecture Overview

```text
                         ┌──────────────────────────┐
                         │ Future Mobile OS Agents  │
                         │ Gemini / Siri            │
                         └────────────┬─────────────┘
                                      │
                 ┌────────────────────┴────────────────────┐
                 │                                         │
      ┌──────────▼──────────┐                  ┌───────────▼───────────┐
      │ Android AppFunctions│                  │ iOS App Intents        │
      │ via Flutter bridge  │                  │ via Flutter bridge     │
      └──────────┬──────────┘                  └───────────┬───────────┘
                 │                                         │
                 └────────────────────┬────────────────────┘
                                      │
                         ┌────────────▼────────────┐
                         │ Backend Action API       │
                         │ Canonical app actions    │
                         └────────────┬────────────┘
                                      │
                         ┌────────────▼────────────┐
                         │ Tool/Action Executor     │
                         │ deterministic code       │
                         └────────────┬────────────┘
                                      │
           ┌──────────────────────────┼──────────────────────────┐
           │                          │                          │
┌──────────▼──────────┐    ┌──────────▼──────────┐    ┌──────────▼──────────┐
│ PostgreSQL           │    │ pgvector memory      │    │ Nutrition sources   │
│ source of truth      │    │ semantic recall      │    │ food facts          │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘


Current MVP path:

┌──────────────────────┐
│ Flutter App           │
│ voice/text UI         │
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Backend Internal Agent│
│ OpenRouter/LLM        │
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Same Action Registry  │
└──────────────────────┘
```

---

## Core Architectural Principle

The app must be built around a **Canonical App Action Layer**.

This layer should be structurally similar to Android AppFunctions and iOS App Intents:

Each action must have:

* stable ID,
* title,
* description,
* typed parameters,
* typed result,
* permission scope,
* confirmation policy,
* side-effect classification,
* deterministic backend handler.

Example:

```ts
type AppActionDefinition = {
  id: string;
  version: string;
  title: string;
  description: string;
  parametersSchema: unknown;
  resultSchema: unknown;
  permissionScope: string;
  confirmationPolicy:
    | "never"
    | "before_commit"
    | "always"
    | "trusted_mode_only";
  sideEffect: "read" | "propose" | "write" | "delete";
  executionMode: "foreground" | "background" | "either";
};
```

This internal structure is intentionally designed to map later to:

```text
Android AppFunctions
iOS App Intents
Internal LLM tools
Flutter UI actions
REST endpoints
```

---

## `flutter_intents` / `app_intents` Usage

The Flutter intents package should be used to help expose app actions/intents from the Flutter project to mobile OS systems.

The package’s role:

```text
Mobile OS action/intents layer
  ↓
flutter_intents bridge
  ↓
Dart handler
  ↓
Backend action API
```

The package should not contain core business logic.

Correct usage:

```text
Gemini/Siri invokes log_meal
  ↓
flutter_intents receives/bridges the action
  ↓
Dart handler receives params
  ↓
Dart calls backend action API
  ↓
Backend creates meal proposal
```

Incorrect usage:

```text
Gemini/Siri invokes log_meal
  ↓
flutter_intents
  ↓
Dart handler calculates nutrition, updates DB, manages memory
```

Core rule:

> Intent handlers should be thin. They should forward action requests to the backend.

---

## Android and iOS Platform Differences

Flutter projects have separate platform folders:

```text
apps/mobile/
  lib/       # shared Dart code
  android/   # Android-only native code
  ios/       # iOS-only native code
```

Android builds use:

```text
lib/
android/
```

iOS builds use:

```text
lib/
ios/
```

Android does not compile Swift files.

iOS does not compile Kotlin files.

This allows us to keep Android AppFunctions and iOS App Intents in the same Flutter project without conflict.

---

## Android AppFunctions Strategy

Android AppFunctions should expose selected app capabilities to Gemini/Android agents when available.

Future Android actions:

```text
log_meal
correct_meal
delete_meal
get_daily_summary
get_usual_meals
create_meal_template
```

Android flow:

```text
Gemini / Android agent
  ↓
Android AppFunction
  ↓
flutter_intents bridge or native adapter
  ↓
Dart handler
  ↓
Backend action API
  ↓
Backend tool executor
```

The Android adapter must not duplicate business logic.

---

## iOS App Intents Strategy

iOS App Intents should expose selected app capabilities to Siri, Shortcuts, Spotlight, and Apple Intelligence where supported.

Future iOS intents:

```text
LogMealIntent
CorrectLastMealIntent
DeleteLastMealIntent
ShowDailySummaryIntent
CreateUsualMealIntent
```

iOS flow:

```text
Siri / Apple Intelligence
  ↓
iOS AppIntent
  ↓
flutter_intents bridge or Swift adapter
  ↓
Dart handler
  ↓
Backend action API
  ↓
Backend tool executor
```

Important note:

iOS App Intents may still require static Swift declarations so that Siri/Shortcuts can discover the actions. The Flutter intents package can reduce native work and bridge to Dart, but it may not eliminate all Swift declarations.

Therefore:

* keep iOS-specific intent declarations inside `ios/`,
* keep business logic out of Swift,
* forward everything to Dart/backend.

---

## Backend Action Layer

The backend action layer is the core of the application.

It must define and execute canonical actions.

Initial actions:

```text
query_food_memory
search_nutrition_database
propose_meal_log
commit_meal
correct_meal
delete_meal
get_daily_summary
get_remaining_targets
get_meal_history
get_usual_meals
create_meal_template
update_meal_template
delete_meal_template
```

The internal agent and future OS agents must operate through these actions.

The LLM must never directly mutate the database.

---

## Backend Folder Structure

Recommended backend structure:

```text
apps/backend/
  src/
    index.ts
    server.ts

    config/
      env.ts

    db/
      client.ts
      schema/
        users.ts
        meals.ts
        meal_items.ts
        meal_proposals.ts
        meal_proposal_items.ts
        food_items.ts
        meal_templates.ts
        meal_template_items.ts
        food_memories.ts
        corrections.ts
        nutrition_targets.ts
        action_calls.ts
        confirmation_requests.ts
        audit_events.ts
      migrations/

    modules/
      auth/
      users/
      meals/
      nutrition/
      memory/
      actions/
      agent/
      confirmations/
      audit/
      summaries/

    integrations/
      llm/
        provider.ts
        openrouter.provider.ts
        deepseek.provider.ts
        gemini.provider.ts
        openai.provider.ts

      stt/
        provider.ts
        whisper.provider.ts

      nutrition_sources/
        usda.provider.ts
        openfoodfacts.provider.ts
        custom.provider.ts

    routes/
      health.routes.ts
      agent.routes.ts
      actions.routes.ts
      meals.routes.ts
      summaries.routes.ts
      memory.routes.ts
```

---

## Shared Package

`packages/shared` is mandatory.

It should contain:

```text
packages/shared/
  src/
    domain/
      user.ts
      food.ts
      meal.ts
      nutrition.ts
      memory.ts
      audit.ts

    actions/
      names.ts
      schemas.ts
      registry.ts
      permissions.ts
      descriptions.ts
      confirmation-policy.ts

    api/
      dto.ts
      errors.ts

    validation/
      common.ts

    index.ts
```

Use shared schemas for:

* backend validation,
* Flutter DTOs,
* internal LLM tool definitions,
* Android/iOS action mapping,
* tests,
* documentation.

Prefer a schema validation library such as Zod if the backend and shared package are TypeScript-based.

---

## Example Action Definition

```ts
export const ProposeMealLogAction = {
  id: "propose_meal_log",
  version: "1.0.0",
  title: "Propose Meal Log",
  description: "Create a pending meal log proposal from natural language food input.",
  permissionScope: "nutrition.write.propose",
  confirmationPolicy: "before_commit",
  sideEffect: "propose",
  executionMode: "either",
  parametersSchema: ProposeMealLogInputSchema,
  resultSchema: MealProposalSchema,
} as const;
```

The same action should later map to:

```text
Internal agent tool
REST endpoint
Android AppFunction
iOS AppIntent
Flutter UI action
```

---

## Canonical Actions

### `query_food_memory`

Purpose:

Retrieve user-specific meal memories related to a concept.

Example user phrases:

```text
“usual breakfast”
“post-gym meal”
“same as yesterday”
“my chicken meal”
```

Input:

```ts
{
  userId: string;
  concept: string;
  limit?: number;
}
```

Output:

```ts
{
  memories: Array<{
    id: string;
    label: string;
    description: string;
    confidence: number;
    linkedTemplateId?: string;
    lastUsedAt?: string;
  }>;
}
```

---

### `search_nutrition_database`

Purpose:

Search food/nutrition sources.

Input:

```ts
{
  query: string;
  locale?: string;
  brand?: string;
  barcode?: string;
}
```

Output:

```ts
{
  results: Array<{
    foodId: string;
    name: string;
    source: "usda" | "openfoodfacts" | "custom" | "manual";
    caloriesPer100g?: number;
    proteinPer100g?: number;
    carbsPer100g?: number;
    fatPer100g?: number;
  }>;
}
```

The LLM must not invent nutrition data when authoritative or user-specific data is available.

---

### `propose_meal_log`

Purpose:

Create a pending meal proposal from natural language.

Input:

```ts
{
  userId: string;
  text: string;
  occurredAt?: string;
  mealType?: "breakfast" | "lunch" | "dinner" | "snack" | "post_workout" | "unknown";
  timezone?: string;
  source: "flutter" | "internal_agent" | "android_appfunctions" | "ios_appintents" | "rest";
}
```

Output:

```ts
{
  proposalId: string;
  items: Array<{
    foodName: string;
    quantity: number;
    unit: string;
    state?: "raw" | "cooked" | "unknown";
    calories: number;
    proteinG: number;
    carbsG: number;
    fatG: number;
    confidence: number;
    source: string;
  }>;
  totalCalories: number;
  totalProteinG: number;
  totalCarbsG: number;
  totalFatG: number;
  confidence: number;
  requiresConfirmation: boolean;
  reason?: string;
}
```

This action should create a proposal, not directly commit a meal, unless trusted auto-commit is explicitly enabled.

---

### `commit_meal`

Purpose:

Commit a pending meal proposal after confirmation.

Input:

```ts
{
  userId: string;
  proposalId: string;
  confirmationSource: "user_tap" | "user_voice" | "trusted_auto_commit" | "external_agent_confirmed";
}
```

Output:

```ts
{
  mealId: string;
  committedAt: string;
  summary: {
    calories: number;
    proteinG: number;
    carbsG: number;
    fatG: number;
  };
}
```

---

### `correct_meal`

Purpose:

Apply a user correction to a proposal or committed meal.

Input:

```ts
{
  userId: string;
  mealId?: string;
  proposalId?: string;
  correction: string;
}
```

Output:

```ts
{
  updatedMealId?: string;
  updatedProposalId?: string;
  changes: Array<{
    field: string;
    before: unknown;
    after: unknown;
  }>;
  shouldUpdateMemory: boolean;
}
```

Corrections should update memory/templates when appropriate.

Example:

```text
User: “No, my protein shake uses 300ml milk, not 250ml.”

System:
- correct current meal/proposal
- update protein shake template/default if recurring
```

---

### `delete_meal`

Purpose:

Delete or mark a meal as removed.

Input:

```ts
{
  userId: string;
  mealId?: string;
  selector?: "last" | "today_breakfast" | "today_lunch" | "today_dinner" | "today_snack";
}
```

Output:

```ts
{
  deletedMealId?: string;
  requiresConfirmation: boolean;
  reason?: string;
}
```

Destructive actions usually require confirmation.

---

### `get_daily_summary`

Purpose:

Return calories/macros for one day.

Input:

```ts
{
  userId: string;
  date: string;
}
```

Output:

```ts
{
  date: string;
  caloriesConsumed: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  targetCalories?: number;
  targetProteinG?: number;
  remainingCalories?: number;
  meals: Array<{
    mealId: string;
    mealType: string;
    calories: number;
  }>;
}
```

---

### `get_usual_meals`

Purpose:

Return learned/user-created meal templates.

Input:

```ts
{
  userId: string;
}
```

Output:

```ts
{
  templates: Array<{
    id: string;
    name: string;
    aliases: string[];
    items: Array<{
      foodName: string;
      quantity: number;
      unit: string;
    }>;
    usageCount: number;
    lastUsedAt?: string;
  }>;
}
```

---

## Internal Agent Requirements

The internal agent is used in the MVP.

It must:

1. receive the user’s natural language input,
2. load available actions/tools,
3. load relevant user context,
4. call the LLM provider,
5. validate selected tool/action arguments,
6. execute deterministic backend actions,
7. return a structured response to Flutter.

The internal agent should support tool calling.

Expected flow:

```text
User: “Log my usual breakfast.”

Backend agent:
1. reads action registry
2. calls query_food_memory("usual breakfast")
3. calls propose_meal_log(...)
4. returns meal proposal
```

The internal agent must not directly update the database outside the action executor.

---

## LLM Safety Rules

The LLM must not:

* directly write to the database,
* invent nutrition values without lookup,
* bypass confirmation policy,
* delete meals without confirmation,
* modify nutrition targets without confirmation,
* expose one user’s data to another user,
* silently commit ambiguous meals.

The LLM may:

* interpret natural language,
* select tools/actions,
* ask clarification questions,
* summarize results,
* propose structured meal logs,
* explain uncertainty.

---

## Confirmation Policy

The app must be proposal-first.

Default write flow:

```text
Natural language input
  ↓
Meal proposal
  ↓
User confirmation/correction
  ↓
Committed meal
```

Confidence levels:

```text
Level 0 — Read-only
No confirmation needed.
Example: get_daily_summary.

Level 1 — Safe proposal
Agent can create a pending proposal.
No permanent write.

Level 2 — Trusted write
Agent may commit common/high-confidence meals only if user explicitly enabled trusted mode.
Example: “usual breakfast.”

Level 3 — Sensitive/destructive
Always confirm.
Examples:
- delete meal
- modify targets
- export history
```

Examples that require confirmation:

```text
“I ate chicken and rice.”
“I had a slice of cake.”
“Delete the last meal.”
“Change my calorie target.”
```

Examples that may be eligible for trusted auto-commit:

```text
“Log my usual breakfast.”
“Same protein shake as always.”
```

---

## Data Model Requirements

Minimum tables:

```text
users
nutrition_targets
food_items
meals
meal_items
meal_proposals
meal_proposal_items
meal_templates
meal_template_items
food_memories
corrections
action_calls
confirmation_requests
audit_events
agent_connections
```

### Meals

Committed source-of-truth meal records.

Must include:

* user ID,
* meal type,
* timestamp,
* source,
* total calories/macros,
* confirmation metadata.

### Meal Proposals

Pending meal logs before final commit.

Statuses:

```text
pending
confirmed
corrected
rejected
expired
committed
```

### Food Memories

Semantic/personal memory records.

Must include:

* user ID,
* label/text,
* embedding,
* linked template/meal if relevant,
* confidence,
* usage count,
* last used timestamp.

### Action Calls

Every tool/action call must be logged.

Must include:

* user ID,
* action name,
* source interface,
* input JSON,
* output JSON or error,
* model/provider if agent-initiated,
* timestamp,
* latency,
* confirmation status.

### Audit Events

Every important mutation must create an audit event.

Examples:

```text
meal_proposal_created
meal_committed
meal_corrected
meal_deleted
template_created
memory_updated
agent_connection_created
agent_connection_revoked
```

---

## Memory System

Use hybrid memory:

```text
PostgreSQL = source of truth
pgvector = semantic retrieval
Rules/templates = learned user defaults
Nutrition DB/API = factual nutrition source
LLM = interpretation layer
```

Do not use vector memory as the source of truth.

Vector memory is for fuzzy retrieval of:

* usual meal phrases,
* meal aliases,
* repeated meal patterns,
* vague references,
* contextual habits.

Examples:

```text
“usual breakfast”
“post-gym meal”
“cafeteria sandwich”
“chicken and rice after training”
```

---

## Nutrition Data

Initial sources:

```text
USDA FoodData Central
OpenFoodFacts
custom user foods
manual entries
```

For Spain/Europe, OpenFoodFacts and custom foods are important.

The system must support:

* generic foods,
* branded foods,
* user custom foods,
* raw/cooked state,
* unit conversion,
* correction-based personalization.

Do not over-optimize the nutrition database before validating the logging loop.

The core advantage is:

```text
personal meal memory + correction learning + low-friction agent logging
```

---

## Flutter App Requirements

Recommended Flutter structure:

```text
apps/mobile/
  lib/
    main.dart

    app/
      app.dart
      router.dart
      theme.dart

    core/
      config/
      networking/
        api_client.dart
      auth/
      errors/
      utils/

    features/
      onboarding/
      auth/
      voice_log/
      meal_confirmation/
      dashboard/
      meal_history/
      meal_templates/
      agent_permissions/
      settings/

    platform/
      intents/
        app_intents_adapter.dart
        action_bridge.dart

    models/
      meal.dart
      meal_proposal.dart
      daily_summary.dart
```

### `voice_log`

Responsibilities:

* record voice,
* submit audio or text to backend,
* show loading/progress,
* display resulting proposal.

No meal parsing should happen locally.

### `meal_confirmation`

Responsibilities:

* display proposal,
* confirm,
* correct,
* reject,
* call backend commit/correct endpoints.

### `dashboard`

Responsibilities:

* show today’s calories/macros,
* remaining targets,
* daily meals.

### `meal_history`

Responsibilities:

* show committed meals,
* allow correction/deletion through backend.

### `meal_templates`

Responsibilities:

* show usual meals,
* allow manual template creation/editing.

### `agent_permissions`

Responsibilities:

* show connected agents/adapters,
* show trusted mode settings,
* show scopes/permissions,
* revoke access.

---

## API Requirements

Minimum backend routes:

```text
GET  /health

GET  /actions
POST /actions/execute

POST /agent/run

POST /meals/proposals
POST /meals/proposals/:id/commit
POST /meals/proposals/:id/correct
POST /meals/:id/correct
DELETE /meals/:id

GET  /summary/daily
GET  /meals
GET  /meal-templates
POST /meal-templates

GET  /agent-connections
POST /agent-connections
DELETE /agent-connections/:id
```

`/agent/run` is used by the internal backend agent.

`/actions/execute` is used by future adapters such as AppFunctions/App Intents.

Both must use the same action executor.

---

## Permissions

Design for future scoped action access.

Possible scopes:

```text
nutrition.read.summary
nutrition.read.history
nutrition.read.memory
nutrition.write.propose
nutrition.write.commit
nutrition.write.correct
nutrition.write.delete
nutrition.targets.modify
nutrition.export
```

Default policy:

```text
Read summary: allowed with scope
Query memory: allowed with scope
Propose meal: allowed with scope
Commit meal: confirmation required unless trusted mode
Delete meal: confirmation required
Modify targets: confirmation required
Export history: explicit permission required
```

---

## Privacy Requirements

The app handles health-adjacent data.

Must support:

* delete account,
* delete all user data,
* export data,
* revoke agent connections,
* delete embeddings/memory,
* audit agent actions,
* clear privacy policy,
* no medical claims.

If user data is deleted, related embeddings must also be deleted.

---

## Observability Requirements

Track:

```text
voice_to_proposal_latency
proposal_to_confirmation_latency
confirmed_without_edit_rate
correction_rate
usual_meal_hit_rate
food_resolution_confidence
action_success_rate
action_error_rate
llm_provider_latency
llm_cost_per_log
stt_latency
commit_rate
retention_metrics
```

The product succeeds or fails based on:

```text
speed
trust
accuracy
low friction
repeat usage
memory usefulness
```

---

## Testing Requirements

Backend tests must cover:

* action schema validation,
* propose meal flow,
* commit flow,
* correction flow,
* delete flow,
* confidence policy,
* permission checks,
* memory retrieval,
* nutrition calculation,
* audit logging.

Flutter tests must cover:

* voice/text input UI,
* proposal display,
* confirmation flow,
* correction flow,
* loading states,
* API error states.

Agent tests must include golden scenarios:

```text
“I had my usual breakfast.”
“Same lunch as yesterday.”
“Chicken and rice.”
“Delete the snack I just added.”
“No, the chicken was 200 grams.”
“How many calories do I have left?”
```

Each test should verify:

* correct action selected,
* correct proposal structure,
* confirmation required when appropriate,
* memory used when appropriate,
* no direct database mutation by LLM.

---

## Development Rules for AI Coding Agents

When working on this repo:

### Preserve boundaries

Do not move backend agent logic into Flutter.

Do not duplicate action logic in Android/iOS adapters.

Do not put nutrition reasoning inside Flutter intents handlers.

### Use shared schemas

When creating a new action:

1. Define schema in `packages/shared`.
2. Implement backend handler.
3. Expose through backend route.
4. Add tests.
5. Update docs.
6. Later map to AppFunctions/App Intents if needed.

### Build incrementally

Recommended order:

```text
1. Create monorepo structure.
2. Create shared domain/action schemas.
3. Create backend health route.
4. Create database schema.
5. Implement propose_meal_log.
6. Implement commit_meal.
7. Implement correct_meal.
8. Implement get_daily_summary.
9. Implement internal agent endpoint.
10. Build Flutter voice/text input screen.
11. Build meal proposal confirmation screen.
12. Add basic memory/templates.
13. Add flutter_intents adapter prototype.
14. Add Android AppFunctions mapping.
15. Add iOS App Intents mapping.
```

### Keep providers replaceable

Do not hardcode OpenRouter or DeepSeek everywhere.

Use provider interfaces.

### Keep deterministic logic testable

The action executor must be testable without LLM calls.

### Do not overbuild early

Avoid initially:

* complex multi-agent frameworks,
* MCP server,
* microservices,
* full nutritionist dashboard,
* advanced photo recognition,
* wearable integrations,
* complex medical claims,
* full enterprise auth.

---

## MVP Definition

The MVP must prove:

> Users can log recurring meals faster and more reliably through an agentic flow than through a traditional calorie tracking UI.

MVP must include:

```text
Flutter mobile app
Bun + TypeScript backend
internal backend agent
external LLM provider through abstraction
voice or text input
canonical action registry
meal proposal generation
user confirmation/correction
meal commit
daily summary
basic meal memory/templates
audit logging
shared action schemas
flutter_intents adapter prototype
```

MVP should not require:

```text
production Android AppFunctions access through Gemini
production iOS App Intents through Siri
MCP server
photo recognition
barcode scanning
wearable integrations
nutritionist dashboard
```

---

## Non-Negotiable Principle

The app must not be designed as:

```text
A calorie app with an AI chatbot
```

It must be designed as:

```text
A calorie/nutrition capability layer that agents can operate safely
```

The current internal backend agent is the first agent.

Future mobile OS agents should be able to call the same capabilities through AppFunctions/App Intents with minimal architectural changes.

Every major decision should support this future:

```text
User request
  ↓
Agent chooses declared action/tool
  ↓
Backend validates and executes
  ↓
Meal proposal/confirmation workflow
  ↓
Personal nutrition memory improves
```

```
```
