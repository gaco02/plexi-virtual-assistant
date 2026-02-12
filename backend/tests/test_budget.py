import asyncio
from services.tools.budget_tool import BudgetTool
from models.chat import ChatRequest, Message
import json

async def test_budget():
    budget_tool = BudgetTool()
    
    # Test messages
    test_messages = [
        "I spent $10 on a hamburger",
        "Paid $25 for taxi",
        "Bought movie tickets for $15"
    ]
    
    for message in test_messages:
        request = ChatRequest(
            message=message,
            conversation_history=[],
            tool="budget"
        )
        
        response = await budget_tool.handle_request(request)
        print(f"\nTest message: {message}")
        print("Response:", json.dumps(response, indent=2))

if __name__ == "__main__":
    asyncio.run(test_budget()) 