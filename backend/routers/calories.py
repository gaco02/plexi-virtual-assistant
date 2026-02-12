from fastapi import APIRouter, Depends, HTTPException, Query
import logging
from models.chat import ChatRequest
from models.calories import FoodMacros, CalorieSummary, CalorieEntry
from services.tools.calorie_tool import CalorieTool
from services.mcp_nutrition_service import get_nutrition_service, NutritionData
from middleware.firebase_auth import verify_firebase_token
from middleware.auth_middleware import get_current_user
from services.db_service import VirtualAssistantDB
from typing import List, Dict, Optional
from datetime import datetime
from pydantic import BaseModel

router = APIRouter()

def get_db():
    db = VirtualAssistantDB()
    try:
        yield db
    finally:
        pass

@router.post("/log")
async def log_calories(
    request: ChatRequest,
    token=Depends(verify_firebase_token)
):
    """Handle calorie logging requests"""
    request.user_id = token['uid']
    tool = CalorieTool()
    return await tool.handle_logging(request)

@router.post("/entries/add", response_model=Dict)
async def add_calorie_entry(
    entry: CalorieEntry,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Add a new calorie entry directly without using OpenAI processing.
    This is more efficient for direct food logging.
    """
    try:
        # Wrap the entire function in a try-except to catch all errors
        # Print the raw entry for debugging
        print(f"DEBUG: Received calorie entry: {entry}")
        print(f"DEBUG: Entry types - calories: {type(entry.calories)}, carbs: {type(entry.carbs)}, protein: {type(entry.protein)}, fat: {type(entry.fat)}, quantity: {type(entry.quantity)}")

        # Use the current timestamp if not provided
        timestamp = entry.timestamp or datetime.now().isoformat()
        
        # Check for recent duplicate entries to avoid duplicates
        # Get recent entries from the last minute
        recent_entries = await db.get_raw_calorie_entries(
            user_id=current_user["id"],
            period="daily"
        )
        
        # Parse timestamps to datetime objects for comparison
        # Handle different timestamp types for current_time
        if isinstance(timestamp, datetime):
            # Already a datetime object
            current_time = timestamp
            print(f"DEBUG: Current timestamp is already a datetime object: {current_time}")
        elif isinstance(timestamp, str):
            # Convert string to datetime
            current_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00') if timestamp.endswith('Z') else timestamp)
            print(f"DEBUG: Converted current string timestamp to datetime: {current_time}")
        else:
            # Unknown type, use current time
            current_time = datetime.now()
            print(f"DEBUG: Unknown current timestamp type: {type(timestamp)}, using current time: {current_time}")
        
        # Check if there's a similar entry recently added
        for recent_entry in recent_entries:
            try:
                # Parse the entry timestamp
                entry_timestamp = recent_entry["timestamp"]
                
                # Handle different timestamp types
                if isinstance(entry_timestamp, datetime):
                    # Already a datetime object
                    entry_time = entry_timestamp
                    print(f"DEBUG: Timestamp is already a datetime object: {entry_time}")
                elif isinstance(entry_timestamp, str):
                    # Convert string to datetime
                    entry_time = datetime.fromisoformat(
                        entry_timestamp.replace('Z', '+00:00') 
                        if entry_timestamp.endswith('Z') 
                        else entry_timestamp
                    )
                    print(f"DEBUG: Converted string timestamp to datetime: {entry_time}")
                else:
                    # Unknown type, skip this entry
                    print(f"DEBUG: Unknown timestamp type: {type(entry_timestamp)}, value: {entry_timestamp}")
                    continue
                
                # Calculate time difference in seconds
                time_diff = abs((current_time - entry_time).total_seconds())
                
                # Check if the entry is similar (same food item or similar name and calories)
                similar_food = (
                    entry.food_item.lower() == recent_entry["food_item"].lower() or
                    entry.food_item.lower() in recent_entry["food_item"].lower() or
                    recent_entry["food_item"].lower() in entry.food_item.lower()
                )
                
                similar_calories = (
                    abs(int(entry.calories) - int(recent_entry["calories"])) < 10
                    if recent_entry["calories"] is not None else False
                )
                
                # If the entry is similar and was added within the last 60 seconds, consider it a duplicate

                # Get updated daily summary
                daily_data = await db.get_calories_by_period(current_user["id"], 'daily')
                
                return {
                    "success": True,
                    "message": f"Entry for {entry.food_item} already exists",
                    "duplicate": True,
                    "total_calories": daily_data.get('totalCalories', 0),
                    "total_carbs": daily_data.get('totalCarbs', 0),
                    "total_protein": daily_data.get('totalProtein', 0),
                    "total_fat": daily_data.get('totalFat', 0),
                    "breakdown": daily_data.get('breakdown', [])
                }
            except (ValueError, TypeError) as e:
                # Skip entries with invalid timestamps

                continue
        
        # Clean up the food item name to avoid redundant unit information
        food_item = entry.food_item
        if entry.unit and entry.unit != "serving":
            # Remove the unit from the beginning of the food item if it's there
            if food_item.lower().startswith(entry.unit.lower()):
                food_item = food_item[len(entry.unit):].strip()
        
        # Convert values to appropriate types
        try:
            print(f"DEBUG: Starting type conversion for calorie entry")
            
            # Convert calories to integer
            calories = entry.calories
            print(f"DEBUG: Original calories: {calories} ({type(calories)})")
            if isinstance(calories, str):
                print(f"DEBUG: Converting calories from string: {calories}")
                calories = int(float(calories))
                print(f"DEBUG: Converted calories to int: {calories}")
            else:
                print(f"DEBUG: Converting calories from non-string: {calories}")
                calories = int(calories)
                print(f"DEBUG: Converted calories to int: {calories}")
                
            # Convert macros to float if they exist
            carbs = entry.carbs
            print(f"DEBUG: Original carbs: {carbs} ({type(carbs) if carbs is not None else 'None'})")
            if carbs is not None:
                if isinstance(carbs, str):
                    print(f"DEBUG: Converting carbs from string: {carbs}")
                    carbs = float(carbs) if carbs.strip() else None
                    print(f"DEBUG: Converted carbs to float: {carbs}")
                    
            protein = entry.protein
            print(f"DEBUG: Original protein: {protein} ({type(protein) if protein is not None else 'None'})")
            if protein is not None:
                if isinstance(protein, str):
                    print(f"DEBUG: Converting protein from string: {protein}")
                    protein = float(protein) if protein.strip() else None
                    print(f"DEBUG: Converted protein to float: {protein}")
                    
            fat = entry.fat
            print(f"DEBUG: Original fat: {fat} ({type(fat) if fat is not None else 'None'})")
            if fat is not None:
                if isinstance(fat, str):
                    print(f"DEBUG: Converting fat from string: {fat}")
                    fat = float(fat) if fat.strip() else None
                    print(f"DEBUG: Converted fat to float: {fat}")
                    
            # Convert quantity to float
            quantity = entry.quantity
            print(f"DEBUG: Original quantity: {quantity} ({type(quantity)})")
            if isinstance(quantity, str):
                print(f"DEBUG: Converting quantity from string: {quantity}")
                quantity = float(quantity) if quantity.strip() else 1.0
                print(f"DEBUG: Converted quantity to float: {quantity}")
            
            # Log the converted values
            logging.info(f"Converted values for calorie entry: calories={calories}, carbs={carbs}, protein={protein}, fat={fat}, quantity={quantity}")
            print(f"DEBUG: Final converted values - calories: {calories} ({type(calories)}), carbs: {carbs} ({type(carbs)}), protein: {protein} ({type(protein)}), fat: {fat} ({type(fat)}), quantity: {quantity} ({type(quantity)})")
                
        except (ValueError, TypeError) as e:
            logging.error(f"Error converting calorie entry values: {e}")
            raise HTTPException(
                status_code=400,
                detail=f"Invalid data format: {str(e)}"
            )
            
        # Save the entry to the database
        meal_id = await db.save_meal(
            user_id=current_user["id"],
            food_info={
                'food_item': food_item,
                'calories': calories,  # Send as integer
                'carbs': carbs,  # Send as float or None
                'protein': protein,  # Send as float or None
                'fat': fat,  # Send as float or None
                'quantity': quantity,  # Send as float
                'unit': entry.unit,
                'timestamp': timestamp
            }
        )
        
        if not meal_id:
            raise HTTPException(
                status_code=500,
                detail="Failed to save calorie entry"
            )
        
        # Get updated daily summary
        try:
            print(f"DEBUG: Getting daily summary after adding entry")
            daily_data = await db.get_calories_by_period(current_user["id"], 'daily')
            print(f"DEBUG: Received daily_data: {daily_data}")
            
            # Make sure daily_data is a dictionary
            if not isinstance(daily_data, dict):
                print(f"DEBUG: daily_data is not a dictionary: {type(daily_data)}")
                daily_data = {
                    'totalCalories': 0,
                    'totalCarbs': 0,
                    'totalProtein': 0,
                    'totalFat': 0,
                    'breakdown': []
                }
            
            return {
                "success": True,
                "message": f"Added {entry.calories} calories for {food_item}",
                "id": meal_id,  # Include the server-assigned ID
                "total_calories": daily_data.get('totalCalories', 0),
                "total_carbs": daily_data.get('totalCarbs', 0),
                "total_protein": daily_data.get('totalProtein', 0),
                "total_fat": daily_data.get('totalFat', 0),
                "breakdown": daily_data.get('breakdown', [])
            }
        except Exception as summary_error:
            print(f"DEBUG: Error getting daily summary: {summary_error}")
            # Return success without the summary data
            return {
                "success": True,
                "message": f"Added {entry.calories} calories for {food_item}",
                "id": meal_id,  # Include the server-assigned ID
                "total_calories": 0,
                "total_carbs": 0,
                "total_protein": 0,
                "total_fat": 0,
                "breakdown": []
            }
    except Exception as e:
        import traceback
        error_traceback = traceback.format_exc()
        print(f"DEBUG: FULL ERROR TRACEBACK: \n{error_traceback}")
        print(f"DEBUG: Error type: {type(e)}")
        print(f"DEBUG: Error message: {str(e)}")
        logging.error(f"Error adding calorie entry: {e}")
        logging.error(f"Error traceback: {error_traceback}")
        
        raise HTTPException(
            status_code=500,
            detail=f"Failed to add calorie entry: {str(e)}"
        )

@router.get("/entries", response_model=List[Dict])
async def get_calorie_entries(
    period: str = "daily",
    month: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Get calorie entries for a specific period directly from the database.
    This endpoint bypasses the OpenAI processing for efficiency.
    """
    try:
        # Validate period parameter
        valid_periods = ["daily", "weekly", "monthly", "yearly"]
        if period not in valid_periods:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid period. Must be one of: {', '.join(valid_periods)}"
            )
        
        # Get raw entries from database
        entries = await db.get_raw_calorie_entries(
            user_id=current_user["id"],
            period=period,
            month=month
        )
        
        return entries
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to get calorie entries: {str(e)}"
        )

