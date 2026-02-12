from models.chat import ChatRequest, ChatResponse
from services.db_service import RestaurantDBService
from openai import OpenAI
import json
from datetime import datetime
import logging
import re
import random
from typing import List, Dict, Any
from config.settings import get_settings

settings = get_settings()
client = OpenAI(api_key=settings.OPENAI_API_KEY)


class RestaurantTool:
    def __init__(self, db_service: RestaurantDBService = None):
        # Use the provided db_service or create a new one if none is provided
        self.db = db_service or RestaurantDBService()
        
    def is_recommendation_request(self, message: str) -> bool:
        """
        Determine if the message is asking for restaurant recommendations
        """
        recommendation_patterns = [
            "recommend", "suggestion", "where to eat", "place to eat",
            "restaurant", "food place", "dining", "eat out", "where should i eat",
            "good place", "best place", "where can i get", "looking for food"
        ]
        return any(pattern in message.lower() for pattern in recommendation_patterns)
    
    def extract_cuisine_preference(self, message: str) -> str:
        """
        Extract cuisine preference from a message
        """
        try:
            prompt = (
                "Extract the cuisine type or food preference from the following message. "
                "Return ONLY the cuisine type as a single word or short phrase (e.g., 'Italian', 'Mexican', 'seafood', etc.). "
                "If no specific cuisine is mentioned, return 'any'.\n\n"
                f"Message: \"{message}\""
            )
            
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant that extracts cuisine preferences from messages."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=20
            )
            
            cuisine = response.choices[0].message.content.strip().lower()
            
            # Remove any quotes or punctuation
            cuisine = re.sub(r'["\'\.,;:]', '', cuisine)
            
            # If the response is too long or contains multiple words with "or", "and", etc., just use the first word
            if len(cuisine.split()) > 2 or any(word in cuisine for word in ["or", "and", "with", "also"]):
                cuisine = cuisine.split()[0]
            
            return cuisine if cuisine and cuisine != "any" else ""
            
        except Exception as e:
            logging.error(f"Error extracting cuisine preference: {e}")
            return ""
    
    async def get_daily_recommendations(self, count: int = 5) -> List[Dict[str, Any]]:
        """
        Get daily restaurant recommendations
        
        Uses the current date as a seed to ensure the same restaurants are recommended throughout the day
        """
        today = datetime.now().strftime("%Y-%m-%d")
        return await self.db.get_random_restaurants(count=count, seed=today)
    
    async def handle_recommendation(self, request: ChatRequest):
        """Handle restaurant recommendation requests"""
        try:
            # Extract cuisine preference from the message
            cuisine_preference = self.extract_cuisine_preference(request.message)
            
            # Get restaurants based on cuisine preference or random if no preference
            if cuisine_preference:
                restaurants = await self.db.get_restaurants_by_cuisine(cuisine_preference)
                # If no restaurants found for the specific cuisine, fall back to random
                if not restaurants:
                    restaurants = await self.get_daily_recommendations()
            else:
                restaurants = await self.get_daily_recommendations()
            
            if not restaurants:
                return ChatResponse(
                    response="I couldn't find any restaurants to recommend at the moment.",
                    success=False
                )
            
            # Prepare OpenAI prompt with restaurant information
            restaurant_context = "Available restaurants:\n"
            for i, rest in enumerate(restaurants[:5]):  # Limit to 5 restaurants for the prompt
                highlights = ", ".join(rest.get("highlights", [])[:3])  # Limit to 3 highlights
                restaurant_context += f"{i+1}. {rest['name']} - {rest['cuisine_type']} cuisine, {rest['price_level']} price, {rest['rating']} rating\n"
                restaurant_context += f"   Address: {rest['address']}\n"
                restaurant_context += f"   Highlights: {highlights}\n"
            
            # Create a personalized recommendation using OpenAI
            messages = [
                {"role": "system", "content": f"""You are a helpful restaurant recommender. 
                Based on the user's request, recommend restaurants from this list and explain why they might enjoy them:
                {restaurant_context}
                
                Format your response in a friendly, conversational way. Mention 2-3 restaurants from the list with brief descriptions.
                If the user mentioned a specific cuisine, emphasize restaurants of that type."""},
                {"role": "user", "content": request.message}
            ]
            
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                temperature=0.7,
                max_tokens=250
            )
            
            assistant_response = response.choices[0].message.content
            
            # Prepare restaurant suggestions for the response
            restaurant_suggestions = []
            for rest in restaurants[:5]:  # Limit to 5 restaurants
                restaurant_suggestions.append({
                    "id": rest.get("id"),
                    "name": rest.get("name"),
                    "cuisine_type": rest.get("cuisine_type"),
                    "price_level": rest.get("price_level"),
                    "rating": rest.get("rating"),
                    "address": rest.get("address"),
                    "highlights": rest.get("highlights", [])[:3],  # Limit to 3 highlights
                    "image_url": rest.get("image_url")
                })
            
            return ChatResponse(
                response=assistant_response,
                success=True,
                restaurant_info={
                    "recommendations": restaurant_suggestions,
                    "cuisine_preference": cuisine_preference
                }
            )
            
        except Exception as e:
            logging.error(f"Error handling restaurant recommendation: {e}")
            return ChatResponse(
                response="Sorry, I couldn't provide restaurant recommendations at the moment. Please try again later.",
                success=False
            )
    
    async def handle_query(self, request: ChatRequest):
        """Handle general restaurant queries"""
        try:
            # Check if it's a search query
            search_terms = re.findall(r'find|search|looking for|show me (.*?)(?:restaurant|place|food)', request.message.lower())
            
            if search_terms:
                search_term = search_terms[0].strip()
                restaurants = await self.db.search_restaurants(search_term)
            else:
                # Default to daily recommendations
                restaurants = await self.get_daily_recommendations()
            
            if not restaurants:
                return ChatResponse(
                    response="I couldn't find any restaurants matching your query.",
                    success=False
                )
            
            # Create a response with the restaurant information
            response_text = "Here are some restaurants you might like:\n\n"
            
            for i, rest in enumerate(restaurants[:5]):  # Limit to 5 restaurants
                response_text += f"{i+1}. {rest['name']} - {rest['cuisine_type']} cuisine\n"
                response_text += f"   Rating: {rest['rating']} stars, Price: {rest['price_level']}\n"
                response_text += f"   Address: {rest['address']}\n"
                
                if rest.get("highlights"):
                    highlights = ", ".join(rest.get("highlights", [])[:3])  # Limit to 3 highlights
                    response_text += f"   Known for: {highlights}\n"
                
                response_text += "\n"
            
            # Prepare restaurant suggestions for the response
            restaurant_suggestions = []
            for rest in restaurants[:5]:  # Limit to 5 restaurants
                restaurant_suggestions.append({
                    "id": rest.get("id"),
                    "name": rest.get("name"),
                    "cuisine_type": rest.get("cuisine_type"),
                    "price_level": rest.get("price_level"),
                    "rating": rest.get("rating"),
                    "address": rest.get("address"),
                    "highlights": rest.get("highlights", [])[:3],  # Limit to 3 highlights
                    "image_url": rest.get("image_url")
                })
            
            return ChatResponse(
                response=response_text,
                success=True,
                restaurant_info={
                    "recommendations": restaurant_suggestions
                }
            )
            
        except Exception as e:
            logging.error(f"Error handling restaurant query: {e}")
            return ChatResponse(
                response="Sorry, I couldn't process your restaurant query at the moment. Please try again later.",
                success=False
            )
    
    async def process_request(self, request: ChatRequest):
        """
        Process incoming restaurant tool requests.
        Routes the request to either the recommendation handler or the query handler.
        """
        if self.is_recommendation_request(request.message):
            return await self.handle_recommendation(request)
        else:
            return await self.handle_query(request)