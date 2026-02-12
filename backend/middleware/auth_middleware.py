from fastapi import Request, HTTPException, Depends
import firebase_admin
from firebase_admin import auth
import logging
from functools import wraps
from config.firebase_config import firebase_app

logger = logging.getLogger(__name__)

async def verify_firebase_token(request: Request):
    # Skip authentication if Firebase isn't initialized
    if firebase_app is None:
        # Create a mock user for development purposes
        mock_user = {"uid": "dev-user", "email": "dev@example.com"}
        request.state.user = mock_user
        return mock_user
        
    try:
        # Get the Authorization header
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            raise HTTPException(status_code=401, detail="No authorization header")

        # Extract the token
        scheme, token = auth_header.split()
        if scheme.lower() != 'bearer':
            raise HTTPException(status_code=401, detail="Invalid authentication scheme")

        # Verify the token
        try:
            decoded_token = auth.verify_id_token(token)
            # Add the token info to request state
            request.state.user = decoded_token
            return decoded_token
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))

async def get_current_user(token=Depends(verify_firebase_token)):
    try:
        # We're getting a decoded token, not the raw token
        return {
            "id": token["uid"],  # Change from decoded_token to token
            "email": token.get("email"),
            "name": token.get("name")
        }
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication credentials"
        ) 