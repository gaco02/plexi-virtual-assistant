from models.chat import ChatRequest, ChatResponse
from services.db_service import VirtualAssistantDB
from services.mcp_nutrition_service import get_nutrition_with_fallback, get_nutrition_service
from openai import OpenAI
import json
from datetime import datetime
import calendar
from models.calories import FoodMacros, CalorieSummary
import os
import logging
import re

from config.settings import get_settings
settings = get_settings()
client = OpenAI(api_key=settings.OPENAI_API_KEY)

class CalorieTool:
    def __init__(self):
        self.db = VirtualAssistantDB()
        # Define a function schema in case you want to use OpenAI's function calling
        self.functions = [
            {
                "name": "log_food",
                "description": "Log food item with calories and macronutrients",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "food_item": {
                            "type": "string",
                            "description": "The name of the food item"
                        },
                        "calories": {
                            "type": "integer",
                            "description": "Estimated calories"
                        },
                        "carbs": {
                            "type": "number",
                            "description": "Carbohydrates in grams"
                        },
                        "protein": {
                            "type": "number",
                            "description": "Protein in grams"
                        },
                        "fat": {
                            "type": "number",
                            "description": "Fat in grams"
                        },
                        "quantity": {
                            "type": "number",
                            "description": "Amount of food"
                        },
                        "unit": {
                            "type": "string",
                            "description": "Unit of measurement (e.g., pieces, grams, servings)"
                        }
                    },
                    "required": ["food_item", "calories"]
                }
            }
        ]
        
        # Common food macros database for fallback
        self.common_foods = {
            "pizza": {
                "calories": 300,
                "carbs": 36,
                "protein": 12,
                "fat": 14
            },
            "pepperoni pizza": {
                "calories": 300,
                "carbs": 36,
                "protein": 12,
                "fat": 14
            },
            "banana": {
                "calories": 105,
                "carbs": 27,
                "protein": 1.3,
                "fat": 0.4
            },
            "apple": {
                "calories": 95,
                "carbs": 25,
                "protein": 0.5,
                "fat": 0.3
            },
            "chicken breast": {
                "calories": 165,
                "carbs": 0,
                "protein": 31,
                "fat": 3.6
            },
            "rice": {
                "calories": 200,
                "carbs": 45,
                "protein": 4,
                "fat": 0.5
            },
            "bread": {
                "calories": 80,
                "carbs": 15,
                "protein": 3,
                "fat": 1
            },
            "pasta": {
                "calories": 200,
                "carbs": 40,
                "protein": 7,
                "fat": 1.5
            },
            "burger": {
                "calories": 350,
                "carbs": 30,
                "protein": 20,
                "fat": 17
            },
            "soda": {
                "calories": 150,
                "carbs": 39,
                "protein": 0,
                "fat": 0
            },
            "coffee": {
                "calories": 5,
                "carbs": 0,
                "protein": 0,
                "fat": 0
            }
        }
    
    async def get_food_macros(self, food_item: str, quantity: float = 1.0, unit: str = "serving"):
        """Get macros for a food item using MCP nutrition service with fallback"""
        try:
            # Estimate weight in grams based on quantity and unit
            estimated_grams = self._estimate_weight_in_grams(food_item, quantity, unit)
            
            # Get nutrition data from MCP service (with fallback)
            nutrition = await get_nutrition_with_fallback(food_item, estimated_grams)
            
            return {
                "food_item": food_item,
                "calories": int(nutrition["calories"]),
                "carbs": round(nutrition["carbs"], 1),
                "protein": round(nutrition["protein"], 1),
                "fat": round(nutrition["fat"], 1),
                "quantity": quantity,
                "unit": unit,
                "estimated_grams": estimated_grams
            }
        except Exception as e:
            logging.error(f"Error getting food macros for {food_item}: {e}")
            # Ultimate fallback
            return {
                "food_item": food_item,
                "calories": int(200 * quantity),
                "carbs": 25 * quantity,
                "protein": 10 * quantity,
                "fat": 8 * quantity,
                "quantity": quantity,
                "unit": unit
            }

    def _estimate_weight_in_grams(self, food_item: str, quantity: float, unit: str) -> float:
        """Estimate weight in grams based on food item, quantity, and unit"""
        food_item = food_item.lower()
        unit = unit.lower()
        
        # If already in grams, return as-is
        if unit in ["g", "gram", "grams"]:
            return quantity
            
        # Common serving size estimates in grams
        serving_sizes = {
            "pizza": 120,  # slice
            "banana": 120,
            "apple": 180,
            "chicken breast": 150,
            "rice": 150,  # cooked serving
            "bread": 30,  # slice
            "pasta": 85,  # dry serving becomes ~200g cooked
            "burger": 200,
            "soda": 355,  # can
            "coffee": 240  # cup
        }
        
        # Unit conversion multipliers
        unit_multipliers = {
            "slice": 1,
            "slices": 1,
            "piece": 1,
            "pieces": 1,
            "serving": 1,
            "servings": 1,
            "cup": 1,
            "cups": 1,
            "can": 1,
            "cans": 1,
            "bottle": 1,
            "bottles": 1,
            "ml": 1,  # Assume 1ml = 1g for liquids
            "milliliter": 1,
            "milliliters": 1,
            "oz": 28.35,  # fluid ounce to grams
            "ounce": 28.35,
            "ounces": 28.35,
            "lb": 453.6,  # pound to grams
            "pound": 453.6,
            "pounds": 453.6
        }
        
        # Find best match for food item
        base_weight = 100  # default
        for food, weight in serving_sizes.items():
            if food in food_item or food_item in food:
                base_weight = weight
                break
        
        # Apply unit multiplier
        multiplier = unit_multipliers.get(unit, 1)
        
        return base_weight * quantity * multiplier
    
    def is_query_request(self, message: str) -> bool:
        """
        Determine if the message is asking for calorie information
        rather than logging new food data.
        """
        query_patterns = [
            "how many", "total calories", "calorie count", 
            "did i consume", "calories today"
        ]
        return any(pattern in message.lower() for pattern in query_patterns)
    
    
    async def extract_food_actions(self, message):
        """
        Extract food logging actions from a message.
        
        Expected output format:
        [
            {
                "food_item": "banana",
                "calories": 105,
                "carbs": 27,
                "protein": 1.3,
                "fat": 0.4,
                "quantity": 1
            },
            ...
        ]
        """
        try:
            # Check if the message is empty or None
            if not message or message.strip() == "":
                return []
            
            # Create a prompt for the OpenAI API focused on food identification
            prompt = f"""
            Extract food items from the following message and identify their quantities and units:
            
            "{message}"
            
            For each food item mentioned, provide:
            1. Food item name (be specific, include preparation method if mentioned)
            2. Quantity (number)
            3. Unit of measurement
            
            Return a JSON array of objects with these fields:
            - food_item: The name of the food item (e.g., "grilled chicken breast", "medium apple", "slice of pepperoni pizza")
            - quantity: Amount of food (number, default 1)
            - unit: Unit of measurement (e.g., "serving", "piece", "slice", "cup", "grams", default "serving")
            
            Do NOT estimate calories or nutritional values - just identify the food items, quantities, and units.
            
            If multiple food items are part of the same meal, list them separately unless they form a single dish name.
            
            Examples:
            - "I ate 2 slices of pizza" → [{"food_item": "pizza", "quantity": 2, "unit": "slice"}]
            - "I had a banana and coffee" → [{"food_item": "banana", "quantity": 1, "unit": "piece"}, {"food_item": "coffee", "quantity": 1, "unit": "cup"}]
            - "I ate 150g of chicken breast" → [{"food_item": "chicken breast", "quantity": 150, "unit": "grams"}]
            
            If no food items are mentioned, return an empty array.
            """
            
            # Call the OpenAI API
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant that extracts food logging information."},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object"}
            )
            
            content = response.choices[0].message.content.strip()
            logging.info(f"LM response: {content}")
            
            # Try to extract JSON from the response
            try:
                # Find JSON array in the response
                import re
                json_match = re.search(r'\[.*\]', content, re.DOTALL)
                if json_match:
                    json_str = json_match.group(0)
                    actions = json.loads(json_str)
                else:
                    # If no JSON array is found, try to parse the entire response as JSON
                    actions = json.loads(content)
            except json.JSONDecodeError:
                print("Failed to parse JSON from OpenAI response")
                actions = []
            
            # Validate and enhance actions with nutrition data from MCP
            validated_actions = []
            for action in actions:
                # Ensure all required fields are present
                if "food_item" not in action:
                    continue
                
                # Set default values for missing fields
                action.setdefault("quantity", 1)
                action.setdefault("unit", "serving")
                
                # Get nutrition data using MCP service
                try:
                    nutrition_data = await self.get_food_macros(
                        action["food_item"],
                        action["quantity"],
                        action["unit"]
                    )
                    
                    # Merge nutrition data with action
                    action.update(nutrition_data)
                    validated_actions.append(action)
                    
                except Exception as e:
                    logging.error(f"Error getting nutrition for {action['food_item']}: {e}")
                    # Continue with the action even if nutrition lookup fails
                    validated_actions.append(action)
            
            return validated_actions
        except Exception as e:
            print(f"Error extracting food actions: {e}")
            return []
    
    async def handle_logging(self, request: ChatRequest):
        """Handle calorie logging"""
        try:
            responses = []
            total_calories = 0
            total_carbs = 0
            total_protein = 0
            total_fat = 0
            
            # Extract food actions from the message
            actions = await self.extract_food_actions(request.message)
            
            # If no actions were found, return an error message
            if not actions:
                return ChatResponse(
                    response="I couldn't identify any food items in your message. Please try again with a clearer description.",
                    success=False
                )
            
            # Process each food action
            for action in actions:
                food_item = action.get("food_item", "")
                quantity = action.get("quantity", 1)
                unit = action.get("unit", "serving")
                
                # Special case for pizza (slice vs whole)
                if "pizza" in food_item.lower():
                    if "slice" in food_item.lower() or unit.lower() == "slice":
                        # Pizza slice
                        calories = action.get("calories", 0) / 8
                        carbs = action.get("carbs", 0) / 8
                        protein = action.get("protein", 0) / 8
                        fat = action.get("fat", 0) / 8
                        unit = "slice"
                    else:
                        # Whole pizza
                        calories = action.get("calories", 0)
                        carbs = action.get("carbs", 0)
                        protein = action.get("protein", 0)
                        fat = action.get("fat", 0)
                else:
                    # Normal case
                    calories = action.get("calories", 0)
                    carbs = action.get("carbs", 0)
                    protein = action.get("protein", 0)
                    fat = action.get("fat", 0)
                
                # If unit is grams or pieces, the calories/macros returned are already for the whole quantity
                if unit.lower() in ['grams', 'gram', 'g', 'piece', 'pieces']:
                    item_total_calories = int(calories)
                    item_total_carbs = round(carbs, 1)
                    item_total_protein = round(protein, 1)
                    item_total_fat = round(fat, 1)
                else:
                    item_total_calories = int(calories * quantity)
                    item_total_carbs = round(carbs * quantity, 1)
                    item_total_protein = round(protein * quantity, 1)
                    item_total_fat = round(fat * quantity, 1)
                
                timestamp = request.local_time if request.local_time else datetime.now().isoformat()
                print(f"Saving meal with timestamp: {timestamp}")

                await self.db.save_meal(
                    user_id=request.user_id,
                    food_info={
                        "food_item": food_item,
                        "calories": item_total_calories,
                        "carbs": item_total_carbs,
                        "protein": item_total_protein,
                        "fat": item_total_fat,
                        "quantity": quantity,
                        "unit": unit,
                        "timestamp": timestamp
                    }
                )
                
                # Format the response based on quantity and unit
                quantity_text = f"{quantity} {unit}" if quantity != 1 else f"1 {unit}"
                if unit == "serving" and quantity == 1:
                    quantity_text = ""  # Don't show "1 serving" for cleaner output
                
                # Create food description without prepending the unit to the food_item
                food_description = f"{food_item} ({quantity_text})" if quantity_text else food_item
                responses.append(f"{item_total_calories} calories ({item_total_carbs}g carbs, {item_total_protein}g protein, {item_total_fat}g fat) for {food_description}")
                
                total_calories += item_total_calories
                total_carbs += item_total_carbs
                total_protein += item_total_protein
                total_fat += item_total_fat

            return ChatResponse(
                response=f"Logged: {', '.join(responses)}. Total: {total_calories} calories ({total_carbs}g carbs, {total_protein}g protein, {total_fat}g fat)",
                success=True,
                calorie_info={
                    "actions_logged": len(responses),
                    "total_calories": total_calories,
                    "total_carbs": total_carbs,
                    "total_protein": total_protein,
                    "total_fat": total_fat
                }
            )
        except Exception as e:
            print(f"Error logging calories: {e}")
            return ChatResponse(
                response="Sorry, I couldn't log your calories. Please try again with a clearer description of what you ate.",
                success=False
            )
    
    def determine_query_scope(self, message: str) -> tuple[str, str | None]:
        """
        Determine query scope and specific month if applicable
        Returns (scope, month) where month is None for non-specific queries
        """
        message = message.lower()
        
        # Check for specific months
        months = {
            'january': '01', 'february': '02', 'march': '03', 'april': '04',
            'may': '05', 'june': '06', 'july': '07', 'august': '08',
            'september': '09', 'october': '10', 'november': '11', 'december': '12'
        }
        
        for month_name, month_num in months.items():
            if month_name in message:
                return 'specific_month', month_num
        
        # Check for other time periods
        if any(word in message for word in ["today", "now", "current"]):
            return 'daily', None
        elif any(word in message for word in ["week", "weekly", "7 days"]):
            return 'weekly', None
        elif any(word in message for word in ["year", "yearly", "this year"]):
            return 'yearly', None
        elif any(word in message for word in ["month", "monthly"]):
            return 'monthly', None
        
        return 'daily', None  # default

    async def handle_query(self, request: ChatRequest):
        """Handle calorie queries"""
        try:
            if not request.user_id:
                return ChatResponse(
                    response="No user ID provided",
                    success=True,
                    calorie_info={
                        "is_query_response": True,
                        "total_calories": 0, 
                        "total_carbs": 0,
                        "total_protein": 0,
                        "total_fat": 0,
                        "breakdown": []
                    }
                )

            scope, month = self.determine_query_scope(request.message)
            print(f"Query scope: {scope}, Month: {month}")
            print(f"User ID for query: {request.user_id}")

            summary = await self.db.get_calories_by_period(request.user_id, scope, month)
            print(f"{scope.capitalize()} calories summary: {summary}")

            # Format period text for response
            period_text = {
                'daily': "Today's",
                'weekly': "This week's",
                'monthly': "This month's",
                'yearly': "This year's",
                'specific_month': f"{list(calendar.month_name)[int(month)]}'s" if month else "This month's"
            }.get(scope, "Today's")

            if not summary or (summary.get("totalCalories", 0) == 0 and not summary.get("breakdown")):
                return ChatResponse(
                    response=f"You haven't logged any calories {period_text.lower()}.",
                    success=True,
                    calorie_info={
                        "is_query_response": True,
                        "total_calories": 0, 
                        "total_carbs": 0,
                        "total_protein": 0,
                        "total_fat": 0,
                        "breakdown": []
                    }
                )

            # Use the camelCase keys from the database response
            total_calories = summary.get("totalCalories", 0) or 0
            total_carbs = round(summary.get("totalCarbs", 0) or 0, 1)
            total_protein = round(summary.get("totalProtein", 0) or 0, 1)
            total_fat = round(summary.get("totalFat", 0) or 0, 1)
            
            # Calculate macro percentages
            total_macro_calories = (total_carbs * 4) + (total_protein * 4) + (total_fat * 9)
            if total_macro_calories > 0:
                carbs_percent = round((total_carbs * 4 / total_macro_calories) * 100)
                protein_percent = round((total_protein * 4 / total_macro_calories) * 100)
                fat_percent = round((total_fat * 9 / total_macro_calories) * 100)
            else:
                carbs_percent = protein_percent = fat_percent = 0

            # Format food item breakdown using the "breakdown" key
            item_details = []
            breakdown = summary.get("breakdown", [])
            if isinstance(breakdown, dict):
                # if breakdown is a dict, iterate its items
                for item, data in breakdown.items():
                    calories = data.get('calories', 0)
                    carbs = round(data.get('carbs', 0) or 0, 1)
                    protein = round(data.get('protein', 0) or 0, 1)
                    fat = round(data.get('fat', 0) or 0, 1)
                    item_details.append(f"{calories} cal from {item} ({carbs}g carbs, {protein}g protein, {fat}g fat)")
            elif isinstance(breakdown, list):
                # if breakdown is already a list, iterate through it
                for entry in breakdown:
                    food_item = entry.get("food_item", "")
                    calories = entry.get('calories', 0)
                    carbs = round(entry.get('carbs', 0) or 0, 1)
                    protein = round(entry.get('protein', 0) or 0, 1)
                    fat = round(entry.get('fat', 0) or 0, 1)
                    item_details.append(f"{calories} cal from {food_item} ({carbs}g carbs, {protein}g protein, {fat}g fat)")
            
            # Create a detailed response with macro breakdown
            response_text = f"{period_text} nutrition summary:\n"
            response_text += f"• Total: {total_calories} calories\n"
            response_text += f"• Carbs: {total_carbs}g ({carbs_percent}%)\n"
            response_text += f"• Protein: {total_protein}g ({protein_percent}%)\n"
            response_text += f"• Fat: {total_fat}g ({fat_percent}%)"
            
            if item_details:
                response_text += f"\n\nFood breakdown:\n"
                response_text += "\n".join([f"• {item}" for item in item_details])
            
            return ChatResponse(
                response=response_text,
                success=True,
                calorie_info={
                    "is_query_response": True,
                    "total_calories": total_calories,
                    "total_carbs": total_carbs,
                    "total_protein": total_protein,
                    "total_fat": total_fat,
                    "carbs_percent": carbs_percent,
                    "protein_percent": protein_percent,
                    "fat_percent": fat_percent,
                    "items": breakdown
                }
            )
        except Exception as e:
            print(f"Error querying calories: {e}")
            return ChatResponse(
                response="Sorry, I couldn't retrieve your calories.",
                success=False,
                calorie_info={
                    "is_query_response": True,
                    "total_calories": 0, 
                    "total_carbs": 0,
                    "total_protein": 0,
                    "total_fat": 0,
                    "breakdown": []
                }
            )
    
    async def process_request(self, request: ChatRequest):
        """
        Process incoming calorie tool requests.
        Routes the request to either the query handler or the logging handler.
        """
        if self.is_query_request(request.message):
            return await self.handle_query(request)
        else:
            return await self.handle_logging(request)