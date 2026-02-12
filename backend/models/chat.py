from pydantic import BaseModel, validator
from typing import List, Dict, Optional, Union, Any
from datetime import datetime

class ChatMessage(BaseModel):
    id: Optional[int] = None
    user_id: str
    content: str
    is_user: bool
    timestamp: Union[datetime, str] = datetime.now()
    tool_used: Optional[str] = None
    tool_response: Optional[Dict[str, Any]] = None
    conversation_id: Optional[str] = None
    
    # Validator to convert string timestamps to datetime objects
    @validator('timestamp', pre=True)
    def parse_timestamp(cls, value):
        if isinstance(value, str):
            try:
                return datetime.fromisoformat(value)
            except ValueError:
                # If we can't parse the timestamp, use current time
                return datetime.now()
        return value

class ChatRequest(BaseModel):
    message: str
    conversation_history: list = []
    tool: Optional[str] = None
    user_id: Optional[str] = None
    local_time: Union[datetime, str, None] = None
    timezone: Optional[str] = None
    conversation_id: Optional[str] = None
    
    # Validator to convert string timestamps to datetime objects
    @validator('local_time', pre=True)
    def parse_local_time(cls, value):
        if isinstance(value, str):
            try:
                return datetime.fromisoformat(value)
            except ValueError:
                # If we can't parse the timestamp, use current time
                return datetime.now()
        return value

class ChatResponse(BaseModel):
    response: str
    success: bool = True
    conversation_context: Optional[str] = None
    restaurant_suggestions: Optional[List[Dict]] = None
    expense_info: Optional[Dict] = None
    calorie_info: Optional[Dict] = None
    messages: Optional[List[ChatMessage]] = None

# Explicitly specify what should be exported
__all__ = ['ChatMessage', 'ChatRequest', 'ChatResponse']