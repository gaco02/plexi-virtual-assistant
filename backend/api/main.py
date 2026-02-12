from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from routers import chat, budget, calories, restaurants, auth
from dotenv import load_dotenv
import os
from config.firebase_config import firebase_app  # Import the initialized app
from middleware.auth_middleware import verify_firebase_token
from contextlib import asynccontextmanager
from services.db_service import RestaurantDBService, VirtualAssistantDB
from services.tools.restaurant_tool import RestaurantTool

# Load environment variables
load_dotenv()

# Initialize database services
restaurant_db = RestaurantDBService()
virtual_assistant_db = VirtualAssistantDB()

# Initialize tools with the database services
restaurant_tool = RestaurantTool(db_service=restaurant_db)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup databases on startup


    await restaurant_db.setup_database()
    await virtual_assistant_db.setup_database()


    yield
    # Cleanup on shutdown (if needed)



app = FastAPI(lifespan=lifespan)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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

# Debug print to verify router registration


# Register routers
app.include_router(chat.router, prefix="/chat")
app.include_router(restaurants.router, prefix="/restaurants")
app.include_router(budget.router, prefix="/budget")
app.include_router(calories.router, prefix="/calories")
app.include_router(auth.router)







@app.get("/health")
async def health_check():
    return {"status": "healthy", "message": "API is running"}

@app.get("/")
async def root():
    return {"message": "Virtual Assistant API"}

# Add to protected routes
@app.get("/protected-route")
async def protected_endpoint(user_data=Depends(verify_firebase_token)):
    return {"message": "This is a protected route", "user": user_data}