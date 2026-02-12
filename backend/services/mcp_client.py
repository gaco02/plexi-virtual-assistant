"""
Real MCP Client for OpenNutrition Integration

This module provides a direct interface to MCP servers using the official MCP Python SDK.
It communicates with MCP servers through stdio transport, just like Claude Desktop does.
"""

import asyncio
import json
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
import subprocess
import os
from pathlib import Path

logger = logging.getLogger(__name__)

@dataclass
class MCPFood:
    """Represents a food item from MCP OpenNutrition"""
    food_id: str
    name: str
    calories_per_100g: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: Optional[float] = None
    sugar_g: Optional[float] = None
    sodium_mg: Optional[float] = None
    brand: Optional[str] = None
    barcode: Optional[str] = None

class MCPNutritionClient:
    """Direct MCP client for OpenNutrition server"""
    
    def __init__(self, mcp_server_path: str = None):
        self.mcp_server_path = mcp_server_path or self._find_mcp_server()
        self.process = None
        self.request_id = 0
        
    def _find_mcp_server(self) -> str:
        """Find the MCP OpenNutrition server executable"""
        possible_paths = [
            os.path.expanduser("~/mcp-opennutrition/build/index.js"),
            os.path.expanduser("~/StudioProjects/mcp-opennutrition/build/index.js"),
            "/usr/local/bin/mcp-opennutrition",
            "./mcp-opennutrition/build/index.js"
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        # Default path - user will need to configure
        return os.path.expanduser("~/mcp-opennutrition/build/index.js")
    
    async def start(self):
        """Start the MCP server process"""
        if self.process is not None:
            return
        
        try:
            # Check if server file exists
            if not os.path.exists(self.mcp_server_path):
                raise FileNotFoundError(f"MCP server not found at {self.mcp_server_path}")
            
            # Start the MCP server process
            self.process = await asyncio.create_subprocess_exec(
                "node", self.mcp_server_path,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            # Initialize the MCP connection
            await self._send_initialize()
            
            logger.info(f"MCP OpenNutrition server started: {self.mcp_server_path}")
            
        except Exception as e:
            logger.error(f"Failed to start MCP server: {e}")
            self.process = None
            raise
    
    async def stop(self):
        """Stop the MCP server process"""
        if self.process is not None:
            self.process.terminate()
            await self.process.wait()
            self.process = None
    
    async def _send_initialize(self):
        """Send MCP initialization message"""
        init_message = {
            "jsonrpc": "2.0",
            "id": self._get_next_id(),
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "resources": {},
                    "tools": {}
                },
                "clientInfo": {
                    "name": "nutrition-backend",
                    "version": "1.0.0"
                }
            }
        }
        
        await self._send_message(init_message)
        response = await self._receive_message()
        
        if response.get("error"):
            raise Exception(f"MCP initialization failed: {response['error']}")
    
    def _get_next_id(self) -> int:
        """Get next request ID"""
        self.request_id += 1
        return self.request_id
    
    async def _send_message(self, message: Dict):
        """Send a message to the MCP server"""
        if self.process is None:
            raise RuntimeError("MCP server not started")
        
        message_str = json.dumps(message) + "\n"
        self.process.stdin.write(message_str.encode())
        await self.process.stdin.drain()
    
    async def _receive_message(self) -> Dict:
        """Receive a message from the MCP server"""
        if self.process is None:
            raise RuntimeError("MCP server not started")
        
        line = await self.process.stdout.readline()
        if not line:
            raise RuntimeError("MCP server closed connection")
        
        return json.loads(line.decode().strip())
    
    async def call_tool(self, tool_name: str, arguments: Dict) -> Dict:
        """Call a tool on the MCP server"""
        if self.process is None:
            await self.start()
        
        message = {
            "jsonrpc": "2.0",
            "id": self._get_next_id(),
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            }
        }
        
        await self._send_message(message)
        response = await self._receive_message()
        
        if response.get("error"):
            raise Exception(f"Tool call failed: {response['error']}")
        
        return response.get("result", {})
    
    async def search_foods(self, query: str, limit: int = 10) -> List[MCPFood]:
        """Search for foods using MCP OpenNutrition"""
        try:
            result = await self.call_tool("search_foods", {
                "query": query,
                "limit": limit
            })
            
            foods = []
            for food_data in result.get("foods", []):
                food = self._parse_food_data(food_data)
                if food:
                    foods.append(food)
            
            return foods
            
        except Exception as e:
            logger.error(f"Error searching foods: {e}")
            return []
    
    async def get_food_by_id(self, food_id: str) -> Optional[MCPFood]:
        """Get food details by ID"""
        try:
            result = await self.call_tool("get_food", {
                "food_id": food_id
            })
            
            return self._parse_food_data(result)
            
        except Exception as e:
            logger.error(f"Error getting food by ID: {e}")
            return None
    
    async def lookup_barcode(self, barcode: str) -> Optional[MCPFood]:
        """Look up food by barcode"""
        try:
            result = await self.call_tool("lookup_barcode", {
                "barcode": barcode
            })
            
            return self._parse_food_data(result)
            
        except Exception as e:
            logger.error(f"Error looking up barcode: {e}")
            return None
    
    def _parse_food_data(self, data: Dict) -> Optional[MCPFood]:
        """Parse food data from MCP response"""
        if not data:
            return None
        
        try:
            nutrition = data.get("nutrition", {})
            
            return MCPFood(
                food_id=str(data.get("id", "")),
                name=data.get("name", ""),
                calories_per_100g=float(nutrition.get("energy_kcal", 0)),
                protein_g=float(nutrition.get("protein", 0)),
                carbs_g=float(nutrition.get("carbohydrates", 0)),
                fat_g=float(nutrition.get("fat", 0)),
                fiber_g=float(nutrition.get("fiber", 0)) if nutrition.get("fiber") else None,
                sugar_g=float(nutrition.get("sugar", 0)) if nutrition.get("sugar") else None,
                sodium_mg=float(nutrition.get("sodium", 0)) if nutrition.get("sodium") else None,
                brand=data.get("brand"),
                barcode=data.get("barcode")
            )
        except (ValueError, KeyError, TypeError) as e:
            logger.error(f"Error parsing food data: {e}")
            return None

# Global MCP client instance
_mcp_client = None

async def get_mcp_client() -> MCPNutritionClient:
    """Get the global MCP client instance"""
    global _mcp_client
    if _mcp_client is None:
        _mcp_client = MCPNutritionClient()
    return _mcp_client

async def search_foods_mcp(query: str, limit: int = 10) -> List[MCPFood]:
    """Search foods using MCP client"""
    client = await get_mcp_client()
    return await client.search_foods(query, limit)

async def get_food_by_id_mcp(food_id: str) -> Optional[MCPFood]:
    """Get food by ID using MCP client"""
    client = await get_mcp_client()
    return await client.get_food_by_id(food_id)

async def lookup_barcode_mcp(barcode: str) -> Optional[MCPFood]:
    """Look up food by barcode using MCP client"""
    client = await get_mcp_client()
    return await client.lookup_barcode(barcode)

async def shutdown_mcp_client():
    """Shutdown the MCP client"""
    global _mcp_client
    if _mcp_client is not None:
        await _mcp_client.stop()
        _mcp_client = None