@router.post("/entries", response_model=Dict)
async def post_calorie_entries(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Get calorie entries for a specific period directly from the database via POST.
    This endpoint allows the client to send parameters in the request body.
    """
    try:
        # Extract parameters from request body
        period = request.get("period", "daily")
        month = request.get("month")
        user_id = request.get("user_id", current_user["id"])
        
        # Validate period parameter
        valid_periods = ["daily", "weekly", "monthly", "yearly"]
        if period not in valid_periods:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid period. Must be one of: {', '.join(valid_periods)}"
            )
        
        # Get raw entries from database
        entries = await db.get_raw_calorie_entries(
            user_id=user_id,
            period=period,
            month=month
        )
        
        return {
            "success": True,
            "entries": entries
        }
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to get calorie entries: {str(e)}"
        )

@router.post("/entries/update", response_model=Dict)
async def update_calorie_entry(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Update an existing calorie entry.
    """
    try:
        # Extract parameters from request body
        entry_id = request.get("entry_id")
        food_item = request.get("food_item")
        calories = request.get("calories")
        protein = request.get("protein")
        carbs = request.get("carbs")
        fat = request.get("fat")
        quantity = request.get("quantity", 1.0)
        unit = request.get("unit", "serving")
        user_id = request.get("user_id", current_user["id"])
        
        # Log the request for debugging
        print(f"Update calorie entry request - entry_id: {entry_id}, user_id: {user_id}")
        print(f"Food details - item: {food_item}, calories: {calories}, carbs: {carbs}, protein: {protein}, fat: {fat}")
        
        # Validate required parameters
        if not entry_id:
            raise HTTPException(
                status_code=400,
                detail="entry_id is required"
            )
        
        if not food_item or calories is None:
            raise HTTPException(
                status_code=400,
                detail="food_item and calories are required"
            )
        
        # Clean up the food item name to avoid redundant unit information
        if unit and unit != "serving":
            # Remove the unit from the beginning of the food item if it's there
            if food_item.lower().startswith(unit.lower()):
                food_item = food_item[len(unit):].strip()
        
        try:
            # Update the entry in the database
            success = await db.update_calorie_entry(
                user_id=user_id,
                entry_id=entry_id,
                food_info={
                    'food_item': food_item,
                    'calories': calories,  # Pass as numeric value, not string
                    'carbs': carbs,  # Pass as numeric value, not string
                    'protein': protein,  # Pass as numeric value, not string
                    'fat': fat,  # Pass as numeric value, not string
                    'quantity': quantity,  # Pass as numeric value, not string
                    'unit': unit
                }
            )
            
            if not success:
                raise HTTPException(
                    status_code=404,  # Changed to 404 since it's likely the entry wasn't found
                    detail=f"Calorie entry with ID {entry_id} not found or could not be updated"
                )
            
            # Get updated daily summary
            daily_data = await db.get_calories_by_period(user_id, 'daily')
            
            return {
                "success": True,
                "message": f"Updated entry for {food_item}",
                "total_calories": daily_data.get('totalCalories', 0),
                "total_carbs": daily_data.get('totalCarbs', 0),
                "total_protein": daily_data.get('totalProtein', 0),
                "total_fat": daily_data.get('totalFat', 0),
                "breakdown": daily_data.get('breakdown', [])
            }
        except Exception as db_error:
            print(f"Database error while updating calorie entry: {str(db_error)}")
            raise HTTPException(
                status_code=500,
                detail=f"Database error: {str(db_error)}"
            )
    except HTTPException:
        # Re-raise HTTP exceptions as they already have the correct format
        raise
    except Exception as e:
        print(f"Unexpected error in update_calorie_entry: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update calorie entry: {str(e)}"
        )

@router.post("/entries/delete", response_model=Dict)
async def delete_calorie_entry(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Delete an existing calorie entry.
    """
    try:
        # Extract parameters from request body
        entry_id = request.get("entry_id")
        user_id = request.get("user_id", current_user["id"])
        
        # Log the request for debugging
        print(f"Delete calorie entry request - entry_id: {entry_id}, user_id: {user_id}")
        
        # Validate required parameters
        if not entry_id:
            raise HTTPException(
                status_code=400,
                detail="entry_id is required"
            )
        
        try:
            # Delete the entry from the database
            success = await db.delete_calorie_entry(
                user_id=user_id,
                entry_id=entry_id
            )
            
            if not success:
                raise HTTPException(
                    status_code=404,  # Changed to 404 since it's likely the entry wasn't found
                    detail=f"Calorie entry with ID {entry_id} not found or could not be deleted"
                )
            
            # Get updated daily summary
            daily_data = await db.get_calories_by_period(user_id, 'daily')
            
            return {
                "success": True,
                "message": "Entry deleted successfully",
                "total_calories": daily_data.get('totalCalories', 0),
                "total_carbs": daily_data.get('totalCarbs', 0),
                "total_protein": daily_data.get('totalProtein', 0),
                "total_fat": daily_data.get('totalFat', 0),
                "breakdown": daily_data.get('breakdown', [])
            }
        except Exception as db_error:
            print(f"Database error while deleting calorie entry: {str(db_error)}")
            raise HTTPException(
                status_code=500,
                detail=f"Database error: {str(db_error)}"
            )
    except HTTPException:
        # Re-raise HTTP exceptions as they already have the correct format
        raise
    except Exception as e:
        print(f"Unexpected error in delete_calorie_entry: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete calorie entry: {str(e)}"
        )

@router.post("/query")
async def query_calories(
    request: ChatRequest,
    token=Depends(verify_firebase_token)
):
    """Handle calorie queries"""
    request.user_id = token['uid']
    tool = CalorieTool()
    return await tool.handle_query(request)

@router.get("/summary")
async def get_summary(token=Depends(verify_firebase_token)):
    """Get calorie summary for the user"""
    user_id = token['uid']
    tool = CalorieTool()
    return await tool.handle_query(ChatRequest(message="summary", user_id=user_id))

@router.post("/summary")
async def post_summary(
    request: dict,
    token=Depends(verify_firebase_token),
    db = Depends(get_db)
):
    """Get calorie summary for the user via POST"""
    try:
        print(f"post_summary called with request: {request}")
        
        user_id = token['uid']
        # Override user_id if provided in request
        if request and 'user_id' in request:
            user_id = request['user_id']
            print(f"Using user_id from request: {user_id}")
        
        # Get period from request or default to daily
        period = 'daily'
        if request and 'period' in request:
            period = request['period']
            print(f"Using period from request: {period}")
        
        # Get month from request if provided
        month = None
        if request and 'month' in request:
            month = request['month']
            print(f"Using month from request: {month}")
        
        # Construct a more specific message if period is provided
        message = f"show me my {period} calories"
        if request and 'message' in request:
            message = request['message']
        
        print(f"Calling handle_query with message: {message}, user_id: {user_id}")
        
        # If we're just getting a summary directly, bypass the CalorieTool
        # and call the database directly for better performance
        if period in ['daily', 'weekly', 'monthly', 'yearly'] and not ('message' in request and request['message'] != 'summary'):
            print(f"Getting calorie summary directly from database for period: {period}")
            
            # Check if there are any entries for this user at all
            conn = await db.get_connection()
            try:
                # First check if the user has any entries at all
                any_entries = await conn.fetchval(
                    "SELECT COUNT(*) FROM meals WHERE user_id = $1", 
                    user_id
                )
                print(f"User has {any_entries} total calorie entries in database")
                
                if any_entries > 0:
                    # Get a sample entry to check timestamp format
                    sample = await conn.fetchrow(
                        "SELECT timestamp FROM meals WHERE user_id = $1 ORDER BY timestamp DESC LIMIT 1", 
                        user_id
                    )
                    if sample:
                        print(f"Sample timestamp format: {sample['timestamp']} (type: {type(sample['timestamp']).__name__})")
            finally:
                await conn.close()
            
            # Get summary for the requested period
            summary = await db.get_calories_by_period(user_id, period, month)
            print(f"Direct database summary: {summary}")
            
            # We should NOT fall back to monthly data if daily calories are zero
            # Users may not have logged anything for the day, which is perfectly valid
            
            return summary
        else:
            # Use the CalorieTool for more complex queries
            tool = CalorieTool()
            response = await tool.handle_query(ChatRequest(message=message, user_id=user_id))
            return response.calorie_info if response.calorie_info else {
                'totalCalories': 0,
                'totalCarbs': 0,
                'totalProtein': 0,
                'totalFat': 0,
                'breakdown': []
            }
    except Exception as e:
        print(f"Error in post_summary: {e}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return {
            'totalCalories': 0,
            'totalCarbs': 0,
            'totalProtein': 0,
            'totalFat': 0,
            'breakdown': []
        }

# ===== NEW MCP NUTRITION ENDPOINTS =====

class FoodSearchRequest(BaseModel):
    query: str
    limit: int = 10

class BarcodeRequest(BaseModel):
    barcode: str

class NutritionCalculationRequest(BaseModel):
    food_name: str
    amount_grams: float = 100

@router.post("/nutrition/search", response_model=List[Dict])
async def search_foods(
    request: FoodSearchRequest,
    current_user: dict = Depends(get_current_user)
):
    """Search for foods using MCP OpenNutrition database"""
    try:
        nutrition_service = get_nutrition_service()
        
        # Check if MCP server is available
        if not await nutrition_service.is_server_available():
            raise HTTPException(
                status_code=503,
                detail="Nutrition database service is currently unavailable"
            )
        
        # Search for foods
        foods = await nutrition_service.search_foods(request.query, request.limit)
        
        # Convert to API response format
        results = []
        for food in foods:
            results.append({
                "food_id": food.food_id,
                "food_name": food.food_name,
                "calories_per_100g": food.calories_per_100g,
                "protein_g": food.protein_g,
                "carbs_g": food.carbs_g,
                "fat_g": food.fat_g,
                "fiber_g": food.fiber_g,
                "sugar_g": food.sugar_g,
                "sodium_mg": food.sodium_mg,
                "brand": food.brand,
                "serving_size_g": food.serving_size_g
            })
        
        return results
        
    except Exception as e:
        logging.error(f"Error searching foods: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to search foods: {str(e)}"
        )

@router.post("/nutrition/barcode", response_model=Dict)
async def lookup_barcode(
    request: BarcodeRequest,
    current_user: dict = Depends(get_current_user)
):
    """Look up food by barcode using MCP OpenNutrition database"""
    try:
        nutrition_service = get_nutrition_service()
        
        # Check if MCP server is available
        if not await nutrition_service.is_server_available():
            raise HTTPException(
                status_code=503,
                detail="Nutrition database service is currently unavailable"
            )
        
        # Look up by barcode
        food = await nutrition_service.lookup_barcode(request.barcode)
        
        if not food:
            raise HTTPException(
                status_code=404,
                detail="Food not found for the provided barcode"
            )
        
        # Convert to API response format
        return {
            "food_id": food.food_id,
            "food_name": food.food_name,
            "calories_per_100g": food.calories_per_100g,
            "protein_g": food.protein_g,
            "carbs_g": food.carbs_g,
            "fat_g": food.fat_g,
            "fiber_g": food.fiber_g,
            "sugar_g": food.sugar_g,
            "sodium_mg": food.sodium_mg,
            "brand": food.brand,
            "barcode": food.barcode,
            "serving_size_g": food.serving_size_g
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error looking up barcode: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to lookup barcode: {str(e)}"
        )

@router.get("/nutrition/food/{food_id}", response_model=Dict)
async def get_food_details(
    food_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get detailed nutrition information for a specific food ID"""
    try:
        nutrition_service = get_nutrition_service()
        
        # Check if MCP server is available
        if not await nutrition_service.is_server_available():
            raise HTTPException(
                status_code=503,
                detail="Nutrition database service is currently unavailable"
            )
        
        # Get food details
        food = await nutrition_service.get_food_by_id(food_id)
        
        if not food:
            raise HTTPException(
                status_code=404,
                detail="Food not found"
            )
        
        # Convert to API response format
        return {
            "food_id": food.food_id,
            "food_name": food.food_name,
            "calories_per_100g": food.calories_per_100g,
            "protein_g": food.protein_g,
            "carbs_g": food.carbs_g,
            "fat_g": food.fat_g,
            "fiber_g": food.fiber_g,
            "sugar_g": food.sugar_g,
            "sodium_mg": food.sodium_mg,
            "brand": food.brand,
            "barcode": food.barcode,
            "serving_size_g": food.serving_size_g
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error getting food details: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get food details: {str(e)}"
        )

@router.post("/nutrition/calculate", response_model=Dict)
async def calculate_nutrition(
    request: NutritionCalculationRequest,
    current_user: dict = Depends(get_current_user)
):
    """Calculate nutrition values for a specific amount of food"""
    try:
        nutrition_service = get_nutrition_service()
        
        # Get nutrition data (with fallback)
        nutrition = await nutrition_service.get_nutrition_for_food_name(
            request.food_name, 
            request.amount_grams
        )
        
        if not nutrition:
            raise HTTPException(
                status_code=404,
                detail="Nutrition information not found for this food"
            )
        
        return {
            "food_name": request.food_name,
            "amount_grams": request.amount_grams,
            "nutrition": nutrition
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error calculating nutrition: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to calculate nutrition: {str(e)}"
        )

@router.get("/nutrition/server-status", response_model=Dict)
async def get_nutrition_server_status(
    current_user: dict = Depends(get_current_user)
):
    """Check if the MCP nutrition server is available"""
    try:
        nutrition_service = get_nutrition_service()
        is_available = await nutrition_service.is_server_available()
        
        return {
            "mcp_server_available": is_available,
            "server_url": nutrition_service.mcp_server_url,
            "fallback_enabled": True
        }
        
    except Exception as e:
        logging.error(f"Error checking server status: {e}")
        return {
            "mcp_server_available": False,
            "server_url": "unknown",
            "fallback_enabled": True,
            "error": str(e)
        }

@router.post("/nutrition/clear-cache", response_model=Dict)
async def clear_nutrition_cache(
    current_user: dict = Depends(get_current_user)
):
    """Clear the nutrition data cache"""
    try:
        nutrition_service = get_nutrition_service()
        nutrition_service.clear_cache()
        
        return {
            "success": True,
            "message": "Nutrition cache cleared successfully"
        }
        
    except Exception as e:
        logging.error(f"Error clearing cache: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to clear cache: {str(e)}"
        )
