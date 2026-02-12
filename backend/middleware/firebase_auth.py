from fastapi import Request, HTTPException
from firebase_admin import auth
from functools import wraps

async def verify_firebase_token(request: Request):
    """Verify Firebase token from Authorization header"""
    try:
        # Get token from header
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="No valid token found")
        
        token = auth_header.split(' ')[1]
        # Verify token with Firebase
        decoded_token = auth.verify_id_token(token)
        # Add user_id to request state
        request.state.user_id = decoded_token['uid']
        return decoded_token
        
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid token") 