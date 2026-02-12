# MCP OpenNutrition Server Setup

This guide explains how to set up the MCP OpenNutrition server for enhanced nutrition data in the virtual assistant.

## Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- Git

## Installation Steps

### 1. Clone and Install MCP OpenNutrition

```bash
# Clone the MCP OpenNutrition repository
git clone https://github.com/deadletterq/mcp-opennutrition.git
cd mcp-opennutrition

# Install dependencies
npm install

# Build the project
npm run build
```

### 2. Build the MCP Server

```bash
# Build the project
npm run build
```

### 3. Important Note: MCP Server Architecture

The MCP OpenNutrition server is designed to run as an MCP server for Claude/Cline IDE integrations, not as a standalone HTTP server. However, we can create a simple HTTP wrapper to make it work with our FastAPI backend.

### 4. Use Our HTTP Wrapper (Recommended for Backend Integration)

Since the MCP server is designed for Claude/Cline IDE integration, we've created an HTTP wrapper that provides the same functionality via HTTP endpoints for our FastAPI backend.

**Option A: Use the HTTP Wrapper (Recommended)**

```bash
# In the TikTok-Analyzer directory
cd /Users/osvaldo/StudioProjects/TikTok-Analyzer

# Install Node.js dependencies
npm install

# Start the HTTP wrapper
npm start
```

**Option B: Future Integration with Real MCP OpenNutrition**

For production use, you would integrate directly with the MCP OpenNutrition database:

```bash
# In the mcp-opennutrition directory
cd /path/to/mcp-opennutrition
npm install
npm run build

# Then configure it as an MCP server (advanced setup)
```

### 5. Verify Installation

Test that the HTTP wrapper is running:

```bash
# Health check
curl http://localhost:3000/health

# Test search functionality
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "method": "search_foods",
    "params": {
      "query": "banana",
      "limit": 5
    }
  }'
```

## Configuration

### Environment Variables

Add to your `.env` file:

```bash
# MCP OpenNutrition Server
MCP_NUTRITION_SERVER_URL=http://localhost:3000
MCP_NUTRITION_ENABLED=true
```

### Backend Configuration

Update `config/settings.py` to include MCP settings:

```python
MCP_NUTRITION_SERVER_URL: str = os.getenv("MCP_NUTRITION_SERVER_URL", "http://localhost:3000")
MCP_NUTRITION_ENABLED: bool = os.getenv("MCP_NUTRITION_ENABLED", "false").lower() == "true"
```

## Usage in Development

1. **Start MCP Server**: Run the MCP OpenNutrition server first
2. **Start Backend**: Run your FastAPI backend
3. **Test Integration**: The CalorieTool will automatically use MCP for nutrition data

## Troubleshooting

### HTTP Wrapper Not Starting
- Check Node.js version: `node --version` (requires Node.js 16+)
- Ensure port 3000 is available: `lsof -i :3000`
- Install dependencies: `npm install`
- Check for errors in console output

### Connection Issues
- Verify server URL in settings
- Check firewall settings
- Test direct curl requests to server

### Data Issues
- Clear nutrition cache: Restart backend or call cache clear endpoint
- Check MCP server logs for parsing errors
- Verify food search queries return valid data

## Features Available

### Food Search
- Search by food name
- Partial matching
- Brand-specific foods
- Nutritional data per 100g

### Barcode Lookup
- EAN-13 barcode support
- Packaged food identification
- Brand and product details

### Detailed Nutrition
- Calories, macronutrients (protein, carbs, fat)
- Micronutrients (vitamins, minerals)
- Serving size information
- Multiple food databases (USDA, CNF, etc.)

## Performance Notes

- First request may be slower (database initialization)
- Subsequent requests are cached for 24 hours
- Local processing ensures data privacy
- No external API calls required after setup

## Development vs Production

### Development
- Run MCP server locally on localhost:3000
- Enable verbose logging for debugging
- Use development database

### Production
- Deploy MCP server to dedicated instance
- Configure proper networking and security
- Use production-optimized database
- Enable monitoring and health checks