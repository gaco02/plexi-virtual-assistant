# Frontend Design Document (Initial Draft)

## 1) Purpose and Scope
This document explains how the Flutter frontend in `frontend/` is organized, how data/state moves through the app, and how it integrates with backend services.

It covers:
- Runtime/app bootstrap and dependency wiring
- UI module and screen structure
- BLoC and repository architecture
- Offline/cache strategy
- API/auth integration
- Build/runtime configuration
- Known risks and recommended cleanup priorities

---

## 2) Technology Stack
Core stack identified from `pubspec.yaml` and code:
- **Framework**: Flutter (Dart)
- **State management**: `flutter_bloc` + `equatable`
- **Networking**: `http` (custom `ApiService` wrapper)
- **Auth**: Firebase Auth + Google Sign-In
- **Persistence**:
  - `sqflite` for local DB data (transactions/calories)
  - `shared_preferences` for lightweight persistence (chat history)
  - `flutter_secure_storage` included for secure local storage use
- **Connectivity/offline**: `connectivity_plus` + local queue/sync abstractions
- **UI/Charts**: Material, `fl_chart`, custom widgets

---

## 3) Application Bootstrap and Runtime Composition

## Entry point
- `lib/main.dart` performs startup initialization in this order:
  1) `WidgetsFlutterBinding.ensureInitialized()`
  2) `Firebase.initializeApp()`
  3) initialize app-wide cache manager
  4) initialize SQLite/database services
  5) instantiate `ApiService` with backend base URL
  6) run app with shared repositories and BLoCs

## Dependency Injection strategy
`main.dart` composes app dependencies with:
- `MultiRepositoryProvider` for repositories/services
- `MultiBlocProvider` for feature BLoCs

This makes one shared `ApiService` available to all repositories.

## Initial screen routing (state-driven)
`_buildInitialScreen()` in `main.dart` selects first UI based on auth + preferences state:
- authenticated + no preferred name -> name welcome screen
- authenticated + preferred name -> home screen
- unauthenticated -> welcome screen

No advanced route package is used; navigation is mostly `Navigator.push` / `MaterialPageRoute`.

---

## 4) High-Level Frontend Architecture

```text
Presentation (screens/widgets)
  -> BLoCs (feature orchestration)
    -> Repositories (domain/data operations)
      -> Services (ApiService, connectivity) + local data sources/cache
        -> Backend API + Firebase Auth + local SQLite/shared prefs
```

Layering pattern in codebase:
- `presentation/`: screens + reusable widgets
- `blocs/`: event/state/logic per feature
- `data/repositories/`: API + cache + local store orchestration
- `data/local/`: SQLite and connectivity helpers
- `services/`: network helpers and utility services
- `utils/`: formatting/calculator/mixins

---

## 5) Feature Modules and Flows

## 5.1 Authentication
Primary files:
- `blocs/auth/auth_bloc.dart`
- `data/repositories/auth_repository.dart`

Flow:
1. `AuthCheckRequested` subscribes to Firebase auth state stream.
2. UI receives one of: `AuthAuthenticated`, `AuthUnauthenticated`, `AuthLoading`, `AuthError`.
3. Sign-in/sign-up events call repository methods and map Firebase exceptions into user-facing errors.

Notes:
- Auth BLoC is foundational and read by many other features for user context.

## 5.2 Chat
Primary files:
- `blocs/chat/chat_bloc.dart`
- `data/repositories/chat_repository.dart`

Flow:
1. Load history from local `SharedPreferences` cache.
2. If empty, inject welcome assistant message.
3. On `SendMessage`:
   - append user message locally
   - emit typing state
   - call backend `/chat/` via `ChatRepository`
   - process response
   - append assistant message
4. Chat response side effects dispatch events to:
   - `TransactionBloc` (budget/expense results)
   - `CalorieBloc` (calorie responses)

This makes chat a central cross-feature orchestrator.

## 5.3 Transactions and Budget Analysis
Primary files:
- `blocs/transaction/transaction_bloc.dart`
- `blocs/transaction_analysis/transaction_analysis_bloc.dart`
- `blocs/budget/budget_bloc.dart`
- `data/repositories/transactions/transaction_repository_new.dart` + specialized repos

Architecture pattern:
- `TransactionRepository` is a facade over specialized repositories:
  - command repository (mutations + offline sync)
  - query repository (reads/period filters)
  - analysis repository (budget analysis endpoints/cache)

Capabilities:
- daily/monthly transaction loading
- add/edit/delete transaction operations
- category totals and monthly summary
- transaction history by period
- budget analysis fetch and refresh
- quick update paths from chat events

