# Consolidated: re-export from auth_middleware so all routers use the same implementation.
# This avoids duplicate auth logic and ensures the dev-mode bypass is gated behind ENVIRONMENT=development.
from middleware.auth_middleware import verify_firebase_token, get_current_user

__all__ = ["verify_firebase_token", "get_current_user"]
