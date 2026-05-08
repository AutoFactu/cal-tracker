# Database and Vector Memory Architecture

## Architectural Review Corrections Applied

This document keeps PostgreSQL + pgvector as the database direction, but corrects several design flaws:

* Removed embedded prompt instructions and malformed Markdown fences.
* Made PostgreSQL the only source of truth and pgvector an auxiliary retrieval mechanism.
* Split semantic memory records from embedding vectors so model changes and re-embedding are manageable.
* Added explicit user scoping, ownership checks, deletion behavior, and backend-only access rules.
* Added core relational tables missing from the original database document, including proposals, committed meals, nutrition targets, action calls, confirmations, audit events, and jobs.
* Added constraints, indexes, and retrieval order for exact aliases, temporal references, vector search, reranking, and clarification.
* Added migration, local Docker, production, backup, and security guidance.

## Core Principles

The application uses a hybrid data architecture:

```text
PostgreSQL = source of truth
pgvector = semantic memory retrieval
LLM = interpretation and tool selection
Backend action executor = deterministic execution
Flutter = UI and thin platform adapters only
```

The vector layer must never be treated as the source of truth.

Structured nutrition data, meal templates, committed meals, quantities, calories, macros, corrections, confirmations, and audit events must live in relational PostgreSQL tables.

Vector records are used only to retrieve user-specific semantic memories such as:

```text
"usual breakfast"
"same breakfast as always"
"normal breakfast"
"post-gym meal"
"my chicken meal"
```

These semantic memories must point back to structured records in PostgreSQL.

## Vector Database Choice

Use:

```text
PostgreSQL + pgvector, running locally through Docker Compose
```

Do not introduce Pinecone, Weaviate, Qdrant, Milvus, or another separate vector database for the MVP.

Reasons:

* one database to deploy and maintain,
* easier joins with users, templates, meals, and audit logs,
* simpler local development,
* enough for user-scoped semantic retrieval,
* transactional consistency with source-of-truth records,
* easier user deletion and export.

Revisit a separate vector database only if measured production data shows pgvector cannot satisfy retrieval latency or recall requirements.

## Local Development and Docker Setup

Local development must use the same database technology planned for production:

```text
PostgreSQL + pgvector
```

Do not use SQLite for the MVP except for throwaway UI prototypes that do not exercise persistence or memory retrieval.

Correct local architecture:

```text
Flutter app
  -> Bun + TypeScript backend
  -> PostgreSQL + pgvector in Docker
```

Flutter must never connect directly to PostgreSQL.

## Docker Compose Database Service

Use a pgvector PostgreSQL image in `docker-compose.yml`.

Example:

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg16
    container_name: cal_tracker_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: cal_tracker
      POSTGRES_USER: cal_tracker_user
      POSTGRES_PASSWORD: cal_tracker_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infra/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U cal_tracker_user -d cal_tracker"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
```

Example local `.env`:

```env
DATABASE_URL=postgres://cal_tracker_user:cal_tracker_password@localhost:5432/cal_tracker
```

When the backend runs inside Docker Compose, use the service name:

```env
DATABASE_URL=postgres://cal_tracker_user:cal_tracker_password@postgres:5432/cal_tracker
```

## pgvector Extension Initialization

Create:

```text
infra/db/init.sql
```

With:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

The migration system must also ensure the extension exists:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

The backend should fail fast during startup if the extension is unavailable:

```sql
SELECT extversion FROM pg_extension WHERE extname = 'vector';
```

## Local Development Commands

Recommended flow:

```bash
docker compose up -d postgres
cd apps/backend
bun install
bun run db:migrate
bun run dev
```

Run Flutter separately:

```bash
cd apps/mobile
flutter pub get
flutter run
```

If seed data exists:

```bash
cd apps/backend
bun run db:seed
```

## Persistence and Resets

The PostgreSQL container must use a named Docker volume:

```text
postgres_data
```

To reset the local database completely:

```bash
docker compose down -v
docker compose up -d postgres
```

Use this only when a full local reset is intended.

## Production Deployment

Decision: production starts with self-hosted PostgreSQL + pgvector running as a Docker container on the VPS.

Production shape:

```text
VPS
  backend container
  postgres + pgvector container
  optional redis/job container
  nginx reverse proxy
  encrypted backups