Important behavior:
- explicit cache invalidation methods are used before forced refresh
- chat-triggered updates can avoid duplicate state emissions and optimize UI refreshes

## 5.4 Calories and Nutrition
Primary files:
- `blocs/calorie/calorie_bloc.dart`
- `data/repositories/calorie_repository.dart`
- `utils/nutrition_calculator.dart`

Flow:
1. Load daily calories from local + server strategy.
2. Merge/normalize server and local entries, deduplicate by server ID and heuristics.
3. Maintain macro totals + breakdown list in BLoC state.
4. Events handle add/edit/delete entries and chat-driven updates.
5. Calorie goals and nutrition plans derive from preferences when available.

Caching behavior:
- in-memory repository cache with TTL metadata
- local SQLite storage for entries and daily summaries
- lock-based synchronization (`synchronized`) to protect cache updates

## 5.5 Restaurants
Primary files:
- `blocs/restaurant/restaurant_bloc.dart`
- `data/repositories/restaurant_repository.dart`

Capabilities:
- list all restaurants
- daily recommendations
- search by text
- filter by cuisine
- load restaurant details

---

## 6) Core Services and Data Access

## ApiService (`lib/services/api_service.dart`)
Responsibilities:
- build full URLs from base URL + endpoint
- inject auth headers with Firebase ID token (`Authorization: Bearer ...`)
- token caching with soft expiry
- basic throttling between requests
- retry on 401 with forced token refresh
- fallback GET behavior for certain POST failures (404/405)
- UTF-8 safe response decoding

Observations:
- network requests use `http` directly (both client and static `http.post` calls)
- extensive debug logging in service methods

## Local data sources and sync
Transaction feature includes local-first/offline scaffolding:
- `TransactionLocalDataSource`
- `NetworkConnectivityService`
- `TransactionCache`
- command/query repositories performing sync/invalidation routines

Calorie feature also uses local persistence + server reconciliation.

---

## 7) State Management Topology (BLoCs)

BLoCs created in `main.dart`:
- `AuthBloc`
- `PreferencesBloc`
- `TransactionAnalysisBloc`
- `TransactionBloc`
- `CalorieBloc`
- `RestaurantBloc`
- `ChatBloc`
- `BudgetBloc`

Dependency ordering is intentional:
- foundational BLoCs first
- `ChatBloc` depends on auth + transaction + calorie
- `BudgetBloc` depends on `ChatBloc` and `TransactionBloc`

This creates cross-feature reactive behavior but also increases coupling.

---

## 8) UI/Presentation Structure

Main user-facing screens (high-level):
- auth/onboarding flow (`presentation/screens/loging/...`)
- home dashboard (`presentation/screens/home/home_screen.dart`)
- chat screen (`presentation/screens/chat_screen.dart`)
- settings screen
- feature widgets for transaction and calorie summaries

Home screen behavior:
- subscribes to app lifecycle and route events
- triggers transaction loads on init/resume/return
- displays greeting from preferences
- provides quick access to chat via floating action button

UI composition style:
- screen widgets connect to BLoCs via `BlocBuilder`/`BlocListener`
- many reusable widgets under `presentation/widgets/...`

---

## 9) Backend API Integration Map (Frontend Side)

Observed endpoint usage by repositories/services:
- **Chat**: `/chat/`
- **Auth/Preferences**:
  - `/api/auth/register`
  - `/api/auth/preferences`
- **Budget/Transactions**:
  - `/budget/transactions`
  - `/budget/transactions/add`
  - `/budget/transactions/update`
  - `/budget/transactions/delete`
  - `/budget/daily-total`
  - `/budget/budget-analysis`
- **Calories** (examples):
  - `/calories/entries`
  - `/calories/entries/add`
  - `/calories/entries/delete`
  - `/calories/summary`
- **Restaurants**:
  - `/restaurants`
  - `/restaurants/daily`
  - `/restaurants/search/{query}`
  - `/restaurants/cuisine/{type}`
  - `/restaurants/{id}`

Auth model on client side:
- Firebase user ID token fetched from `FirebaseAuth.currentUser.getIdToken(...)`
- attached to API headers for authenticated backend routes

---

## 10) Performance and Reliability Patterns

Patterns present in code:
- request throttling in `ApiService`
- token reuse caching
- selective force-refresh flags for expensive loads
- local cache invalidation hooks before data refresh
- repository-level merge/dedupe logic for calorie and transaction datasets
- timer-based periodic refresh in `CalorieBloc` with guard conditions

