import firebase_admin
from firebase_admin import credentials, auth
import requests
import sys
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_test_token():
    try:
        # Try to get default app first
        app = firebase_admin.get_app()
    except ValueError:
        # Initialize only if not already initialized
        cred = credentials.Certificate("config/firebase-credentials.json")
        app = firebase_admin.initialize_app(cred)
    
    # 1. Create custom token
    custom_token = auth.create_custom_token("test_user_id")
    
    # 2. Exchange custom token for ID token using API key from env
    response = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken",
        params={"key": os.getenv("FIREBASE_WEB_API_KEY")},
        json={"token": custom_token.decode(), "returnSecureToken": True}
    )
    
    id_token = response.json()["idToken"]
    print(f"\nID Token: {id_token}\n")
    return id_token

if __name__ == "__main__":
    try:
        token = get_test_token()
        sys.exit(0)  # Exit successfully
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)  # Exit with error 