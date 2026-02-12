"""
MCP Nutrition Service

This service provides an interface to the MCP OpenNutrition server for accurate
nutrition data lookup. It serves as a wrapper around the MCP client to provide
nutrition information for the calorie tracking system.
"""

import json
import logging
import asyncio
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
import aiohttp
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

@dataclass
class NutritionData:
    """Represents nutrition data for a food item"""
    food_id: str
    food_name: str
    calories_per_100g: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: Optional[float] = None
    sugar_g: Optional[float] = None
    sodium_mg: Optional[float] = None
    brand: Optional[str] = None
    barcode: Optional[str] = None
    serving_size_g: Optional[float] = None
    
    def get_nutrition_for_amount(self, amount_g: float) -> Dict[str, float]:
        """Calculate nutrition values for a specific amount in grams"""
        multiplier = amount_g / 100.0
        return {
            "calories": round(self.calories_per_100g * multiplier, 1),
            "protein": round(self.protein_g * multiplier, 1),
            "carbs": round(self.carbs_g * multiplier, 1),
            "fat": round(self.fat_g * multiplier, 1),
            "fiber": round(self.fiber_g * multiplier, 1) if self.fiber_g else 0,
            "sugar": round(self.sugar_g * multiplier, 1) if self.sugar_g else 0,
            "sodium": round(self.sodium_mg * multiplier, 1) if self.sodium_mg else 0
        }