Potentially expensive behaviors still present:
- high-frequency debug logging in hot paths
- large BLoC handlers doing parsing + orchestration + side effects in one method
- repeated manual cache invalidation triggers from multiple UI points

---

## 11) Build, Runtime, and Environment Notes

## Build/runtime
- Flutter app configured in `pubspec.yaml`.
- Assets under `assets/images/*`.
- Android and iOS directories exist with standard Flutter project layout.

## Backend base URL
- hardcoded in `main.dart` currently (`http://192.168.1.215:8000` with an old Cloud Run URL commented out).
- No dedicated environment/flavor config abstraction detected in this pass.

---

## 12) Known Issues / Risks (Observed)

1. **Hardcoded API base URL** in app bootstrap (`main.dart`) complicates dev/stage/prod switching.
2. **High module coupling**:
   - `ChatBloc` directly dispatches side-effect events to transaction and calorie blocs.
3. **Complex repository methods** (especially calorie and transaction flows) increase regression risk.
4. **Inconsistent endpoint assumptions** may exist (some fallback behavior tries alternate methods on error).
5. **Large handlers with mixed concerns** (network parsing + business logic + UI-state shaping) reduce maintainability.
6. **Debug logging verbosity** in production code paths can impact observability signal/noise.
7. **Route/screen organization naming** includes typo-style folder (`loging`) and mixed conventions.
8. **No clear centralized contract layer** for API endpoint schemas and versioning.

---

## 13) Recommended Refactoring Priorities

Priority 1 (stability + operability):
- Introduce environment-driven config for `baseUrl` (flavors or build-time dart-define).
- Centralize API endpoint constants and request/response contract mappers.
- Reduce noisy logging; keep structured errors only.

Priority 2 (maintainability):
- Split oversized BLoC handlers into dedicated use-case/service classes.
- Reduce cross-bloc coupling by using explicit domain events or a mediator/use-case layer.
- Normalize folder naming and feature module boundaries.

Priority 3 (performance + correctness):
- Consolidate cache refresh strategy to avoid duplicate reloads.
- Add test coverage for repository merge/dedupe logic and chat side effects.

---

## 14) Practical Dev Runbook (Current)

1. Ensure Firebase project config is set for Android/iOS builds.
2. Start backend API and confirm `/health` is reachable.
3. Set/update API base URL in `main.dart` for your network.
4. Run app (`flutter run`) and verify:
   - auth flow
   - home dashboard data
   - chat message round-trip
   - transaction + calorie updates from chat side effects

---

## 15) Document Status
- **Status**: Initial comprehensive frontend draft
- **Confidence**: High for architecture/composition and major feature flows; medium for every edge case in very large repository/BLoC methods
- **Suggested next update**: add a frontend API contract appendix (per repository method), and sequence diagrams for chat→transaction and chat→calorie update flows

---

## 16) Frontend API Contract Appendix (Repository → Endpoint)

This appendix maps the **actual frontend repository/service calls** to backend endpoints and expected payload/response shapes.

## 16.1 Global transport/auth contract (`ApiService`)
- **Base URL**: configured in `main.dart` and passed into `ApiService(baseUrl: ...)`.
- **Auth header**: all calls include `Authorization: Bearer <firebase_id_token>` from `FirebaseAuth.currentUser.getIdToken(...)`.
- **Retry behavior**: if 401, token cache is invalidated and request retries once with a fresh token.
- **Fallback behavior**: selected POSTs may retry as GET for `summary/transactions/daily-total` style endpoints on 404/405.

## 16.2 Auth/Preferences contracts

| Frontend method | Endpoint | HTTP | Request shape | Expected response |
|---|---|---|---|---|
| `AuthRepository.registerUserWithBackend(user)` | `/api/auth/register` | POST | `{ email, name, firebase_uid }` | `{ message, user }` (or already-registered message) |
| `PreferencesRepository.getPreferences()` | `/api/auth/preferences` | GET | none | preferences object (or default empty object on frontend fallback) |
| `PreferencesRepository.savePreferences(preferences)` | `/api/auth/preferences` | POST | preferences fields (salary, weights, goals, profile fields) | success message/object |
| `PreferencesRepository.updatePreferences(preferences)` | `/api/auth/preferences` | PUT | preferences JSON | success message/object |

Notes:
- `savePreferences` has retry logic after delay for backend FK/500 race conditions.

## 16.3 Chat contracts

| Frontend method | Endpoint | HTTP | Request shape | Expected response |
|---|---|---|---|---|
| `ChatRepository.sendMessage(message, history, timestamp, userId)` | `/chat/` | POST | `{ message, conversation_history, timestamp, tool, user_id, local_time, timezone }` | chat response with `response`, optional `expense_info`, `calorie_info`, and context/tool fields |

