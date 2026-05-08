## Database and Vector Memory Architecture

The application uses a hybrid data architecture:

```text
PostgreSQL = source of truth
pgvector = semantic memory / fuzzy retrieval
LLM agent = interpretation and tool selection
Backend deterministic tools = execution
Flutter = UI only
````

The vector database must not be treated as the source of truth.

Structured nutrition data, meal templates, committed meals, quantities, calories, macros, and corrections must live in relational PostgreSQL tables.

The vector layer is only used to retrieve user-specific semantic memories such as:

```text
“usual breakfast”
“same breakfast as always”
“normal breakfast”
“post-gym meal”
“my chicken meal”
```

These semantic memories point back to structured records in PostgreSQL.

---

## Vector Database Choice

Use:

```text
PostgreSQL + pgvector
```

Do not introduce a separate vector database such as Pinecone, Weaviate, Qdrant, or Milvus for the MVP unless there is a strong scaling reason later.

Reasons:

* one database to deploy and maintain,
* easier joins with users/templates/meals,
* simpler local development,
* enough for user-scoped semantic retrieval,
* better transactional consistency,
* easier deletion/export of user data.

---


Add this section to the DB architecture file, ideally after **Vector Database Choice** or before **Core Tables for Meal Memory**:

````markdown
---

## Local Development and Docker Setup

For local development, use Docker Compose with PostgreSQL + pgvector.

The local development database should use the same database technology planned for production:

```text
PostgreSQL + pgvector
````

Do not use SQLite for the main MVP unless building a temporary throwaway prototype.

Reasons to use Dockerized PostgreSQL locally:

* keeps local development close to production,
* avoids future migration pain from SQLite to PostgreSQL,
* allows pgvector to be used from the beginning,
* supports realistic migrations and constraints,
* allows testing user-scoped semantic search properly,
* allows testing joins between meals, templates, memories, users, and audit logs,
* makes onboarding easier for developers and coding agents.

Flutter must never connect directly to PostgreSQL.

Correct local architecture:

```text
Flutter app
  ↓
Bun + TypeScript backend
  ↓
PostgreSQL + pgvector running in Docker
```

---

## Docker Compose Database Service

Use a `pgvector` PostgreSQL image in `docker-compose.yml`.

Example:

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg16
    container_name: nutrition_agent_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: nutrition_agent
      POSTGRES_USER: nutrition_user
      POSTGRES_PASSWORD: nutrition_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infra/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro

volumes:
  postgres_data:
```

The backend should connect to this database through `DATABASE_URL`.

Example `.env`:

```env
DATABASE_URL=postgres://nutrition_user:nutrition_password@localhost:5432/nutrition_agent
```

When the backend runs inside Docker Compose, the hostname should be the service name:

```env
DATABASE_URL=postgres://nutrition_user:nutrition_password@postgres:5432/nutrition_agent
```

---

## pgvector Extension Initialization

The PostgreSQL database must enable the `vector` extension.

Create:

```text
infra/db/init.sql
```

With:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

If using migrations, the migration system should also ensure the extension exists:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

The application must fail fast during startup if the `vector` extension is unavailable.

---

## Local Development Commands

Recommended local development flow:

```bash
docker compose up -d postgres
cd apps/backend
bun install
bun run dev
```

Run the Flutter app separately:

```bash
cd apps/mobile
flutter pub get
flutter run
```

If migrations are used:

```bash
cd apps/backend
bun run db:migrate
```

If seed data is used:

```bash
cd apps/backend
bun run db:seed
```

---

## Database Persistence

The PostgreSQL container must use a named Docker volume:

```text
postgres_data
```

This prevents local data from being deleted every time the container restarts.

To reset the local database completely:

```bash
docker compose down -v
docker compose up -d postgres
```

Use this only when a full local reset is intended.

---

## Production Deployment Note

For the MVP, PostgreSQL + pgvector can run as a Docker container on the VPS together with the Bun backend.

Recommended production shape:

```text
VPS
  ├── backend container
  ├── postgres + pgvector container
  ├── optional redis container
  └── nginx reverse proxy
```

PostgreSQL must not be exposed publicly.

In production, bind PostgreSQL only to the internal Docker network or localhost.

Do not expose this in production:

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

---

## Infrastructure Boundary

The database infrastructure belongs under:

```text
infra/db/
docker-compose.yml
```

Database schemas and migrations belong under the backend:

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

Docker only provides the database infrastructure. The backend owns the actual memory retrieval logic.

---

## Dockerized pgvector Rule

The project must use Dockerized PostgreSQL + pgvector for local MVP development.

Minimum requirements:

```text
PostgreSQL container
pgvector extension enabled
persistent Docker volume
DATABASE_URL configured in backend
migrations run from backend
Flutter communicates only with backend
```

The local development stack should be:

```text
docker compose up -d postgres
bun backend connects to postgres
Flutter app connects to backend API
```

````

Also update your **Vector Database Choice** section from:

```markdown
Use:

```text
PostgreSQL + pgvector
````

````

to:

```markdown
Use:

