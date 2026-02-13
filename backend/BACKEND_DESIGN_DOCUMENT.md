# Backend Design Document (Initial Draft)

## 1) Purpose and Scope
This document explains how the backend in `backend/` is structured, what it does, and how request/data flow works end-to-end.

It covers:
- Runtime architecture and startup flow
- API surface and auth model
- Core services and algorithms
- Data model and schema behavior
- External integrations (OpenAI, Firebase, MCP nutrition, TikTok)
- Deployment/runtime operations
- Known issues, risks, and cleanup priorities

---

## 2) High-Level Architecture
The backend is a FastAPI-based service with modular routers, service classes, and PostgreSQL persistence.

Main components:
- **HTTP layer**: FastAPI app(s), router registration, middleware
- **Domain/API routers**: `chat`, `budget`, `calories`, `restaurants`, `auth`
- **Service layer**: DB services + domain tools for budget/calories/restaurants/chat
- **Data layer**: PostgreSQL via `asyncpg` (schema mostly created at runtime)
- **External services**: OpenAI, Firebase token verification, MCP nutrition wrapper, TikTok API

### Architecture sketch
```text
Client (Flutter/web)
  -> FastAPI app (`api/main.py` recommended)
    -> Routers (`routers/*.py`)
      -> Tools/Services (`services/tools/*.py`, `services/*.py`)
        -> DB (`services/db_service.py`, PostgreSQL)
        -> OpenAI API
        -> Firebase Admin SDK
        -> MCP Nutrition HTTP Wrapper (Node)
        -> TikTok RapidAPI
```

---

## 3) Runtime and Entrypoints

## Canonical app path
- Docker and local launcher both point to `api.main:app`:
  - `Dockerfile`: `CMD ["uvicorn", "api.main:app", ...]`
  - `run_api.py`: `uvicorn.run("api.main:app", ...)`

## Startup behavior (`api/main.py`)
- Loads environment variables.
- Creates shared `RestaurantDBService` and `VirtualAssistantDB` instances.
- Registers a FastAPI lifespan handler that runs:
  - `restaurant_db.setup_database()`
  - `virtual_assistant_db.setup_database()`
- Overrides restaurant router dependencies by assignment:
  - `restaurants.get_db_service = get_restaurant_db`
  - `restaurants.get_restaurant_tool = get_restaurant_tool`

## Important: second app exists
- `app.py` defines another FastAPI app with overlapping routes and older TikTok analyzer endpoints.
- This creates an architectural fork (same domain logic exposed from two different app compositions).

---

## 4) Request Lifecycle

Typical authenticated request path:
1. Request hits router endpoint (e.g., `/budget/...`, `/chat/...`).
2. Dependency verifies token (either strict Firebase or fallback-capable middleware depending on endpoint).
3. Router normalizes request payload and user context (`user_id`).
4. Router invokes tool/service class.
5. Service/tool performs extraction + business logic (often OpenAI-assisted), then DB reads/writes.
6. Response returns normalized JSON / Pydantic model.

Common patterns in the code:
- Router-local `get_db()` functions instantiate `VirtualAssistantDB` per request.
- Services open/close `asyncpg` connections for each operation (no shared pool abstraction).
- Business logic is split between routers and tools, with substantial fallback/defensive parsing.

---

## 5) API Surface (Current)

## Base app routes (`api/main.py`)
- `GET /health` (public)
- `GET /` (public)
- `GET /protected-route` (auth via `middleware.auth_middleware.verify_firebase_token`)

## Auth router (`/api/auth` prefix from `routers/auth.py`)
- `POST /api/auth/register` (strict Firebase auth)
- `GET /api/auth/test-token` (strict Firebase auth)
- `POST /api/auth/preferences` (strict Firebase auth)
- `GET /api/auth/preferences` (strict Firebase auth)

## Chat router (`/chat` prefix from `api/main.py`)
- `POST /chat/` (auth via `get_current_user` fallback middleware)
- `GET /chat/chat/history/` (auth via `get_current_user`)
- `DELETE /chat/chat/history/` (auth via `get_current_user`)

Note: history paths include duplicated `chat` segment due to route definitions.

## Budget router (`/budget`)
- `POST /budget/track` (token dependency)
- `POST /budget/transactions/add` (current user dependency)
- `GET /budget/transactions` (current user dependency)
- `POST /budget/transactions` (current user dependency)
- `POST /budget/transactions/update` (current user dependency)
- `POST /budget/transactions/delete` (current user dependency)
- `GET /budget/daily-total` (current user dependency)
- `POST /budget/daily-total` (current user dependency)
- `POST /budget/query` (no auth dependency in this handler)
- `GET /budget/summary` (token dependency)
- `POST /budget/budget-analysis` (token dependency)
- `GET /budget/budget-analysis` (token dependency)
- `GET /budget/recommendations` (current user dependency)

## Calories router (`/calories`)
- `POST /calories/log` (strict Firebase token)
- `POST /calories/entries/add` (current user dependency)
- `GET /calories/entries` (current user dependency)
- `POST /calories/entries` (current user dependency)
- `POST /calories/entries/update` (current user dependency)
- `POST /calories/entries/delete` (current user dependency)
- `POST /calories/query` (strict Firebase token)
- `GET /calories/summary` (strict Firebase token)
- `POST /calories/summary` (strict Firebase token)
- MCP nutrition endpoints (`/nutrition/search`, `/nutrition/barcode`, `/nutrition/food/{food_id}`, `/nutrition/calculate`, `/nutrition/server-status`, `/nutrition/clear-cache`) mostly require current user dependency.

## Restaurants router (`/restaurants`)
- Public:
  - `GET /restaurants/`
  - `GET /restaurants/daily`
  - `GET /restaurants/{restaurant_id}`
  - `GET /restaurants/search/{query}`
  - `GET /restaurants/cuisine/{cuisine_type}`
- Auth required (strict Firebase):
  - `POST /restaurants/recommend`
  - `POST /restaurants/query`

---

## 6) Core Domain Modules and How They Work

## 6.1 Chat orchestration (`routers/chat.py` + `services/chat_service.py`)
- `chat()` endpoint stores incoming user message first.
- Pulls conversation history (by `conversation_id` if present; otherwise recent messages).
- Determines intent with OpenAI (`determine_intent`) and extracts potential multi-intent actions (`extract_multiple_intents`).
- Routes execution to tools:
  - `CalorieTool`
  - `BudgetTool`
  - restaurant recommender path
- Stores assistant response in `chat_messages` with tool metadata.
- `ChatService` handles conversion/parsing of timestamps and `tool_response` JSON.

## 6.2 Budget (`services/tools/budget_tool.py`)
- Decides query vs logging via phrase matching (`is_query_request`).
- For logging:
  - regex-first extraction (`extract_expense_actions` simple patterns)
  - OpenAI extraction fallback with schema-like normalization
  - category inference via regex + optional LLM categorization
- For query:
  - period/scope detection and DB summary retrieval
- Related analysis path (`budget_analysis_tool.py`) implements 50/30/20-style budget allocation and recommendation generation.

## 6.3 Calories (`services/tools/calorie_tool.py`)
- Extracts food actions via OpenAI JSON extraction.
- Estimates grams from quantity/unit (`_estimate_weight_in_grams`).
- Resolves nutrition through MCP-first helper (`get_nutrition_with_fallback`) and fallback food DB.
- Summarizes calories and macros by period.

## 6.4 Restaurants (`services/tools/restaurant_tool.py`)
- Detects recommendation intent with phrase matching.
- Extracts cuisine preference via OpenAI.
- Queries `RestaurantDBService` for daily random, cuisine-filtered, or searched records.
- Builds conversational recommendation text + structured restaurant suggestions.

## 6.5 TikTok integration (`services/tiktok_service.py`)
- Pulls TikTok data via RapidAPI endpoint and maps to internal video schema.
- Used primarily by alternate `app.py` analyzer endpoints.

---

## 7) Data Layer and Schema

## 7.1 DB abstraction
`services/db_service.py` contains two main classes:
- `RestaurantDBService` for restaurant catalog operations.
- `VirtualAssistantDB` for users/preferences/chat/transactions/meals/budget analysis data.

DB connection behavior:
- Uses `asyncpg.connect(...)` per operation.
- Supports Cloud SQL unix socket host if `DB_HOST` starts with `/cloudsql`.

## 7.2 Runtime-created tables (`VirtualAssistantDB.setup_database`)
- `users`
- `user_preferences`
- `chat_messages`
- `transactions`
- `meals`
- `budget_allocations`
- `budget_recommendations`

Key relationship pattern:
- Most domain tables use `user_id TEXT` with FK to `users(firebase_uid)`.

## 7.3 Models (Pydantic)
- `models/chat.py`: `ChatRequest`, `ChatMessage`, `ChatResponse`
- `models/user.py`: `User`, `UserCreate`, `UserPreferences`, enums
- `models/budget.py`: transaction/analysis DTOs
- `models/calories.py`: food macros, summaries, entry payloads
- `models/restaurant.py`: restaurant response models

## 7.4 SQL files vs runtime schema
- `migrations/*.sql` and `chat_messages.sql` include SQLite-style schema (`AUTOINCREMENT`, `DATETIME`, FK refs like `users(id)` in some files).
- Runtime app behavior is PostgreSQL + runtime DDL in Python.
- This is an important consistency gap for migration/versioning and onboarding.

---

## 8) Authentication and Identity Model

Two middleware implementations exist:

1. **Strict Firebase** (`middleware/firebase_auth.py`)
- Requires `Authorization: Bearer <token>`
- Uses `firebase_admin.auth.verify_id_token`
- Rejects failures with HTTP 401

2. **Fallback-capable auth** (`middleware/auth_middleware.py`)
- If Firebase app is unavailable, creates mock dev user (`uid=dev-user`)
- Otherwise verifies token via Firebase
- Provides `get_current_user()` projection (`id`, `email`, `name`)

Firebase initialization (`config/firebase_config.py`):
- Priority 1: `FIREBASE_CREDENTIALS` JSON env var
- Priority 2: `FIREBASE_ADMIN_SDK_PATH` file path
- If neither available: app logs warning and runs without initialized Firebase

Net effect:
- Auth strictness varies by endpoint because routers mix both middleware paths.

---

## 9) External Integrations

## 9.1 OpenAI
Used across chat and tools for:
- intent routing
- structured extraction (expense, foods)
- categorization/recommendation generation

Primary model currently referenced in many places: `gpt-4o-mini`.

## 9.2 MCP nutrition
- Python client wrapper: `services/mcp_nutrition_service.py`
- HTTP endpoint contract: `POST /mcp` with method names (`search_foods`, `get_food`, `lookup_barcode`, `browse_foods`)
- Cache: in-memory 24-hour TTL
- Fallback chain:
  1) MCP server lookup
  2) local fallback nutrition dictionary
  3) generic macro estimate

Node wrapper (`mcp_http_wrapper.js`):
- Express server, mock nutrition DB for development behavior.

## 9.3 TikTok RapidAPI
- `services/tiktok_service.py` uses RapidAPI search endpoint with hardcoded key in source.
- Basic pagination and response mapping with request-failure stop behavior.

---

## 10) Configuration and Environment

`config/settings.py` defines major settings:
- `OPENAI_API_KEY`
- Firebase settings (`FIREBASE_PROJECT_ID`, `FIREBASE_WEB_API_KEY`, `FIREBASE_ADMIN_SDK_PATH`)
- DB settings (`DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_HOST`, `DB_PORT`, plus `DATABASE_URL` legacy)
- MCP settings (`MCP_NUTRITION_SERVER_URL`, `MCP_NUTRITION_ENABLED`)

`requirements.txt` includes FastAPI, asyncpg, OpenAI, Firebase Admin SDK, aiohttp, NLP/data libs.

Node wrapper runtime is separately defined in `package.json`.

---

## 11) Deployment and Operations

## Containerization
- `Dockerfile` uses a multi-stage build with `python:3.11-slim`, runs as non-root `appuser`, and includes a `HEALTHCHECK` directive.
- Canonical entrypoint: `uvicorn api.main:app --host 0.0.0.0 --port 8080`.

## Cloud Run deployment script
- `deploy-cloud-run.sh` deploys service `plexi-assistant-api` to `us-west1`.
- Attaches Cloud SQL instance via Unix socket.
- Sets `ENVIRONMENT=production` to disable dev auth bypass.
- Resource limits: `--memory=512Mi --cpu=1 --max-instances=10`.
- Secrets (DB_PASSWORD, OPENAI_API_KEY, FIREBASE_WEB_API_KEY) must be set before running; script validates their presence.
- Firebase credentials are mounted from Google Secret Manager.

## CORS
- Configurable via `ALLOWED_ORIGINS` env var (comma-separated). Defaults to empty (no origins allowed) if not set.
- Only allows `GET`, `POST`, `PUT`, `DELETE` methods and `Authorization`, `Content-Type` headers.

## Startup behavior
- Connection pools are initialized on startup (`asyncpg.create_pool`).
- Database tables and indexes are created/altered idempotently at startup.
- Pools are closed gracefully on shutdown via the lifespan context manager.

## Observability
- **Structured JSON logging**: All logs are emitted as JSON to stdout, automatically ingested by Cloud Logging on Cloud Run.
- **Rate limiting**: `slowapi` rate limiter attached to the app; can be applied per-route with `@limiter.limit()`.
- **Health check**: `GET /health` validates DB pool connectivity and returns `{"status": "healthy/degraded", "checks": {...}}`.
- **Global error handler**: Catches unhandled exceptions, logs them, and returns a generic error response (no stack trace leakage).

## CI/CD
- GitHub Actions workflow at `.github/workflows/backend-ci.yml`:
  - On PR/push to `main` (backend paths): lint with `ruff`, run `pytest`, build Docker image.
  - Uses a PostgreSQL 15 service container for integration tests.

---

## 12) Known Issues / Risks (Resolved & Remaining)

### Resolved
1. ~~**Dual app entrypoints**~~: `app.py` is deprecated. `api/main.py` is the single canonical entrypoint.
2. ~~**Auth inconsistency**~~: `firebase_auth.py` now re-exports from `auth_middleware.py`. Single implementation with `ENVIRONMENT=development` gating for dev bypass.
3. ~~**Route oddity**~~: Chat history routes fixed from `/chat/chat/history/` to `/chat/history/`.
4. ~~**Secret handling risk**~~: TikTok API key moved to `RAPIDAPI_KEY` env var. CORS restricted. `.gitignore` strengthened.
5. ~~**DB performance**~~: Connection pooling implemented via `asyncpg.create_pool()` with configurable pool sizes.
6. ~~**SQL injection**~~: `get_random_restaurants()` `LIMIT {count}` changed to parameterized `LIMIT $1`.

### Remaining
1. **Schema drift risk**: Runtime Postgres DDL still differs from SQL migration files. Alembic migration system recommended.
2. **Potential bug**: `routers/budget.py` `add_transaction` references `timestamp` variable without local definition.
3. **Integration mismatch risk**: MCP wrapper currently uses mock DB semantics in Node wrapper.
4. **Debug logging**: ~600 `print()` statements remain in `db_service.py` and tools — should be migrated to structured logger and reduced.
5. **REST conventions**: Some query endpoints still use `POST` instead of `GET` (e.g., `POST /budget/transactions`, `POST /calories/summary`).

---

## 13) Production Checklist

Before going live:
- [ ] Rotate exposed OpenAI API key in OpenAI dashboard
- [ ] Rotate Firebase service account credentials in Firebase console
- [ ] Remove `backend/config/*firebase-adminsdk*.json` from git history (BFG or `git filter-branch`)
- [ ] Set `ALLOWED_ORIGINS` env var if serving web clients
- [ ] Set `ENVIRONMENT=production` in Cloud Run (disables dev auth bypass)
- [ ] Verify `GET /health` returns `{"status": "healthy"}` after deployment
- [ ] Run `backend/tests/run_backend_tests.sh` against staging
- [ ] Confirm Firebase project alignment (`.firebaserc` vs deploy script)
- [ ] Consider `--min-instances=1` to avoid cold starts (costs more)

---

## 14) Practical Dev Runbook (Current)

1. Set required env vars: `OPENAI_API_KEY`, DB vars, Firebase vars, `ENVIRONMENT=development`.
2. Ensure PostgreSQL is reachable.
3. Optionally start MCP HTTP wrapper (Node) on port 3000.
4. Start backend with `python run_api.py` (or Docker).
5. Validate with:
   - `GET /health` — should return `{"status": "healthy", "checks": {"database": "ok"}}`
   - `GET /` — should return `{"message": "Virtual Assistant API"}`
   - Authenticated endpoint checks (`/api/auth/test-token`, `/chat/`, etc.)

---

## 15) Document Status
- **Status**: Comprehensive — updated to reflect production readiness improvements
- **Confidence**: High for architecture, endpoint mapping, and deployment configuration
- **Recommended next update**: Add endpoint contract table (request/response examples + auth matrix) and sequence diagrams for chat, budget logging, and calorie logging flows



ssh root@178.128.3.203
cd /opt/plexi/backend
docker compose logs -f api        # Follow API logs
docker compose logs -f postgres   # Follow DB logs
docker compose ps                 # Check status
docker compose down               # Stop everything
docker compose up -d --build      # Rebuild & restart
