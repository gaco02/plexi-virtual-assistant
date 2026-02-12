from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
from services.db_service import RestaurantDBService
from services.tools.restaurant_tool import RestaurantTool
from models.restaurant import Restaurant, RestaurantSummary, RestaurantRecommendation
from models.chat import ChatRequest, ChatResponse
from middleware.firebase_auth import verify_firebase_token
from openai import OpenAI
import json
from datetime import datetime
from config.settings import get_settings

router = APIRouter()
settings = get_settings()
# Create a database instance that will be replaced by dependency injection
db_service = RestaurantDBService()
# Create a tool instance that will be replaced by dependency injection
restaurant_tool = RestaurantTool()
client = OpenAI(api_key=settings.OPENAI_API_KEY)

# Dependency to get the database service
async def get_db_service():
    # This will be overridden in main.py with the properly initialized instance
    return db_service

# Dependency to get the restaurant tool
async def get_restaurant_tool():
    # This will be overridden in main.py with the properly initialized instance
    return restaurant_tool

@router.get("/", response_model=List[RestaurantSummary])
async def get_all_restaurants(db: RestaurantDBService = Depends(get_db_service)):
    """
    Get all restaurants from the database
    """
    try:
        restaurants = await db.get_all_restaurants()
        return [
            RestaurantSummary(
                name=rest["name"],
                cuisine_type=rest["cuisine_type"],
                price_level=rest["price_level"],
                highlights_summary=json.dumps(rest.get("highlights", [])),
                rating=rest["rating"],
                address=rest["address"]
            )
            for rest in restaurants
        ]
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))

@router.get("/daily", response_model=List[RestaurantSummary])
async def get_daily_recommendations(count: int = 5, db: RestaurantDBService = Depends(get_db_service)):
    """
    Get daily restaurant recommendations
    """
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        restaurants = await db.get_random_restaurants(count=count, seed=today)
        return [
            RestaurantSummary(
                name=rest["name"],
                cuisine_type=rest["cuisine_type"],
                price_level=rest["price_level"],
                highlights_summary=json.dumps(rest.get("highlights", [])),
                rating=rest["rating"],
                address=rest["address"]
            )
            for rest in restaurants
        ]
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{restaurant_id}", response_model=Restaurant)
async def get_restaurant_details(restaurant_id: int, db: RestaurantDBService = Depends(get_db_service)):
    """
    Get details for a specific restaurant
    """
    try:
        restaurant = await db.get_restaurant_by_id(restaurant_id)
        if not restaurant:
            raise HTTPException(status_code=404, detail="Restaurant not found")
        
        return Restaurant(
            id=restaurant["id"],
            name=restaurant["name"],
            cuisine_type=restaurant["cuisine_type"],
            price_level=restaurant["price_level"],
            highlights=restaurant.get("highlights", []),
            image_url=restaurant.get("image_url", ""),
            cuisine=restaurant.get("cuisine", []),
            address=restaurant["address"],
            description=restaurant["description"],
            rating=restaurant["rating"],
            menu=restaurant.get("menu", [])
        )
    except HTTPException:
        raise
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search/{query}", response_model=List[RestaurantSummary])
async def search_restaurants(query: str, db: RestaurantDBService = Depends(get_db_service)):
    """
    Search for restaurants by name, cuisine type, or description
    """
    try:
        restaurants = await db.search_restaurants(query)
        return [
            RestaurantSummary(
                name=rest["name"],
                cuisine_type=rest["cuisine_type"],
                price_level=rest["price_level"],
                highlights_summary=json.dumps(rest.get("highlights", [])),
                rating=rest["rating"],
                address=rest["address"]
            )
            for rest in restaurants
        ]
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))

@router.get("/cuisine/{cuisine_type}", response_model=List[RestaurantSummary])
async def get_restaurants_by_cuisine(cuisine_type: str, db: RestaurantDBService = Depends(get_db_service)):
    """
    Get restaurants by cuisine type
    """
    try:
        restaurants = await db.get_restaurants_by_cuisine(cuisine_type)
        return [
            RestaurantSummary(
                name=rest["name"],
                cuisine_type=rest["cuisine_type"],
                price_level=rest["price_level"],
                highlights_summary=json.dumps(rest.get("highlights", [])),
                rating=rest["rating"],
                address=rest["address"]
            )
            for rest in restaurants
        ]
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))

@router.post("/recommend", response_model=List[RestaurantRecommendation])
async def recommend_restaurants(request: ChatRequest, token=Depends(verify_firebase_token), tool: RestaurantTool = Depends(get_restaurant_tool)):
    """
    Restaurant recommendation endpoint that uses the restaurant tool
    """
    try:
        # Add user_id from token
        request.user_id = token['uid']
        
        # Process the request using the restaurant tool
        return await tool.process_request(request)
        
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))

@router.post("/query", response_model=ChatResponse)
async def query_restaurants(request: ChatRequest, token=Depends(verify_firebase_token), tool: RestaurantTool = Depends(get_restaurant_tool)):
    """
    Restaurant query endpoint that uses the restaurant tool
    """
    try:
        # Add user_id from token
        request.user_id = token['uid']
        
        # Process the request using the restaurant tool
        return await tool.handle_query(request)
        
    except Exception as e:

        raise HTTPException(status_code=500, detail=str(e))