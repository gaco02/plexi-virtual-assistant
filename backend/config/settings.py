from pydantic_settings import BaseSettings
from functools import lru_cache
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Settings(BaseSettings):
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")
    FIREBASE_WEB_API_KEY: str = os.getenv("FIREBASE_WEB_API_KEY", "")
    FIREBASE_ADMIN_SDK_PATH: str = os.getenv("FIREBASE_ADMIN_SDK_PATH", "")
    DATABASE_URL: str = os.getenv("DATABASE_URL", "data/virtual_assistant.db")
    DB_USER: str = os.getenv("DB_USER", "postgres")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "postgres")
    DB_NAME: str = os.getenv("DB_NAME", "postgres")
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: int = int(os.getenv("DB_PORT", 5432))
    
    # MCP Nutrition Server Settings
    MCP_NUTRITION_SERVER_URL: str = os.getenv("MCP_NUTRITION_SERVER_URL", "http://localhost:3000")
    MCP_NUTRITION_ENABLED: bool = os.getenv("MCP_NUTRITION_ENABLED", "false").lower() == "true"

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings() -> Settings:
    return Settings()