```

This decision avoids a managed database dependency, but it makes database operations a first-class engineering responsibility. The production deployment is not acceptable until backups, restore testing, disk monitoring, private networking, and upgrade procedures are configured.

Minimum production requirements:

```text
PostgreSQL runs in Docker with a persistent named volume or mounted data disk.
pgvector extension is enabled through migration/init SQL.
Database is reachable only by the backend over the internal Docker network or localhost.
No public PostgreSQL port is exposed.
Automated encrypted backups run on a schedule.
Restore procedure is documented and tested before launch.
Disk usage and container health are monitored.
PostgreSQL logs are retained enough to debug incidents.
Upgrade procedure is documented before the first production release.
```

PostgreSQL must not be exposed publicly.

Do not use this in production:

```yaml
ports:
  - "5432:5432"
```

Prefer internal Docker networking:

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg16
    expose:
      - "5432"
```

Only the backend should access the database.

## Infrastructure Boundary

Database infrastructure belongs under:

```text
infra/db/
docker-compose.yml
```

Database schema and migrations belong under the backend:

```text
apps/backend/src/db/schema/
apps/backend/src/db/migrations/
```

Backend memory logic belongs under:

```text
apps/backend/src/modules/memory/
```

Do not put vector search logic inside Flutter.

Do not put vector search logic inside Docker scripts.

Docker provides infrastructure. The backend owns retrieval, ranking, and memory update logic.

## Migration and ORM Guidance

Use SQL migrations as the source of truth for database changes. A TypeScript ORM or query builder can be used, but pgvector operations and indexes must be represented accurately in migrations.

Recommended options:

* Drizzle ORM with SQL migrations.
* Kysely with SQL migrations.
* Raw SQL for vector indexes and specialized retrieval queries.

Avoid hiding vector behavior behind abstractions that make indexes, distance operators, or query plans unclear.

## Core Tables

Minimum required tables:

```text
users
user_credentials
auth_sessions
password_reset_tokens
nutrition_targets
food_items
meals
meal_items
meal_proposals
meal_proposal_items
meal_templates
meal_template_items
food_memories
embedding_models
food_memory_embeddings
corrections
confirmation_requests
action_calls
audit_events
agent_connections
outbox_jobs
```

## Table Responsibilities

### `users`

Stores application users and profile-level preferences.

Required fields:

```text
id
email
display_name
timezone
locale
unit_system
trusted_mode_enabled
created_at
updated_at
deleted_at
```

The application uses custom backend-owned authentication sessions. The backend must derive `user_id` from the validated session, not from request bodies.

`trusted_mode_enabled` defaults to `false`. It only allows auto-commit for safe familiar meal templates that satisfy the trusted auto-commit policy in `docs/app-description.md`.

### `user_credentials`

Stores password credentials for custom backend authentication.

Required fields:

```text
id
user_id
password_hash
password_hash_algorithm
password_hash_params
password_updated_at
created_at
updated_at
```

Rules:

* Store password hashes only. Never store plaintext passwords.
* Use Argon2id or bcrypt with appropriate work factors.
* Keep algorithm metadata so work factors can be migrated later.

### `auth_sessions`

Stores revocable backend-owned user sessions.

Required fields:

```text
id
user_id
session_token_hash
refresh_token_hash
device_label
ip_address_hash
user_agent
expires_at
refresh_expires_at
revoked_at
last_used_at
created_at
updated_at
```

Rules:

* Store token hashes only.
* Sessions must expire and be revocable.
* Refresh rotation must invalidate the previous refresh token.
* Logout must revoke the current session.
* The user must be able to revoke all sessions.

### `password_reset_tokens`

Stores short-lived one-time password reset tokens.

Required fields:

```text
id
user_id
token_hash
expires_at
used_at
created_at
```

Rules:

* Store token hashes only.
* Tokens must be single-use and short-lived.
* Reset request and completion events must be audited.

### `nutrition_targets`

Stores daily targets.

Required fields:

```text
id
user_id
calories
protein_g
carbs_g
fat_g
effective_from
effective_to
created_at
updated_at
```

Use effective date ranges so historical summaries can explain which target was active.

### `food_items`

Stores normalized food data from external providers and custom user foods.

Required fields:

```text
id
owner_user_id
source
source_food_id
barcode
name
brand
locale
serving_size
serving_unit
calories_per_100g
protein_g_per_100g
carbs_g_per_100g
fat_g_per_100g
fiber_g_per_100g
sugar_g_per_100g
sodium_mg_per_100g
data_quality
created_at
updated_at
```

