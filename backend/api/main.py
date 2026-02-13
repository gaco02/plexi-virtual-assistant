from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from routers import chat, budget, calories, restaurants, auth
from dotenv import load_dotenv
import os
import logging
import json
import sys
from config.firebase_config import firebase_app  # Import the initialized app
from middleware.auth_middleware import verify_firebase_token
from contextlib import asynccontextmanager
from services.db_service import RestaurantDBService, VirtualAssistantDB
from services.tools.restaurant_tool import RestaurantTool
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Load environment variables
load_dotenv()

# --- Structured JSON logging ---
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info and record.exc_info[0]:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)

# Configure root logger with JSON output (Cloud Run auto-ingests to Cloud Logging)
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler], force=True)

logger = logging.getLogger(__name__)

# --- Rate limiter ---
limiter = Limiter(key_func=get_remote_address)

# Initialize database services
restaurant_db = RestaurantDBService()
virtual_assistant_db = VirtualAssistantDB()

# Initialize tools with the database services
restaurant_tool = RestaurantTool(db_service=restaurant_db)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup: initialize connection pools and create tables
    await restaurant_db.setup_database()
    await virtual_assistant_db.setup_database()
    logger.info("Database pools initialized and tables ready")

    yield

    # Shutdown: close connection pools
    await restaurant_db.close_pool()
    await virtual_assistant_db.close_pool()
    logger.info("Database pools closed")


app = FastAPI(lifespan=lifespan)

# Attach rate limiter to the app
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Global exception handler — prevents leaking internal errors to clients
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "internal_server_error", "message": "An unexpected error occurred."},
    )

# Add CORS middleware
# For mobile-only apps, CORS is not strictly needed. Restrict origins in production.
allowed_origins = os.getenv("ALLOWED_ORIGINS", "").split(",") if os.getenv("ALLOWED_ORIGINS") else []
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# Override the database dependency in the routers
async def get_restaurant_db():
    return restaurant_db

# Override the restaurant tool dependency
async def get_restaurant_tool():
    return restaurant_tool

# Override the dependencies
restaurants.get_db_service = get_restaurant_db
restaurants.get_restaurant_tool = get_restaurant_tool

# Register routers
app.include_router(chat.router, prefix="/chat")
app.include_router(restaurants.router, prefix="/restaurants")
app.include_router(budget.router, prefix="/budget")
app.include_router(calories.router, prefix="/calories")
app.include_router(auth.router)


@app.get("/health")
async def health_check():
    """Enhanced health check with dependency status."""
    checks = {}

    # Database connectivity check
    try:
        if virtual_assistant_db._pool:
            async with virtual_assistant_db._pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            checks["database"] = "ok"
        else:
            checks["database"] = "not_initialized"
    except Exception:
        checks["database"] = "failing"

    overall = "healthy" if all(v == "ok" for v in checks.values()) else "degraded"
    return {"status": overall, "checks": checks}

@app.get("/")
async def root():
    return {"message": "Virtual Assistant API"}

# Protected route example
@app.get("/protected-route")
@limiter.limit("30/minute")
async def protected_endpoint(request: Request, user_data=Depends(verify_firebase_token)):
    return {"message": "This is a protected route", "user": user_data}
