from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from datetime import datetime

class Restaurant(BaseModel):
    """Model for restaurant information"""
    id: Optional[int] = None
    name: str
    cuisine_type: str
    price_level: str
    highlights: List[str] = []
    image_url: str
    cuisine: List[str] = []
    address: str
    description: str
    rating: float
    menu: List[str] = []

class RestaurantSummary(BaseModel):
    """Model for restaurant summary information"""
    name: str
    cuisine_type: str
    price_level: str
    highlights_summary: Optional[str] = None
    rating: float
    address: str

class RestaurantRecommendation(BaseModel):
    """Model for restaurant recommendation response"""
    response: str
    restaurant_suggestions: List[Dict[str, Any]] = [] 