Notes:
- `ChatRepository` persists local history in `SharedPreferences` regardless of server success.
- `ChatBloc` propagates parsed response side-effects to `TransactionBloc` and `CalorieBloc`.

## 16.4 Restaurant contracts

| Frontend method | Endpoint | HTTP | Request shape | Expected response |
|---|---|---|---|---|
| `RestaurantRepository.getRestaurants()` | `/restaurants` | GET | none | list of restaurant summaries |
| `RestaurantRepository.getDailyRecommendations(count)` | `/restaurants/daily` | GET | query: `{ count }` | list of recommended restaurants |
| `RestaurantRepository.getRestaurantsByCuisine(cuisineType)` | `/restaurants/cuisine/{cuisineType}` | GET | path param | list of restaurants |
| `RestaurantRepository.searchRestaurants(query)` | `/restaurants/search/{query}` | GET | path param | list of restaurants |
| `RestaurantRepository.getRestaurantDetails(id)` | `/restaurants/{id}` | GET | path param | restaurant details object |

Notes:
- Repository has fallback behavior to cached/all restaurants when daily endpoint fails.
- Synthetic IDs are generated on frontend when backend response lacks `id`.

## 16.5 Budget + transaction contracts

### A) `TransactionApiService` core endpoints

| Frontend method | Endpoint | HTTP | Request shape | Expected response |
|---|---|---|---|---|
| `logTransaction(userId, amount, category, description)` | `/budget/transactions/add` | POST | `{ user_id, amount, category, description }` | success object |
| `updateTransaction(userId, id, amount, category, description)` | `/budget/transactions/update` | POST | `{ user_id, transaction_id, amount, category, description }` | success object |
| `deleteTransaction(userId, id)` | `/budget/transactions/delete` | POST | `{ user_id, transaction_id }` | success object |
| `getDailyTransactions(userId)` | `/budget/transactions` | POST | `{ user_id, period: "daily" }` | list or wrapper containing transactions |
| `getTransactionsByPeriod(userId, period, forceRefresh)` | `/budget/transactions` | POST | `{ user_id, period, force_refresh }` | list/wrapper |
| `getDailyTotal(userId, forceRefresh)` | `/budget/daily-total` | POST | `{ user_id, force_refresh }` | `{ success, total, ... }` |
| `getTransactionAnalysis(userId, queryParams)` | `/budget/budget-analysis` | POST | `{ user_id, month?, monthly_salary?, force_refresh? }` | budget analysis object |
| `getTransactionHistory(userId, period, date, forceRefresh)` | `/budget/transactions` | POST | `{ user_id, period, date?, force_refresh }` | list/wrapper |

### B) `BudgetRepository` direct calls

| Frontend method | Endpoint | HTTP | Request shape | Expected response |
|---|---|---|---|---|
| `getBudgetAnalysis(month, period)` | `/budget/analysis` | GET | query: `{ month?, period }` | budget analysis |
| `getDailyTransactions()` | `/budget/transactions` | POST | `{ user_id, period: "daily" }` | transactions list/wrapper |
| `getDailyTotal()` | `/budget/daily-total` | POST | `{ user_id }` | `{ success, total }` |
| `addTransaction(transaction)` | `/budget/transactions/add` | POST | user_id + transaction payload | success object |
| `getTransactionsByPeriod(period, month)` | `/budget/transactions` | POST | `{ user_id, period, month? }` | list/wrapper |

Important contract note:
- `BudgetRepository.getBudgetAnalysis` uses `/budget/analysis` (GET), while other modules use `/budget/budget-analysis` (POST). This is a known endpoint mismatch risk.

## 16.6 Calorie contracts (`CalorieRepository`)

| Frontend method / flow | Endpoint | HTTP | Request shape | Expected response |
|---|---|---|---|---|
| Daily entries fetch flow | `/calories/entries` | POST | `{ user_id, period: "daily" }` | entries list or wrapper |
| Daily summary fetch flow | `/calories/summary` | POST | `{ user_id, period: "daily" }` | summary object with totals/breakdown |
| Add entry | `/calories/entries/add` | POST | `{ user_id, food_item, calories, carbs?, protein?, fat?, quantity, unit, timestamp }` | success + maybe updated totals |
| Edit entry flow | `/calories/update` | POST | update payload | success object |
| Delete entry flow | `/calories/entries/delete` | POST | `{ user_id, entry_id }` | success object |

