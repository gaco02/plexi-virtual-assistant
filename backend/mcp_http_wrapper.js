/**
 * HTTP Wrapper for MCP OpenNutrition Server
 * 
 * This creates a simple HTTP server that wraps the MCP OpenNutrition functionality
 * to make it accessible via HTTP requests for our FastAPI backend.
 */

const express = require('express');
const cors = require('cors');
const path = require('path');

// You'll need to adjust this path to point to your MCP OpenNutrition installation
const MCP_OPENNUTRITION_PATH = process.env.MCP_OPENNUTRITION_PATH || '/Users/osvaldo/mcp-opennutrition';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Mock nutrition database for testing
// In a real implementation, this would interface with the actual MCP OpenNutrition database
const mockNutritionDB = {
  // Sample foods with nutrition data per 100g
  foods: [
    {
      id: "1",
      name: "Banana",
      nutrition: {
        energy_kcal: 105,
        protein: 1.3,
        carbohydrates: 27,
        fat: 0.4,
        fiber: 2.6,
        sugar: 14.4,
        sodium: 1
      },
      serving_size: 120,
      brand: null,
      barcode: null
    },
    {
      id: "2", 
      name: "Apple",
      nutrition: {
        energy_kcal: 95,
        protein: 0.5,
        carbohydrates: 25,
        fat: 0.3,
        fiber: 4.0,
        sugar: 19,
        sodium: 2
      },
      serving_size: 180,
      brand: null,
      barcode: null
    },
    {
      id: "3",
      name: "Chicken Breast",
      nutrition: {
        energy_kcal: 165,
        protein: 31,
        carbohydrates: 0,
        fat: 3.6,
        fiber: 0,
        sugar: 0,
        sodium: 74
      },
      serving_size: 150,
      brand: null,
      barcode: null
    },
    {
      id: "4",
      name: "Pizza",
      nutrition: {
        energy_kcal: 300,
        protein: 12,
        carbohydrates: 36,
        fat: 14,
        fiber: 2.3,
        sugar: 3.6,
        sodium: 598
      },
      serving_size: 120,
      brand: null,
      barcode: null
    },
    {
      id: "5",
      name: "Rice",
      nutrition: {
        energy_kcal: 200,
        protein: 4,
        carbohydrates: 45,
        fat: 0.5,
        fiber: 0.6,
        sugar: 0.1,
        sodium: 5
      },
      serving_size: 150,
      brand: null,
      barcode: null
    }
  ]
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    message: 'MCP OpenNutrition HTTP Wrapper is running',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'MCP OpenNutrition HTTP Wrapper',
    version: '1.0.0',
    endpoints: {
      health: 'GET /health',
      search: 'POST /mcp (method: search_foods)',
      barcode: 'POST /mcp (method: lookup_barcode)',
      get_food: 'POST /mcp (method: get_food)'
    }
  });
});

// Main MCP endpoint
app.post('/mcp', (req, res) => {
  const { method, params } = req.body;
  
  try {
    switch (method) {
      case 'search_foods':
        return handleSearchFoods(req, res, params);
      case 'lookup_barcode':
        return handleLookupBarcode(req, res, params);
      case 'get_food':
        return handleGetFood(req, res, params);
      case 'browse_foods':
        return handleBrowseFoods(req, res, params);
      default:
        return res.status(400).json({
          error: 'Unknown method',
          available_methods: ['search_foods', 'lookup_barcode', 'get_food', 'browse_foods']
        });
    }
  } catch (error) {
    console.error('Error handling MCP request:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

function handleSearchFoods(req, res, params) {
  const { query, limit = 10 } = params;
  
  if (!query) {
    return res.status(400).json({ error: 'Query parameter is required' });
  }
  
  // Search foods by name (case-insensitive)
  const results = mockNutritionDB.foods
    .filter(food => food.name.toLowerCase().includes(query.toLowerCase()))
    .slice(0, limit)
    .map(food => ({
      id: food.id,
      name: food.name,
      nutrition: food.nutrition,
      brand: food.brand,
      barcode: food.barcode,
      serving_size: food.serving_size
    }));
  
  res.json({
    result: {
      foods: results,
      total: results.length,
      query: query
    }
  });
}

function handleLookupBarcode(req, res, params) {
  const { barcode } = params;
  
  if (!barcode) {
    return res.status(400).json({ error: 'Barcode parameter is required' });
  }
  
  // Look up food by barcode
  const food = mockNutritionDB.foods.find(f => f.barcode === barcode);
  
  if (!food) {
    return res.json({ result: null });
  }
  
  res.json({
    result: {
      id: food.id,
      name: food.name,
      nutrition: food.nutrition,
      brand: food.brand,
      barcode: food.barcode,
      serving_size: food.serving_size
    }
  });
}

function handleGetFood(req, res, params) {
  const { food_id } = params;
  
  if (!food_id) {
    return res.status(400).json({ error: 'food_id parameter is required' });
  }
  
  // Get food by ID
  const food = mockNutritionDB.foods.find(f => f.id === food_id);
  
  if (!food) {
    return res.json({ result: null });
  }
  
  res.json({
    result: {
      id: food.id,
      name: food.name,
      nutrition: food.nutrition,
      brand: food.brand,
      barcode: food.barcode,
      serving_size: food.serving_size
    }
  });
}

function handleBrowseFoods(req, res, params) {
  const { offset = 0, limit = 50 } = params;
  
  const foods = mockNutritionDB.foods
    .slice(offset, offset + limit)
    .map(food => ({
      id: food.id,
      name: food.name,
      nutrition: food.nutrition,
      brand: food.brand,
      barcode: food.barcode,
      serving_size: food.serving_size
    }));
  
  res.json({
    result: {
      foods: foods,
      total: foods.length,
      offset: offset,
      limit: limit
    }
  });
}

// Start server
app.listen(PORT, () => {
  console.log(`🚀 MCP OpenNutrition HTTP Wrapper running on http://localhost:${PORT}`);
  console.log(`📊 Serving ${mockNutritionDB.foods.length} sample foods`);
  console.log(`🔍 Available endpoints:`);
  console.log(`   GET  /health - Health check`);
  console.log(`   POST /mcp - Main MCP endpoint`);
  console.log(`\n📖 Usage examples:`);
  console.log(`   curl -X POST http://localhost:${PORT}/mcp \\`);
  console.log(`     -H "Content-Type: application/json" \\`);
  console.log(`     -d '{"method": "search_foods", "params": {"query": "banana", "limit": 5}}'`);
  console.log(`\n⚠️  Note: This is a mock implementation. In production, integrate with actual MCP OpenNutrition database.`);
});

module.exports = app;