```text
PostgreSQL + pgvector, running locally through Docker Compose
````

````

And update the practical answer at the end to:

```markdown
```text
Flutter does not own vector search.
Backend owns vector search.
PostgreSQL stores truth.
pgvector stores semantic aliases/memories.
Every vector is user-scoped.
Semantic memories point to structured meal templates or past meals.
Local development uses Dockerized PostgreSQL + pgvector.
Flutter connects only to the backend, never directly to PostgreSQL.
````

```
```



## Core Tables for Meal Memory

Minimum required tables:

```text
users
meals
meal_items
meal_templates
meal_template_items
food_memories
corrections
action_calls
audit_events
```

---

## `meal_templates`

Stores reusable structured meals.

Example:

```text
template_id: tpl_001
user_id: user_123
name: Usual breakfast
meal_type: breakfast
description: 2 eggs, 2 slices of toast, coffee with milk
usage_count: 27
confidence: 0.94
```

Suggested fields:

```text
id
user_id
name
meal_type
description
usage_count
confidence
last_used_at
created_at
updated_at
archived_at
```

---

## `meal_template_items`

Stores the actual structured foods inside a reusable meal template.

Suggested fields:

```text
id
template_id
food_item_id
display_name
quantity
unit
state
calories
protein_g
carbs_g
fat_g
source
created_at
updated_at
```

Example:

```text
template_id: tpl_001
- 2 eggs
- 2 slices whole wheat toast
- 1 coffee with milk
```

---

## `food_memories`

Stores semantic memory phrases and embeddings.

This table is used for vector search.

Suggested fields:

```text
id
user_id
memory_type
text
embedding
linked_template_id
linked_meal_id
linked_food_id
meal_type
confidence
usage_count
last_used_at
embedding_model
embedding_dimension
created_at
updated_at
```

Important rule:

```text
Every vector memory must belong to one user.
Always filter vector search by user_id.
```

Never perform semantic search across all users.

---

## Example Memory Mapping

A user may have this structured meal template:

```text
tpl_001 = Usual breakfast
- 2 eggs
- 2 slices toast
- coffee with milk
```

The vector memory table may contain multiple semantic phrases pointing to the same template:

```text
“usual breakfast”              → tpl_001
“same breakfast as always”     → tpl_001
“normal breakfast”             → tpl_001
“eggs and toast breakfast”     → tpl_001
“morning meal with eggs”       → tpl_001
```

When the user says:

```text
“Log the same breakfast as always.”
```

The backend should:

```text
1. Generate embedding for the user phrase.
2. Search food_memories filtered by user_id.
3. Retrieve the closest memory candidates.
4. Follow linked_template_id.
5. Load meal_templates and meal_template_items from PostgreSQL.
6. Create a meal proposal.
7. Ask for confirmation or auto-commit only if policy allows.
```

The vector record helps identify the likely meaning.

The relational template stores the actual meal.

---

## Retrieval Flow

Semantic retrieval must happen through a backend tool/action:

```text
query_food_memory
```

The LLM should not query pgvector directly.

Expected flow:

```text
User phrase
  ↓
Backend agent
  ↓
query_food_memory(concept)
  ↓
pgvector search in food_memories WHERE user_id = current user
  ↓
candidate memories/templates
  ↓
agent/tool layer creates meal proposal
```

Example SQL pattern:

```sql
SELECT
  id,
  text,
  memory_type,
  linked_template_id,
  linked_meal_id,
  meal_type,
  confidence,
  usage_count,
  last_used_at,
  embedding <=> $query_embedding AS distance
FROM food_memories
WHERE user_id = $user_id
ORDER BY embedding <=> $query_embedding
LIMIT 10;
```

---

## Retrieval Ranking

Do not rely only on vector similarity.

After retrieving candidates, re-rank using metadata:

```text
semantic similarity
exact alias match
meal_type match
time-of-day context
usage_count
recency
confidence
```

Example scoring idea:

```text
final_score =
  semantic_similarity * 0.45 +
  meal_type_match * 0.20 +
  exact_alias_match * 0.15 +
  recency_score * 0.10 +
  usage_score * 0.05 +
  confidence_score * 0.05
```

If the user says “usual breakfast” in the morning, breakfast templates should be boosted.

---

## Exact Match Before Vector Search

Before vector search, perform exact or normalized alias lookup.

Example:

```text
User phrase: “usual breakfast”
```

If there is an exact alias for `usual breakfast`, use that before fuzzy semantic search.

Preferred retrieval order:

```text
1. Exact alias/template match
2. Temporal deterministic lookup
3. Vector semantic search
4. Clarification question
```

---

## Temporal References

Phrases such as:

```text
“same as yesterday”
“same lunch as yesterday”
“repeat Monday’s dinner”
```

should not primarily use vector search.

They should use deterministic meal history lookup:

```text
1. Resolve date.
2. Resolve meal type if provided.
3. Retrieve committed meal from that date.
4. Create a new proposal copying that meal.
```

Use vector search for vague semantic references, not obvious temporal references.

---

## Embedding Provider

The backend must use an embedding provider abstraction.

Example:

```ts
interface EmbeddingProvider {
  embed(text: string): Promise<number[]>;
}
```

Store the embedding model metadata in the database:

```text
embedding_model
embedding_dimension
```

This is required because embedding models may change later.

---

## Memory Update Rules

Create or update food memories when:

```text
user confirms a meal template
user creates a usual meal
user corrects a recurring meal
same meal pattern appears repeatedly
user explicitly names a meal
```

Example:

```text
User: “Call this my normal breakfast.”

System:
1. Create meal_template if needed.
2. Add food_memory text = “normal breakfast”.
3. Link memory to the template.
4. Store embedding for “normal breakfast”.
```

Corrections should update both current meal/proposal and future memory when appropriate.

Example:

```text
User: “No, my protein shake uses 300ml milk, not 250ml.”

System:
1. Correct current proposal/meal.
2. Update linked meal_template if recurring.
3. Add audit event.
4. Update memory confidence/metadata.
```

---

## Flutter Boundary

Flutter must not perform vector search.

Flutter responsibilities:

```text
record voice/text
send input to backend
display retrieved/proposed meal
allow confirmation/correction
show templates/history
```

Backend responsibilities:

```text
embedding generation
pgvector search
memory ranking
template loading
proposal creation
commit/correction logic
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
      "unit": "units"
    }
  ],
  "requiresConfirmation": true
}
```

````

