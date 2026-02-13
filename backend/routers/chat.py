from fastapi import APIRouter, HTTPException, Depends
from models.chat import ChatRequest, ChatResponse, ChatMessage
from services.tools.budget_tool import BudgetTool
from services.tools.calorie_tool import CalorieTool
from services.db_service import VirtualAssistantDB
from openai import OpenAI
from routers.restaurants import recommend_restaurants
import json
from typing import List
from middleware.auth_middleware import verify_firebase_token, get_current_user
from services.chat_service import ChatService
from config.settings import get_settings
import logging
from datetime import datetime




router = APIRouter()

settings = get_settings()
client = OpenAI(api_key=settings.OPENAI_API_KEY)
chat_service = ChatService()
db_service = VirtualAssistantDB()
budget_tool = BudgetTool()

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def determine_intent(message: str, conversation_history: List[ChatMessage] = None) -> dict:
    """Determine intent considering conversation context"""
    try:
        messages = [
            {"role": "system", "content": """You will reply with a JSON object only. Possible tools: calories, budget, restaurant, conversation.
For calories queries, set "action" to "query" or "log". If "query", include:
  - "query_type": "consumption" when asking about calories you’ve eaten (e.g., "How many calories did I eat?").
  - "query_type": "nutrition" and a "food" field when asking about a food’s calories (e.g., "How many calories in a pizza?").
Examples:
  {"tool":"calories","action":"query","query_type":"consumption"}
  {"tool":"calories","action":"query","query_type":"nutrition","food":"pizza"}
  {"tool":"budget","action":"log"}
  {"tool":"conversation","action":"chat"}
Return ONLY the JSON."""}
        ]
        
        if conversation_history:
            # Convert conversation history to OpenAI message format
            messages.extend([
                {
                    "role": "user" if msg.is_user else "assistant",
                    "content": msg.content
                }
                for msg in conversation_history[-3:]
            ])
            
        messages.append({"role": "user", "content": message})
        
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            temperature=0
        )
        
        try:
            return json.loads(response.choices[0].message.content)
        except json.JSONDecodeError:
            # Default to conversation if can't parse response
            return {"tool": "conversation", "action": "chat"}
            
    except Exception as e:

        # Default to conversation instead of raising error
        return {"tool": "conversation", "action": "chat"}

async def handle_general_conversation(message: str, conversation_history: List[ChatMessage]) -> ChatResponse:
    """Handle general conversation when no specific tool is needed"""
    try:
        # Convert conversation history to OpenAI message format
        messages = [
            {"role": "system", "content": "You are a helpful and friendly assistant. Maintain a natural conversation while being ready to help with specific tasks when asked."}
        ]
        
        # Add conversation history with proper role mapping
        for msg in conversation_history[-5:]:
            messages.append({
                "role": "user" if msg.is_user else "assistant",
                "content": msg.content
            })
            
        messages.append({"role": "user", "content": message})
        
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            temperature=0.7
        )
        
        return ChatResponse(
            response=response.choices[0].message.content,
            success=True,
            conversation_context="conversation"
        )
    except Exception as e:

        return ChatResponse(
            response="I'm having trouble processing that right now.",
            success=False
        )

