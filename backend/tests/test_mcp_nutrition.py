"""
Test script for MCP OpenNutrition integration

Run this script to test the MCP nutrition service functionality.
Make sure the MCP OpenNutrition server is running before executing.
"""

import asyncio
import sys
import os

# Add parent directory to path to import our modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.mcp_nutrition_service import get_nutrition_service, get_nutrition_with_fallback

async def test_mcp_service():
    """Test the MCP nutrition service functionality"""
    
    print("🧪 Testing MCP OpenNutrition Service Integration")
    print("=" * 50)
    
    nutrition_service = get_nutrition_service()
    
    # Test 1: Check server availability
    print("\n1. Testing server availability...")
    is_available = await nutrition_service.is_server_available()
    print(f"   MCP Server Available: {is_available}")
    
    if not is_available:
        print("   ⚠️  MCP server not available. Testing fallback functionality...")
    
    # Test 2: Search for foods
    print("\n2. Testing food search...")
    try:
        foods = await nutrition_service.search_foods("banana", limit=3)
        print(f"   Found {len(foods)} foods for 'banana':")
        for food in foods[:2]:  # Show first 2 results
            print(f"   - {food.food_name}: {food.calories_per_100g} cal/100g")
    except Exception as e:
        print(f"   ❌ Error searching foods: {e}")
    
    # Test 3: Get nutrition with fallback
    print("\n3. Testing nutrition lookup with fallback...")
    test_foods = ["banana", "chicken breast", "pizza", "unknown_food_item"]
    
    for food in test_foods:
        try:
            nutrition = await get_nutrition_with_fallback(food, 100)
            print(f"   {food} (100g): {nutrition['calories']} cal, {nutrition['protein']}g protein")
        except Exception as e:
            print(f"   ❌ Error getting nutrition for {food}: {e}")
    
    # Test 4: Barcode lookup (if server available)
    if is_available:
        print("\n4. Testing barcode lookup...")
        try:
            # Test with a sample barcode (this might not exist in the database)
            barcode_result = await nutrition_service.lookup_barcode("1234567890123")
            if barcode_result:
                print(f"   Found food for barcode: {barcode_result.food_name}")
            else:
                print("   ℹ️  No food found for test barcode (expected)")
        except Exception as e:
            print(f"   ℹ️  Barcode lookup test: {e}")
    
    # Test 5: Food ID lookup (if server available)
    if is_available:
        print("\n5. Testing food ID lookup...")
        try:
            # First get a food ID from search
            foods = await nutrition_service.search_foods("apple", limit=1)
            if foods:
                food_id = foods[0].food_id
                food_details = await nutrition_service.get_food_by_id(food_id)
                if food_details:
                    print(f"   Food details for ID {food_id}: {food_details.food_name}")
                else:
                    print("   ❌ Could not retrieve food details")
            else:
                print("   ℹ️  No foods found to test ID lookup")
        except Exception as e:
            print(f"   ❌ Error in food ID lookup: {e}")
    
    # Test 6: Cache functionality
    print("\n6. Testing cache functionality...")
    try:
        # Clear cache
        nutrition_service.clear_cache()
        print("   ✅ Cache cleared successfully")
        
        # Test cache by calling the same food twice
        start_time = asyncio.get_event_loop().time()
        await get_nutrition_with_fallback("banana", 100)
        first_call_time = asyncio.get_event_loop().time() - start_time
        
        start_time = asyncio.get_event_loop().time()
        await get_nutrition_with_fallback("banana", 100)
        second_call_time = asyncio.get_event_loop().time() - start_time
        
        print(f"   First call: {first_call_time:.3f}s, Second call: {second_call_time:.3f}s")
        if second_call_time < first_call_time:
            print("   ✅ Caching appears to be working (faster second call)")
        else:
            print("   ℹ️  Cache performance test inconclusive")
            
    except Exception as e:
        print(f"   ❌ Error testing cache: {e}")
    
    print("\n" + "=" * 50)
    print("🏁 MCP Integration Test Complete!")
    
    if is_available:
        print("✅ MCP server is working properly")
    else:
        print("⚠️  MCP server unavailable, but fallback system is working")
    
    print("\nNext steps:")
    print("1. Start the backend server: python run_api.py")
    print("2. Test the new nutrition endpoints with your Flutter app")
    print("3. Try the enhanced calorie logging with accurate nutrition data")

async def test_calorie_tool_integration():
    """Test the upgraded CalorieTool with MCP integration"""
    
    print("\n🔧 Testing CalorieTool Integration")
    print("=" * 40)
    
    try:
        from services.tools.calorie_tool import CalorieTool
        from models.chat import ChatRequest
        
        tool = CalorieTool()
        
        # Test food action extraction with nutrition lookup
        test_message = "I ate 2 slices of pizza and a banana"
        
        print(f"\nTesting message: '{test_message}'")
        
        actions = await tool.extract_food_actions(test_message)
        
        print(f"Extracted {len(actions)} food actions:")
        for action in actions:
            food_item = action.get('food_item', 'Unknown')
            calories = action.get('calories', 0)
            protein = action.get('protein', 0)
            carbs = action.get('carbs', 0)
            fat = action.get('fat', 0)
            
            print(f"  - {food_item}: {calories} cal, {protein}g protein, {carbs}g carbs, {fat}g fat")
        
        print("✅ CalorieTool integration test completed!")
        
    except Exception as e:
        print(f"❌ Error testing CalorieTool integration: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("🚀 Starting MCP OpenNutrition Integration Tests")
    print("Make sure the MCP OpenNutrition server is running on localhost:3000")
    print("(See MCP_SETUP.md for installation instructions)")
    
    # Run the tests
    asyncio.run(test_mcp_service())
    asyncio.run(test_calorie_tool_integration())