`owner_user_id` is nullable for global/provider foods and set for user custom foods.

### `meal_proposals`

Stores pending meal logs before commitment.

Required fields:

```text
id
user_id
source
input_text
occurred_at
meal_type
status
confidence
requires_confirmation
matched_memory_id
expires_at
created_by_action_call_id
created_at
updated_at
```

Allowed statuses:

```text
pending
corrected
rejected
expired
committed
```

### `meal_proposal_items`

Stores structured items inside a pending proposal.

Required fields:

```text
id
proposal_id
food_item_id
display_name
quantity
unit
gram_weight
state
calories
protein_g
carbs_g
fat_g
confidence
source
position
created_at
updated_at
```

Proposal items are snapshots. They should not change if provider food data changes later.

### `meals`

Stores committed source-of-truth meal records.

Required fields:

```text
id
user_id
proposal_id
meal_type
occurred_at
source
status
total_calories
total_protein_g
total_carbs_g
total_fat_g
confirmed_by
confirmed_at
created_by_action_call_id
created_at
updated_at
deleted_at
```

Use `deleted_at` for user-facing meal deletion. Account deletion should hard-delete or anonymize according to the privacy policy.

### `meal_items`

Stores committed nutrition snapshots.

Required fields:

```text
id
meal_id
food_item_id
display_name
quantity
unit
gram_weight
state
calories
protein_g
carbs_g
fat_g
source
position
created_at
updated_at
```

Committed meal item values must remain stable after commit.

### `meal_templates`

Stores reusable structured meals.

Required fields:

```text
id
user_id
name
meal_type
description
usage_count
confidence
trusted_auto_commit_enabled
last_used_at
created_from_meal_id
created_at
updated_at
archived_at
```

`trusted_auto_commit_enabled` defaults to `false`. A template is eligible for trusted auto-commit only when both `users.trusted_mode_enabled` and `meal_templates.trusted_auto_commit_enabled` are true and the backend trusted auto-commit policy passes.

### `meal_template_items`

Stores structured foods inside a reusable meal template.

Required fields:

```text
id
template_id
food_item_id
display_name
quantity
unit
gram_weight
state
calories
protein_g
carbs_g
fat_g
source
position
created_at
updated_at
```

Template item nutrition should be stored as a snapshot. It can be recalculated only through explicit template update logic.

### `food_memories`

Stores semantic memory phrases and their links to structured records.

Required fields:

```text
id
user_id
memory_type
text
normalized_text
linked_template_id
linked_meal_id
linked_food_item_id
meal_type
confidence
usage_count
last_used_at
created_by_action_call_id
created_at
updated_at
archived_at
```

Valid `memory_type` values:

```text
meal_alias
meal_pattern
food_alias
user_preference
```

Rules:

* Every memory belongs to exactly one user.
* Vector search must always filter by user.
* A memory should link to a structured template, meal, or food item.
* Exact alias matching should use `normalized_text`.

### `embedding_models`

Stores embedding model metadata.

Closed MVP decision:

```text
provider = openrouter
model = openai/text-embedding-3-small
dimensions = 1536
```

The application will request embeddings from OpenRouter using `openai/text-embedding-3-small`. The embedding model is not hosted by us. The backend owns provider calls, API keys, retries, and persistence of returned vectors; Flutter must never generate embeddings or call an embedding provider directly.

Required fields:

```text
id
provider
model
dimensions
distance_metric
is_active
created_at
retired_at
```

Embedding dimensions are not merely metadata. A pgvector column declared as `vector(1536)` cannot store vectors of another dimension. If the embedding model changes dimensions, add a new embedding table or column and backfill.

### `food_memory_embeddings`

Stores vectors for semantic memories.

Required fields:

```text
id
memory_id
embedding_model_id
embedding
embedded_text_hash
created_at
updated_at
```

Active MVP DDL using OpenRouter `openai/text-embedding-3-small`:

```sql
CREATE TABLE food_memory_embeddings (
  id uuid PRIMARY KEY,
  memory_id uuid NOT NULL REFERENCES food_memories(id) ON DELETE CASCADE,
  embedding_model_id uuid NOT NULL REFERENCES embedding_models(id),
  embedding vector(1536) NOT NULL,
  embedded_text_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (memory_id, embedding_model_id)
);
```

### `corrections`

Stores user corrections to proposals, meals, and templates.

Required fields:

