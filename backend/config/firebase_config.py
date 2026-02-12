from firebase_admin import credentials, initialize_app
import os
import json

# Initialize Firebase Admin SDK
firebase_app = None
try:
    print("DEBUG: Initializing Firebase Admin SDK...")
    
    # Priority 1: Use FIREBASE_CREDENTIALS environment variable (Secret Manager)
    firebase_creds_json = os.getenv("FIREBASE_CREDENTIALS")
    if firebase_creds_json:
        print("DEBUG: Found FIREBASE_CREDENTIALS environment variable")
        try:
            credentials_dict = json.loads(firebase_creds_json)
            cred = credentials.Certificate(credentials_dict)
            firebase_app = initialize_app(cred)
            print("✅ Firebase Admin SDK initialized successfully from Secret Manager")
        except json.JSONDecodeError as e:
            print(f"DEBUG: Failed to parse FIREBASE_CREDENTIALS JSON: {e}")
            raise
    else:
        # Priority 2: Fallback to file path (for local development)
        print("DEBUG: FIREBASE_CREDENTIALS not found, trying file path...")
        path = os.getenv("FIREBASE_ADMIN_SDK_PATH")
        print(f"DEBUG: FIREBASE_ADMIN_SDK_PATH = {path}")
        
        if path and os.path.exists(path):
            print(f"DEBUG: Firebase credentials file exists at {path}")
            cred = credentials.Certificate(path)
            firebase_app = initialize_app(cred)
            print("✅ Firebase Admin SDK initialized successfully from file")
        else:
            print("⚠️ No Firebase credentials found (neither secret nor file). Running without Firebase authentication.")
            
except Exception as e:
    print(f"❌ Firebase initialization failed with error: {e}")
    pass