Important contract note:
- Frontend currently calls `/calories/update` for edit, while backend router commonly exposes `/calories/entries/update`; this is another mismatch risk.

## 16.7 Unified auth expectation matrix

| Endpoint group | Frontend sends bearer token? | Frontend behavior if unauthorized |
|---|---|---|
| `/api/auth/*` | Yes (always through `ApiService`) | token refresh + one retry, then throw |
| `/chat/*` | Yes | token refresh + retry |
| `/budget/*` | Yes | token refresh + retry; repositories may fallback/default |
| `/calories/*` | Yes | token refresh + retry; repository may keep local cache |
| `/restaurants/*` | Yes for all calls from client | token refresh + retry |

## 16.8 Appendix change-log target
- If backend contract changes, update this section first and then update:
  1) repository method payload mappers,
  2) BLoC parsing assumptions,
  3) local cache merge logic (especially calories/transactions).

---

## 17) Contract Alignment Checklist (Actionable)

This checklist is the implementation guide to align frontend endpoint usage with the current backend contract.

## 17.1 Critical mismatches to fix first

| Priority | Frontend location | Current call | Canonical backend contract | Required change |
|---|---|---|---|---|
| P0 | `data/repositories/budget_repository.dart` (`getBudgetAnalysis`) | `GET /budget/analysis` | `POST /budget/budget-analysis` | ✅ Completed: switched to POST `/budget/budget-analysis` with body payload including `user_id` and optional period/month. |
| P0 | `data/repositories/calorie_repository.dart` (edit flow) | `POST /calories/update` | `POST /calories/entries/update` | ✅ Completed: endpoint changed to `/calories/entries/update`. |
| P1 | `data/repositories/preferences_repository.dart` (`updatePreferences`) | `PUT /api/auth/preferences` | `POST /api/auth/preferences` (GET/POST implemented backend-side) | ✅ Completed: `updatePreferences` now uses POST `/api/auth/preferences`. |

## 17.2 Secondary alignment checks (confirm + keep)

| Priority | Frontend location | Current call | Backend status | Action |
|---|---|---|---|---|
| P1 | `data/repositories/chat_repository.dart` | `POST /chat/` | Matches current backend router | Keep as-is. |
| P1 | `data/repositories/restaurant_repository.dart` | `/restaurants`, `/daily`, `/search/{q}`, `/cuisine/{type}`, `/{id}` | Matches current backend router | Keep as-is. |
| P1 | `data/repositories/transactions/transaction_api_service.dart` | `/budget/transactions*`, `/budget/daily-total`, `/budget/budget-analysis` | Matches current backend router | Keep as-is. |
| P2 | `data/repositories/calorie_repository.dart` | `/calories/entries`, `/calories/summary`, `/calories/entries/add`, `/calories/entries/delete` | Generally matches current backend router | Keep, but verify response-shape assumptions remain stable. |

## 17.3 Code-change checklist by file

1. `frontend/lib/data/repositories/budget_repository.dart`
  - [x] Update `getBudgetAnalysis` to call `/budget/budget-analysis` via POST.
  - [x] Remove/replace `period` query-only assumptions and send body payload.
  - [ ] Validate parsing against actual budget-analysis response object (runtime verification pending).

2. `frontend/lib/data/repositories/calorie_repository.dart`
  - [x] Replace `/calories/update` with `/calories/entries/update`.
  - [x] Confirm request payload includes `entry_id` + updated fields expected by backend.

3. `frontend/lib/data/repositories/preferences_repository.dart`
  - [x] Replace `put('/api/auth/preferences', ...)` with `post('/api/auth/preferences', ...)` **or** align backend to accept PUT explicitly.
  - [ ] Keep retry behavior for FK/timing issues only if still needed after alignment (behavior intentionally preserved for now).

## 17.4 Validation checklist after alignment

Execute these manual verifications in-app after endpoint fixes:
- [ ] Sign in, save preferences, and reload settings (no 405/500 path mismatch errors).
- [ ] Open budget summary and budget analysis (analysis loads from canonical endpoint).
- [ ] Edit a calorie entry (update call returns success and reflects in daily totals).
- [ ] Confirm chat-driven budget and calorie updates still propagate to their blocs.
- [ ] Run app with network on/off to confirm offline fallback behavior still works.

## 17.5 Contract governance recommendation

To prevent future drift:
- Define endpoint constants in one file (for example `lib/data/api/endpoints.dart`).
- Use one transport contract path for each domain repository (avoid duplicate direct calls with alternate paths).
- Keep this section in sync whenever backend routes change.