```text
id
user_id
proposal_id
meal_id
template_id
correction_text
before_json
after_json
should_update_memory
created_by_action_call_id
created_at
```

### `confirmation_requests`

Stores pending confirmations for actions that require user approval.

Required fields:

```text
id
user_id
action_call_id
action_id
status
reason
expires_at
confirmed_at
rejected_at
created_at
updated_at
```

Allowed statuses:

```text
pending
confirmed
rejected
expired
cancelled
```

### `action_calls`

Every tool/action call must be logged.

Required fields:

```text
id
user_id
action_id
action_version
source
input_json
output_json
error_json
model_provider
model_name
prompt_version
confirmation_status
idempotency_key
trace_id
latency_ms
created_at
```

Sensitive values should be redacted or minimized. Do not store raw audio in `action_calls`.

### `audit_events`

Every important mutation must create an audit event.

Examples:

```text
meal_proposal_created
meal_committed
meal_corrected
meal_deleted
template_created
template_updated
template_deleted
memory_created
memory_updated
memory_archived
agent_connection_created
agent_connection_revoked
account_deleted
```

Required fields:

```text
id
user_id
event_type
entity_type
entity_id
action_call_id
metadata_json
trace_id
created_at
```

### `agent_connections`

Stores future external agent or OS adapter connections and granted scopes.

Required fields:

```text
id
user_id
provider
display_name
scopes
status
created_at
revoked_at
last_used_at
```

### `outbox_jobs`

Stores asynchronous jobs for embedding generation, re-embedding, cleanup, exports, and provider retries.

Required fields:

```text
id
job_type
payload_json
status
attempts
run_after
locked_at
locked_by
created_at
updated_at
```

Redis can be introduced later for queue throughput, but a database outbox is sufficient for MVP reliability.

## Required Constraints and Indexes

Every user-owned table must include an index on `user_id`.

Important constraints:

```sql
CREATE UNIQUE INDEX users_email_active_idx
  ON users (lower(email))
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX user_credentials_user_idx
  ON user_credentials (user_id);

CREATE INDEX auth_sessions_user_active_idx
  ON auth_sessions (user_id, expires_at DESC)
  WHERE revoked_at IS NULL;

CREATE INDEX password_reset_tokens_user_created_at_idx
  ON password_reset_tokens (user_id, created_at DESC)
  WHERE used_at IS NULL;

CREATE UNIQUE INDEX food_memories_user_normalized_text_idx
  ON food_memories (user_id, normalized_text)
  WHERE archived_at IS NULL;

CREATE INDEX food_memories_user_meal_type_idx
  ON food_memories (user_id, meal_type)
  WHERE archived_at IS NULL;

CREATE INDEX meals_user_occurred_at_idx
  ON meals (user_id, occurred_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX action_calls_user_created_at_idx
  ON action_calls (user_id, created_at DESC);
```

Vector index example for cosine distance:

```sql
CREATE INDEX food_memory_embeddings_hnsw_idx
  ON food_memory_embeddings
  USING hnsw (embedding vector_cosine_ops);
```

For the MVP, exact per-user vector scans may be acceptable because each user will have a small number of memories. Add HNSW only after benchmarking. Approximate indexes trade recall for speed, so retrieval tests must compare indexed and exact behavior.

## Retrieval Flow

Semantic retrieval must happen through the backend action:

```text
query_food_memory
```

The LLM must not query pgvector directly.

Preferred retrieval order:

```text
1. Normalize phrase and check exact memory/template aliases.
2. Resolve deterministic temporal references.
3. Run user-scoped vector search.
4. Rerank candidates with metadata.
5. Ask a clarification question if confidence is low.
```

Temporal phrases should not primarily use vector search:

```text
"same as yesterday"
"same lunch as yesterday"
"repeat Monday's dinner"
```

These should resolve through meal history:

```text
1. Resolve target date in the user's timezone.
2. Resolve meal type if provided.
3. Retrieve committed meal from that date.
4. Create a new proposal copying the meal item snapshots.
```

## User-Scoped Vector Query

Example exact user-scoped vector query:

```sql
SELECT
  fm.id,
  fm.text,
  fm.memory_type,
  fm.linked_template_id,
  fm.linked_meal_id,
  fm.linked_food_item_id,
  fm.meal_type,
  fm.confidence,
  fm.usage_count,
  fm.last_used_at,
  fme.embedding <=> $2::vector AS distance
FROM food_memories fm
JOIN food_memory_embeddings fme
  ON fme.memory_id = fm.id
WHERE fm.user_id = $1
  AND fm.archived_at IS NULL
  AND fme.embedding_model_id = $3
ORDER BY fme.embedding <=> $2::vector
LIMIT $4;
```