async def extract_multiple_intents(message: str) -> List[dict]:
    """Extract multiple intents from a single message"""
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": """Extract ALL relevant actions from the message.
                Return an array of JSON objects, each with tool and action:
                
                Rules for identifying intents:
                1. For budget logging: Look for specific amounts of money spent or saved
                2. For calorie logging: Look for specific food items with nutritional value
                3. Only extract calorie intent if a SPECIFIC food item is mentioned (e.g., "burger", "apple")
                4. Generic terms like "lunch", "dinner", "food" should NOT trigger calorie logging by themselves
                
                Examples:
                "I spent $10 on a burger" → [
                    {"tool": "budget", "action": "log", "details": {"amount": 10, "category": "dining"}},
                    {"tool": "calories", "action": "log", "details": {"food": "burger"}}
                ]
                
                "I spent $25 on lunch" → [
                    {"tool": "budget", "action": "log", "details": {"amount": 25, "category": "dining"}}
                ]
                
                "I ate a sandwich for lunch" → [
                    {"tool": "calories", "action": "log", "details": {"food": "sandwich"}}
                ]"""},
                {"role": "user", "content": message}
            ],
            temperature=0
        )
        return json.loads(response.choices[0].message.content)
    except Exception as e:

        return []

@router.post("/", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    current_user = Depends(get_current_user)
):
    try:
        # Debug logging for request
        logger.info(f"Chat request received: {request.dict()}")
        logger.info(f"Request local_time type: {type(request.local_time)}, value: {request.local_time}")




        # Save user message
        user_message = ChatMessage(
            user_id=current_user["id"],
            content=request.message,
            is_user=True,
            tool_used=request.tool,
            conversation_id=request.conversation_id
        )
        saved_user_message = await chat_service.save_message(user_message)

        # Get conversation history
        conversation_history = []
        if request.conversation_id:
            conversation_history = await chat_service.get_conversation(request.conversation_id)

        else:
            # Get recent messages for context
            conversation_history = await chat_service.get_messages(current_user["id"], limit=10)

        # Process the message and get response
        logger.info(f"Processing chat message with conversation history length: {len(conversation_history)}")
        
        # Convert string timestamp to datetime if it's a string
        if request.local_time and isinstance(request.local_time, str):
            logger.info(f"Converting string timestamp to datetime: {request.local_time}")
            try:
                request.local_time = datetime.fromisoformat(request.local_time)
                logger.info(f"Converted timestamp: {request.local_time}, type: {type(request.local_time)}")
            except ValueError as e:
                logger.error(f"Error converting timestamp: {e}")
                # If conversion fails, use current time
                request.local_time = datetime.now()
                logger.info(f"Using current time instead: {request.local_time}")
        
        response = await process_chat_message(request, conversation_history, current_user)


        # Save assistant response
        assistant_message = ChatMessage(
            user_id=current_user["id"],
            content=response.response,
            is_user=False,
            tool_used=response.conversation_context,  # Use conversation_context as tool_used
            tool_response={
                'expense_info': response.expense_info,
                'calorie_info': response.calorie_info,
                'restaurant_suggestions': response.restaurant_suggestions
            },
            conversation_id=request.conversation_id or saved_user_message.conversation_id
        )
        saved_assistant_message = await chat_service.save_message(assistant_message)

        # Add messages to response
        response.messages = [saved_user_message, saved_assistant_message]

        return response

    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")

        raise HTTPException(status_code=500, detail=str(e))

@router.get("/history/", response_model=List[ChatMessage])
async def get_chat_history(
    limit: int = 50,
    current_user = Depends(get_current_user)
):
    try:
        return await chat_service.get_messages(current_user["id"], limit=limit)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/history/")
async def clear_chat_history(
    current_user = Depends(get_current_user)
):
    try:
        success = await chat_service.clear_messages(current_user["id"])
        if success:
            return {"message": "Chat history cleared successfully"}
        raise HTTPException(status_code=500, detail="Failed to clear chat history")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def process_chat_message(request: ChatRequest, conversation_history: List[ChatMessage], current_user: dict) -> ChatResponse:
    try:
        logger.info(f"Processing chat message: {request.message}")
        logger.info(f"Request local_time in process_chat_message: {request.local_time}, type: {type(request.local_time)}")


        # Determine the intent of the message

        intent = await determine_intent(request.message, conversation_history)

        # Extract multiple intents if present

        multiple_intents = await extract_multiple_intents(request.message)

        if multiple_intents:

            # Handle multiple intents (e.g., logging both calories and budget)
            response = ChatResponse(
                response="I'll help you with that.",
                success=True,
                conversation_context="multiple_actions"
            )
            
            # Track which tools have been processed to avoid duplicates
            processed_tools = set()
            
            # Store individual tool responses to combine later
            tool_responses = []
            
            # Process each intent
            for intent_data in multiple_intents:

                tool = intent_data["tool"]
                
                # Skip if we've already processed this tool type
                if tool in processed_tools:

                    continue
                
                if tool == "calories":

                    calorie_tool = CalorieTool()
                    calorie_info = await calorie_tool.process_request(request)
                    response.calorie_info = calorie_info.calorie_info
                    tool_responses.append(calorie_info.response)

                    processed_tools.add("calories")
                elif tool == "budget":
                    logger.info(f"Processing budget tool with local_time: {request.local_time}, type: {type(request.local_time)}")
                    
                    request.user_id = current_user["id"]
                    budget_response = await budget_tool.process_request(request)
                    response.expense_info = budget_response.expense_info
                    tool_responses.append(budget_response.response)

                    processed_tools.add("budget")
                elif tool == "restaurant":

                    restaurant_info = await recommend_restaurants(request.message)
                    response.restaurant_suggestions = restaurant_info
                    tool_responses.append("Here are some restaurant suggestions.")

                    processed_tools.add("restaurant")
            
            # Combine all tool responses into a single response
            if tool_responses:
                response.response = " \n\n".join(tool_responses)
        else:

            # Handle single intent
            if intent["tool"] == "calories" and intent.get("action") == "query":
                # distinguish consumption vs nutrition lookup
                if intent.get("query_type") == "nutrition":
                    food = intent.get("food")
                    # use OpenAI client to look up nutrition facts
                    nutrition_resp = client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=[
                            {"role":"system","content":"You are a nutrition expert. Provide only a fact: how many calories are in one {food}."},
                            {"role":"user","content":f"How many calories are in one {food}?"}
                        ],
                        temperature=0
                    )
                    response = ChatResponse(
                        response=nutrition_resp.choices[0].message.content,
                        success=True,
                        conversation_context="calories"
                    )
                else:
                    # consumption summary
                    calorie_tool = CalorieTool()
                    calorie_response = await calorie_tool.process_request(request)
                    # Determine if user asked about today
                    msg_lower = request.message.lower()
                    # Override header if needed
                    if "today" in msg_lower:
                        # Replace any weekly header with today's header
                        response_text = calorie_response.response.replace(
                            "Weekly calories summary",
                            "Today's nutrition summary"
                        )
                    else:
                        response_text = calorie_response.response
                    response = ChatResponse(
                        response=response_text,
                        success=True,
                        conversation_context="calories",
                        calorie_info=calorie_response.calorie_info
                    )
            elif intent["tool"] == "calories" and intent.get("action") == "log":
                # existing logging logic
                calorie_tool = CalorieTool()
                calorie_response = await calorie_tool.process_request(request)
                response = ChatResponse(
                    response=calorie_response.response,
                    success=True,
                    conversation_context="calories",
                    calorie_info=calorie_response.calorie_info
                )

            elif intent["tool"] == "budget":
                logger.info(f"Processing budget intent with local_time: {request.local_time}, type: {type(request.local_time)}")
                
                request.user_id = current_user["id"]
                response = await budget_tool.process_request(request)

            elif intent["tool"] == "restaurant":

                restaurant_info = await recommend_restaurants(request.message)
                response = ChatResponse(
                    response="Here are some restaurant suggestions.",
                    success=True,
                    conversation_context="restaurant",
                    restaurant_suggestions=restaurant_info
                )

            else:
                # Handle general conversation

                response = await handle_general_conversation(request.message, conversation_history)


        return response

    except Exception as e:
        logger.error(f"Error in process_chat_message: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")

        return ChatResponse(
            response="I'm having trouble processing that right now. Could you please try again?",
            success=False
        )