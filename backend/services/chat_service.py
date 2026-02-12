import json
from datetime import datetime
from typing import List, Optional
from models.chat import ChatMessage
from services.db_service import VirtualAssistantDB
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChatService:
    def __init__(self):
        self.db = VirtualAssistantDB()

    async def save_message(self, message: ChatMessage) -> ChatMessage:
        conn = await self.db.get_connection()
        try:
            # Log the message details for debugging
            logger.info(f"Saving message with timestamp: {message.timestamp}, type: {type(message.timestamp)}")
            
            # Handle timestamp conversion
            timestamp = None
            if message.timestamp is None:
                # Use current time if no timestamp provided
                timestamp = datetime.now()
                logger.info(f"Using current time: {timestamp}")
            elif isinstance(message.timestamp, str):
                # Convert string timestamp to datetime
                try:
                    timestamp = datetime.fromisoformat(message.timestamp)
                    logger.info(f"Converted string timestamp to datetime: {timestamp}")
                except ValueError as e:
                    logger.error(f"Error converting timestamp string: {e}")
                    # If conversion fails, use current time
                    timestamp = datetime.now()
                    logger.info(f"Falling back to current time: {timestamp}")
            else:
                # Assume it's already a datetime object
                timestamp = message.timestamp
                logger.info(f"Using provided datetime: {timestamp}")
            
            # Insert the message
            logger.info(f"Executing SQL with timestamp: {timestamp}, type: {type(timestamp)}")
            result = await conn.execute("""
                INSERT INTO chat_messages 
                (user_id, content, is_user, timestamp, tool_used, tool_response, conversation_id)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id
            """, 
                message.user_id,
                message.content,
                message.is_user,
                timestamp,  # Use the properly converted timestamp
                message.tool_used,
                json.dumps(message.tool_response) if message.tool_response else None,
                message.conversation_id
            )
            
            # Get the inserted message with its ID
            row = await conn.fetchrow("SELECT * FROM chat_messages WHERE id = (SELECT lastval())")
            logger.info(f"Message saved with ID: {row['id']}")
            return self._row_to_message(dict(row))
        except Exception as e:
            logger.error(f"Error in save_message: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            raise
        finally:
            await conn.close()

    async def get_messages(self, user_id: str, limit: int = 50) -> List[ChatMessage]:
        conn = await self.db.get_connection()
        try:
            rows = await conn.fetch("""
                SELECT * FROM chat_messages 
                WHERE user_id = $1 
                ORDER BY timestamp DESC 
                LIMIT $2
            """, user_id, limit)
            return [self._row_to_message(dict(row)) for row in rows]
        finally:
            await conn.close()

    async def get_conversation(self, conversation_id: str) -> List[ChatMessage]:
        conn = await self.db.get_connection()
        try:
            rows = await conn.fetch("""
                SELECT * FROM chat_messages 
                WHERE conversation_id = $1 
                ORDER BY timestamp ASC
            """, conversation_id)
            return [self._row_to_message(dict(row)) for row in rows]
        finally:
            await conn.close()

    async def clear_messages(self, user_id: str) -> bool:
        conn = await self.db.get_connection()
        try:
            await conn.execute("DELETE FROM chat_messages WHERE user_id = $1", user_id)
            return True
        finally:
            await conn.close()

    def _row_to_message(self, row: dict) -> ChatMessage:
        # Convert database row to ChatMessage object
        try:
            # Handle timestamp conversion safely
            if isinstance(row['timestamp'], str):
                timestamp = datetime.fromisoformat(row['timestamp'])
            else:
                timestamp = row['timestamp']
                
            # Handle tool_response parsing safely
            tool_response = None
            if row['tool_response']:
                try:
                    tool_response = json.loads(row['tool_response'])
                except json.JSONDecodeError:
                    logger.error(f"Failed to parse tool_response JSON: {row['tool_response']}")
            
            return ChatMessage(
                id=row['id'],
                user_id=row['user_id'],
                content=row['content'],
                is_user=row['is_user'],
                timestamp=timestamp,
                tool_used=row['tool_used'],
                tool_response=tool_response,
                conversation_id=row['conversation_id']
            )
        except Exception as e:
            logger.error(f"Error converting row to message: {e}, row: {row}")
            raise