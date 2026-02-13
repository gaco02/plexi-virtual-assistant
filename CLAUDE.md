# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Plexi Virtual Assistant** is a monorepo containing a Flutter mobile app (frontend) and a Python FastAPI server (backend). The app provides AI-powered financial tracking, calorie tracking, chat, and restaurant recommendations.

### Monorepo Structure
- `frontend/` - Flutter mobile application
- `backend/` - Python FastAPI backend server

---

## Frontend (Flutter App)

### Key Directories
- `frontend/lib/` - Main Flutter application code
- `frontend/lib/blocs/` - BLoC state management (auth, budget, calorie, chat, etc.)
- `frontend/lib/data/` - Data layer (repositories, models, local storage)
- `frontend/lib/presentation/` - UI screens and widgets
- `frontend/lib/services/` - Core services (API, calculations, connectivity)
- `frontend/android/` - Android-specific configuration
- `frontend/ios/` - iOS-specific configuration

### Development Commands
Always run Flutter commands from the `frontend/` directory:
```bash
cd frontend
flutter pub get       # Install dependencies
flutter run           # Run in development mode
flutter build apk     # Build Android APK
flutter build ios     # Build iOS app
flutter test          # Run tests
flutter analyze       # Run static analysis
flutter clean         # Clean build files
```

### Architecture
- **State Management**: BLoC pattern with flutter_bloc
- **Data Layer**: Repositories abstracting API + local SQLite storage
- **Offline Support**: SQLite cache with sync queue, connectivity monitoring
- **Authentication**: Firebase Auth (Google, Apple, Email/Password)

### BLoC Initialization Order (in main.dart)
1. Core blocs (AuthBloc, PreferencesBloc)
2. Feature blocs (TransactionBloc, CalorieBloc)
3. Dependent blocs (ChatBloc depends on others, BudgetBloc depends on ChatBloc)

### Key Components
- **TransactionRepository** - Facade for financial operations (API + cache + local DB)
- **CalorieRepository** - Calorie entry CRUD with deduplication
- **ChatRepository** - AI chat via backend API
- **ApiService** - HTTP client with Firebase token injection and auto-retry

### Frontend Dependencies
`flutter_bloc`, `firebase_auth`, `sqflite`, `dio`, `shared_preferences`, `connectivity_plus`, `fl_chart`

### API Configuration
Update `baseUrl` in `frontend/lib/main.dart`:
```dart
final apiService = ApiService(baseUrl: 'your-api-url');
```
- Development: `http://192.168.1.215:8000`
- Production (Digital Ocean): `http://<DROPLET_IP>:8080`

### Known Issues
See `frontend/CRASH_FIX_SUMMARY.md` for calorie entry deletion crash fixes.

---

## Backend (FastAPI Server)

### Development Commands
Run from the `backend/` directory:
```bash
cd backend
pip install -r requirements.txt    # Install dependencies
cp .env.example .env               # Set up environment variables
python run_api.py                  # Development mode (auto-reload)
uvicorn api.main:app --host 0.0.0.0 --port 8000  # Production mode
```

### Testing
```bash
cd backend
python tests/test_chat.py
python tests/test_budget.py
python tests/test_calories.py
curl -X GET http://localhost:8000/health
```

### Deployment (Digital Ocean)
```bash
cd backend
cp .env.production.example .env    # Fill in your secrets
docker compose up -d --build       # Start PostgreSQL + API
docker compose logs -f api         # Follow logs
curl http://localhost:8080/health  # Verify
```

For first-time Droplet setup, use the deploy script:
```bash
ssh root@<DROPLET_IP>
cd /opt/plexi/backend
./deploy-digitalocean.sh
```

### Application Structure

#### Entry Points
- `backend/api/main.py` - Main FastAPI application with router structure
- `backend/run_api.py` - Development server runner
- `backend/app.py` - Legacy TikTok analysis endpoints

#### Routers
- `routers/chat.py` - Chat and AI conversation handling
- `routers/auth.py` - Authentication endpoints
- `routers/budget.py` - Financial transaction management
- `routers/calories.py` - Calorie tracking and nutrition
- `routers/restaurants.py` - Restaurant recommendations

#### Core Services
- `services/db_service.py` - Database operations (PostgreSQL)
- `services/chat_service.py` - Chat message persistence
- `services/tools/budget_tool.py` - Financial transaction AI processing
- `services/tools/calorie_tool.py` - Nutrition tracking AI processing
- `services/tools/restaurant_tool.py` - Restaurant recommendations
- `services/tools/budget_analysis_tool.py` - Advanced budget analytics

#### Data Models
- `models/budget.py` - Transaction and budget models
- `models/calories.py` - Calorie entry and nutrition models
- `models/chat.py` - Chat message and conversation models
- `models/restaurant.py` - Restaurant and recommendation models
- `models/user.py` - User profile and preferences

### AI Integration Architecture

#### Intent Recognition Flow
1. User message → `determine_intent()` (GPT-4o-mini) → classify as budget/calories/restaurant/conversation
2. `extract_multiple_intents()` → detect multi-intent messages (e.g., "I spent $25 on a burger" → budget + calories)
3. Route to appropriate tool → process → combine responses → return to client

#### Tool Processing
- **BudgetTool** - Extracts financial data, categorizes expenses
- **CalorieTool** - Processes nutrition info via MCP OpenNutrition with fallback DB
- **RestaurantTool** - Provides personalized restaurant suggestions

### Authentication & Security
- Firebase Authentication with JWT token verification
- `middleware/auth_middleware.py` - Token validation
- All protected routes require `Authorization: Bearer <firebase-token>` header

### Database
- **Development**: PostgreSQL (local or via `docker compose up`)
- **Production**: PostgreSQL on Digital Ocean Droplet (via Docker Compose)
- Async operations via `asyncpg`
- Tables auto-created by `setup_database()` on startup
- Migrations in `migrations/` directory

#### Core Tables
`users`, `user_preferences`, `chat_messages`, `transactions`, `calorie_entries`, `budget_allocations`, `budget_recommendations`, `restaurants`

### Environment Variables (.env)
```bash
OPENAI_API_KEY=your-openai-api-key
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_WEB_API_KEY=your-firebase-web-api-key
FIREBASE_CREDENTIALS=<single-line-json-of-service-account>
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=postgres
```
See `backend/.env.production.example` for production template.

### Backend Dependencies
`fastapi`, `uvicorn`, `firebase-admin`, `asyncpg`, `openai`, `pydantic`, `python-dotenv`, `aiohttp`

---

## Common Development Tasks

### Adding New AI Tools (Backend)
1. Create tool class in `backend/services/tools/`
2. Implement `process_request()` method
3. Add intent recognition in `backend/routers/chat.py`
4. Update database schema if needed

### Adding New Endpoints (Backend)
1. Create/update router in `backend/routers/`
2. Add authentication if needed
3. Update `backend/api/main.py`
4. Write tests in `backend/tests/`

### Database Schema Changes (Backend)
1. Create migration in `backend/migrations/`
2. Update models in `backend/models/`
3. Modify database service methods in `backend/services/db_service.py`

## Frontend ↔ Backend Integration
- Flutter `ApiService` sends requests with Firebase ID tokens
- Backend verifies tokens and extracts user ID
- Structured JSON responses match Flutter model expectations
- Chat: `ChatRequest` → `ChatResponse` with tool context, expense_info, calorie_info
