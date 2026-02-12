import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import asyncio
from models.chat import ChatRequest, Message
from services.tools.calorie_tool import CalorieTool
import json

async def test_calories():
    calorie_tool = CalorieTool()
    
    # Log a meal
    log_request = ChatRequest(
        message="I ate a hamburger",
        conversation_history=[],
        tool="calories"
    )
    response = await calorie_tool.handle_request(log_request)
    print("Logged meal:", json.dumps(response, indent=2))
    
    # Query calories
    query_request = ChatRequest(
        message="How many calories today?",
        conversation_history=[],
        tool="calories"
    )
    response = await calorie_tool.handle_query(query_request)
    print("\nQueried calories:", json.dumps(response, indent=2))

if __name__ == "__main__":
    asyncio.run(test_calories()) 