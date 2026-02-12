#!/bin/bash

# Test script for MCP HTTP Wrapper
# Run this to verify the HTTP wrapper is working correctly

echo "🧪 Testing MCP HTTP Wrapper"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Health check
echo -e "\n${YELLOW}1. Testing health check...${NC}"
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:3000/health)
HTTP_CODE="${HEALTH_RESPONSE: -3}"
RESPONSE_BODY="${HEALTH_RESPONSE%???}"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "   Response: $RESPONSE_BODY"
else
    echo -e "${RED}❌ Health check failed (HTTP $HTTP_CODE)${NC}"
    echo "   Make sure the server is running: npm start"
    exit 1
fi

# Test 2: Search foods
echo -e "\n${YELLOW}2. Testing food search...${NC}"
SEARCH_RESPONSE=$(curl -s -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"method": "search_foods", "params": {"query": "banana", "limit": 3}}')

if echo "$SEARCH_RESPONSE" | grep -q "banana"; then
    echo -e "${GREEN}✅ Food search working${NC}"
    echo "   Found: $(echo "$SEARCH_RESPONSE" | grep -o '"name":"[^"]*"' | head -1)"
else
    echo -e "${RED}❌ Food search failed${NC}"
    echo "   Response: $SEARCH_RESPONSE"
fi

# Test 3: Get food by ID
echo -e "\n${YELLOW}3. Testing food lookup by ID...${NC}"
LOOKUP_RESPONSE=$(curl -s -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"method": "get_food", "params": {"food_id": "1"}}')

if echo "$LOOKUP_RESPONSE" | grep -q "Banana"; then
    echo -e "${GREEN}✅ Food lookup working${NC}"
    echo "   Found: $(echo "$LOOKUP_RESPONSE" | grep -o '"name":"[^"]*"')"
else
    echo -e "${RED}❌ Food lookup failed${NC}"
    echo "   Response: $LOOKUP_RESPONSE"
fi

# Test 4: Browse foods
echo -e "\n${YELLOW}4. Testing browse foods...${NC}"
BROWSE_RESPONSE=$(curl -s -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"method": "browse_foods", "params": {"offset": 0, "limit": 2}}')

if echo "$BROWSE_RESPONSE" | grep -q "foods"; then
    echo -e "${GREEN}✅ Browse foods working${NC}"
    FOOD_COUNT=$(echo "$BROWSE_RESPONSE" | grep -o '"name":"[^"]*"' | wc -l)
    echo "   Found $FOOD_COUNT foods"
else
    echo -e "${RED}❌ Browse foods failed${NC}"
    echo "   Response: $BROWSE_RESPONSE"
fi

# Test 5: Invalid method
echo -e "\n${YELLOW}5. Testing error handling...${NC}"
ERROR_RESPONSE=$(curl -s -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"method": "invalid_method", "params": {}}')

if echo "$ERROR_RESPONSE" | grep -q "Unknown method"; then
    echo -e "${GREEN}✅ Error handling working${NC}"
else
    echo -e "${RED}❌ Error handling failed${NC}"
    echo "   Response: $ERROR_RESPONSE"
fi

echo -e "\n${GREEN}🎉 HTTP Wrapper tests completed!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Start your FastAPI backend: python run_api.py"
echo "2. Test the Python integration: python tests/test_mcp_nutrition.py"
echo "3. Try the enhanced calorie tracking in your Flutter app"