All parameters must be bound parameters. Never interpolate user text or vectors into SQL strings.

If a global HNSW index is used at larger scale, benchmark recall under user filters. If recall degrades, use over-fetching, partitioning, higher `hnsw.ef_search`, or a different retrieval design.

## Retrieval Ranking

Do not rely only on vector distance.

Rerank using:

```text
semantic similarity
exact alias match
meal_type match
time-of-day context
usage_count
recency
confidence
correction history
```

Example scoring shape:

```text
final_score =
  semantic_similarity * 0.45 +
  meal_type_match * 0.15 +
  exact_alias_match * 0.15 +
  recency_score * 0.10 +
  usage_score * 0.10 +
  confidence_score * 0.05
```

Treat these weights as starting values. Tune them with test scenarios and production telemetry.

## Memory Creation and Update Rules

Create or update food memories when:

```text
user confirms a meal template
user creates a usual meal
user explicitly names a meal
same meal pattern appears repeatedly
user corrects a recurring meal
```

Example:

```text
User: "Call this my normal breakfast."

System:
1. Create or update a meal_template.
2. Add food_memory text = "normal breakfast".
3. Link memory to the template.
4. Enqueue embedding generation.
5. Add audit event.
```

Correction example:

```text
User: "No, my protein shake uses 300ml milk, not 250ml."

System:
1. Correct current proposal or meal.
2. Ask whether the recurring template should be updated if ambiguity exists.
3. Update linked template if confirmed or policy allows.
4. Add correction and audit events.
5. Update memory confidence and usage metadata.
```

Embedding generation should be asynchronous where possible:

```text
food_memory created
  -> outbox job queued
  -> embedding provider called
  -> food_memory_embeddings upserted
```

Retrieval should ignore memories whose active embedding is missing unless exact alias lookup succeeds.

## Proposal Commit Transaction

`commit_meal` must be transactional.

Required sequence:

```text
1. Load proposal by id and user_id.
2. Lock proposal row.
3. Verify status is pending or corrected.
4. Verify confirmation policy.
5. Insert meal.
6. Insert meal_items from proposal item snapshots.
7. Mark proposal committed.
8. Update template/memory usage counters if applicable.
9. Insert audit_event.
10. Update action_call output.
11. Commit transaction.
```

Retries must be safe through an `idempotency_key` or unique `proposal_id` relationship.

## Delete and Privacy Behavior

Meal deletion in normal app use should soft-delete:

```text
meals.deleted_at = now()
```

Account deletion must remove or anonymize all user-owned data according to the privacy policy. At minimum, it must delete:

```text
food_memories
food_memory_embeddings
meal_templates
meal_template_items
meal_proposals
meal_proposal_items
meals
meal_items
nutrition_targets
custom food_items
agent_connections
```

Audit logs must not retain personally identifying meal text after account deletion unless the privacy policy explicitly allows retention and the data is anonymized.

## Backup and Restore

Production PostgreSQL must have:

* automated backups,
* restore testing,
* disk usage alerts,
* database logs,
* migration rollback strategy,
* encrypted secrets,
* no public database port.

A database without tested restores is not production-ready.

## Flutter Boundary

Flutter responsibilities:

```text
record voice/text
send input to backend
display proposal
allow confirmation/correction/rejection
show templates/history/summary
show permission and trusted-mode settings
```

Backend responsibilities:

```text
embedding generation
pgvector search
memory ranking
template loading
nutrition lookup
proposal creation
commit/correction/delete logic
audit logging
```

Flutter receives structured responses such as:

```json
{
  "proposalId": "prop_123",
  "matchedMemory": {
    "label": "Usual breakfast",
    "confidence": 0.93
  },
  "items": [
    {
      "foodName": "Eggs",
      "quantity": 2,
      "unit": "pieces",
      "calories": 140
    }
  ],
  "requiresConfirmation": true
}
```

Flutter does not own vector search. Backend owns vector search. PostgreSQL stores truth. pgvector stores semantic aliases and memories. Every vector is user-scoped. Semantic memories point to structured meal templates, past meals, or food items. Local development uses Dockerized PostgreSQL + pgvector. Flutter connects only to the backend.