class MCPNutritionService:
    """Service for interfacing with MCP OpenNutrition server"""
    
    def __init__(self, mcp_server_url: str = "http://localhost:3000"):
        self.mcp_server_url = mcp_server_url
        self.cache = {}  # Simple in-memory cache
        self.cache_ttl = timedelta(hours=24)  # Cache for 24 hours
        
    async def _make_mcp_request(self, method: str, params: Dict[str, Any]) -> Optional[Dict]:
        """Make a request to the MCP OpenNutrition server"""
        try:
            # MCP request format
            request_data = {
                "method": method,
                "params": params
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.mcp_server_url}/mcp",
                    json=request_data,
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        return result.get("result")
                    else:
                        logger.error(f"MCP server error: {response.status}")
                        return None
                        
        except asyncio.TimeoutError:
            logger.error("MCP server request timeout")
            return None
        except aiohttp.ClientError as e:
            logger.error(f"MCP server connection error: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error in MCP request: {e}")
            return None

    def _parse_nutrition_data(self, raw_data: Dict) -> Optional[NutritionData]:
        """Parse raw MCP nutrition data into NutritionData object"""
        try:
            # Extract nutrition data from MCP response format
            # This will need to be adjusted based on the actual MCP OpenNutrition response format
            nutrition = raw_data.get("nutrition", {})
            
            return NutritionData(
                food_id=str(raw_data.get("id", "")),
                food_name=raw_data.get("name", ""),
                calories_per_100g=float(nutrition.get("energy_kcal", 0)),
                protein_g=float(nutrition.get("protein", 0)),
                carbs_g=float(nutrition.get("carbohydrates", 0)),
                fat_g=float(nutrition.get("fat", 0)),
                fiber_g=float(nutrition.get("fiber", 0)) if nutrition.get("fiber") else None,
                sugar_g=float(nutrition.get("sugar", 0)) if nutrition.get("sugar") else None,
                sodium_mg=float(nutrition.get("sodium", 0)) if nutrition.get("sodium") else None,
                brand=raw_data.get("brand"),
                barcode=raw_data.get("barcode"),
                serving_size_g=float(raw_data.get("serving_size", 100)) if raw_data.get("serving_size") else None
            )
        except (ValueError, KeyError, TypeError) as e:
            logger.error(f"Error parsing nutrition data: {e}")
            return None

    async def search_foods(self, query: str, limit: int = 10) -> List[NutritionData]:
        """Search for foods by name"""
        cache_key = f"search_{query}_{limit}"
        
        # Check cache first
        if cache_key in self.cache:
            cached_data, timestamp = self.cache[cache_key]
            if datetime.now() - timestamp < self.cache_ttl:
                return cached_data
        
        try:
            result = await self._make_mcp_request("search_foods", {
                "query": query,
                "limit": limit
            })
            
            if not result:
                return []
            
            foods = []
            for item in result.get("foods", []):
                nutrition_data = self._parse_nutrition_data(item)
                if nutrition_data:
                    foods.append(nutrition_data)
            
            # Cache the result
            self.cache[cache_key] = (foods, datetime.now())
            return foods
            
        except Exception as e:
            logger.error(f"Error searching foods: {e}")
            return []

    async def get_food_by_id(self, food_id: str) -> Optional[NutritionData]:
        """Get detailed nutrition information for a specific food ID"""
        cache_key = f"food_{food_id}"
        
        # Check cache first
        if cache_key in self.cache:
            cached_data, timestamp = self.cache[cache_key]
            if datetime.now() - timestamp < self.cache_ttl:
                return cached_data
        
        try:
            result = await self._make_mcp_request("get_food", {
                "food_id": food_id
            })
            
            if not result:
                return None
            
            nutrition_data = self._parse_nutrition_data(result)
            
            # Cache the result
            if nutrition_data:
                self.cache[cache_key] = (nutrition_data, datetime.now())
            
            return nutrition_data
            
        except Exception as e:
            logger.error(f"Error getting food by ID: {e}")
            return None

    async def lookup_barcode(self, barcode: str) -> Optional[NutritionData]:
        """Look up food by barcode"""
        cache_key = f"barcode_{barcode}"
        
        # Check cache first
        if cache_key in self.cache:
            cached_data, timestamp = self.cache[cache_key]
            if datetime.now() - timestamp < self.cache_ttl:
                return cached_data
        
        try:
            result = await self._make_mcp_request("lookup_barcode", {
                "barcode": barcode
            })
            
            if not result:
                return None
            
            nutrition_data = self._parse_nutrition_data(result)
            
            # Cache the result
            if nutrition_data:
                self.cache[cache_key] = (nutrition_data, datetime.now())
            
            return nutrition_data
            
        except Exception as e:
            logger.error(f"Error looking up barcode: {e}")
            return None

    async def browse_foods(self, offset: int = 0, limit: int = 50) -> List[NutritionData]:
        """Browse foods with pagination"""
        try:
            result = await self._make_mcp_request("browse_foods", {
                "offset": offset,
                "limit": limit
            })
            
            if not result:
                return []
            
            foods = []
            for item in result.get("foods", []):
                nutrition_data = self._parse_nutrition_data(item)
                if nutrition_data:
                    foods.append(nutrition_data)
            
            return foods
            
        except Exception as e:
            logger.error(f"Error browsing foods: {e}")
            return []

    async def get_nutrition_for_food_name(self, food_name: str, amount_g: float = 100) -> Optional[Dict[str, float]]:
        """
        Get nutrition information for a food by name with specific amount
        This is the main method that the CalorieTool will use
        """
        try:
            # Search for the food
            search_results = await self.search_foods(food_name, limit=5)
            
            if not search_results:
                logger.info(f"No nutrition data found for: {food_name}")
                return None
            
            # Take the first (best) match
            best_match = search_results[0]
            
            # Calculate nutrition for the specified amount
            nutrition = best_match.get_nutrition_for_amount(amount_g)
            
            logger.info(f"Found nutrition data for {food_name}: {nutrition}")
            return nutrition
            
        except Exception as e:
            logger.error(f"Error getting nutrition for {food_name}: {e}")
            return None

    async def is_server_available(self) -> bool:
        """Check if the MCP server is available"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.mcp_server_url}/health",
                    timeout=aiohttp.ClientTimeout(total=5)
                ) as response:
                    return response.status == 200
        except:
            return False

    def clear_cache(self):
        """Clear the nutrition data cache"""
        self.cache.clear()
        logger.info("Nutrition data cache cleared")

# Global instance
_nutrition_service = None

def get_nutrition_service() -> MCPNutritionService:
    """Get the global nutrition service instance"""
    global _nutrition_service
    if _nutrition_service is None:
        _nutrition_service = MCPNutritionService()
    return _nutrition_service

# Fallback nutrition data for when MCP server is unavailable
FALLBACK_NUTRITION_DB = {
    "pizza": {"calories": 300, "protein": 12, "carbs": 36, "fat": 14},
    "pepperoni pizza": {"calories": 300, "protein": 12, "carbs": 36, "fat": 14},
    "banana": {"calories": 105, "protein": 1.3, "carbs": 27, "fat": 0.4},
    "apple": {"calories": 95, "protein": 0.5, "carbs": 25, "fat": 0.3},
    "chicken breast": {"calories": 165, "protein": 31, "carbs": 0, "fat": 3.6},
    "rice": {"calories": 200, "protein": 4, "carbs": 45, "fat": 0.5},
    "bread": {"calories": 80, "protein": 3, "carbs": 15, "fat": 1},
    "pasta": {"calories": 200, "protein": 7, "carbs": 40, "fat": 1.5},
    "burger": {"calories": 350, "protein": 20, "carbs": 30, "fat": 17},
    "soda": {"calories": 150, "protein": 0, "carbs": 39, "fat": 0},
    "coffee": {"calories": 5, "protein": 0, "carbs": 0, "fat": 0}
}

async def get_nutrition_with_fallback(food_name: str, amount_g: float = 100) -> Dict[str, float]:
    """
    Get nutrition data with fallback to local database if MCP server unavailable
    """
    nutrition_service = get_nutrition_service()
    
    # Try MCP server first
    if await nutrition_service.is_server_available():
        nutrition = await nutrition_service.get_nutrition_for_food_name(food_name, amount_g)
        if nutrition:
            return nutrition
    
    # Fallback to local database
    food_key = food_name.lower()
    if food_key in FALLBACK_NUTRITION_DB:
        fallback_data = FALLBACK_NUTRITION_DB[food_key]
        multiplier = amount_g / 100.0
        return {
            "calories": fallback_data["calories"] * multiplier,
            "protein": fallback_data["protein"] * multiplier,
            "carbs": fallback_data["carbs"] * multiplier,
            "fat": fallback_data["fat"] * multiplier
        }
    
    # Last resort: basic estimates
    return {
        "calories": 200 * (amount_g / 100.0),
        "protein": 10 * (amount_g / 100.0),
        "carbs": 25 * (amount_g / 100.0),
        "fat": 8 * (amount_g / 100.0)
    }