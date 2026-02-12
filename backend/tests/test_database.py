import asyncio
from services.db_service import DBService
import json

async def test_database():
    print("Testing database setup and operations...")
    
    # Initialize database
    db = DBService()
    
    # Test meal
    test_meal = {
        "food_item": "Cheeseburger",
        "calories": 550,
        "quantity": 1,
        "unit": "piece"
    }
    
    try:
        # Save test meal
        meal_id = await db.save_meal("test_user", test_meal)
        print(f"\nSaved test meal with ID: {meal_id}")
        
        # Get summary
        summary = await db.get_calorie_summary("test_user")
        print("\nCalorie Summary:")
        print(json.dumps(summary, indent=2))
        
    except Exception as e:
        print(f"Error during test: {e}")

if __name__ == "__main__":
    print("Starting database test...")
    asyncio.run(test_database()) 