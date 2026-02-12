from fastapi import APIRouter, Depends, HTTPException
from middleware.firebase_auth import verify_firebase_token
from models.user import UserCreate, User, UserPreferences
from datetime import datetime
from services.db_service import VirtualAssistantDB

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/register")
async def register_user(
    user_data: UserCreate,
    token=Depends(verify_firebase_token),
    db: VirtualAssistantDB = Depends()
):
    try:
        # Verify that the Firebase UID matches the token
        if user_data.firebase_uid != token['uid']:
            raise HTTPException(status_code=400, detail="Firebase UID mismatch")
            
        # Check if user already exists
        existing_user = await db.get_user_by_firebase_uid(user_data.firebase_uid)
        if (existing_user):
            return {
                "message": "User already registered",
                "user": existing_user
            }
            
        # Create user in the database
        user_id = await db.create_user(user_data)
        
        # Create a user object to return
        # Note: user_id is already converted to string in the db.create_user method
        new_user = User(
            id=user_data.firebase_uid,  # Use Firebase UID as user ID (as a string)
            email=user_data.email,
            name=user_data.name,
            firebase_uid=user_data.firebase_uid,
            created_at=datetime.utcnow()
        )
        
        print(f"DEBUG: Created new user with id={new_user.id} (type: {type(new_user.id)})")
        
        return {
            "message": "User registered successfully",
            "user": new_user
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/test-token")
async def test_token(token=Depends(verify_firebase_token)):
    return {
        "message": "Token valid",
        "user_id": token['uid']
    }

@router.post("/preferences")
async def update_preferences(
    preferences: UserPreferences,
    token=Depends(verify_firebase_token),
    db: VirtualAssistantDB = Depends()
):
    try:
        # Add detailed logging
        user_id = token['uid']
        print(f"DEBUG: Updating preferences for user_id: {user_id}")
        print(f"DEBUG: Preferences data: {preferences.dict()}")
        
        # Check if user exists in the database
        user = await db.get_user_by_firebase_uid(user_id)
        print(f"DEBUG: User exists in database: {user is not None}")
        
        if not user:
            # User not found by Firebase UID – check by email to avoid duplicates
            email = token.get('email')
            user_found = None
            if email:
                print(f"DEBUG: Looking up user by email: {email}")
                user_found = await db.get_user_by_email(email)
                print(f"DEBUG: User exists by email: {user_found is not None}")
            
            if user_found:
                # The user exists with a different Firebase UID - this happens when a user
                # signs in with Google or another provider but already had an account
                print(f"DEBUG: Found existing user with email {email}. Linking Firebase UIDs.")
                # Link the new Firebase UID to the existing user account
                updated_user = await db.link_firebase_uid_to_user(email, user_id)
                if updated_user:
                    print(f"DEBUG: Successfully linked Firebase UID {user_id} to existing user")
                    user = updated_user
                else:
                    print(f"DEBUG: Failed to link Firebase UIDs. Creating new user instead.")
                    # Fall back to creating a new user
                    from models.user import UserCreate
                    user_data = UserCreate(
                        firebase_uid=user_id,
                        email=email or f"{user_id}@example.com",
                        name=preferences.preferred_name or "User"
                    )
                    print(f"DEBUG: Creating user with data: {user_data.dict()}")
                    await db.create_user(user_data)
                    print(f"DEBUG: User {user_id} created successfully")
                    # Get the new user
                    user = await db.get_user_by_firebase_uid(user_id)
            else:
                print(f"DEBUG: Creating user {user_id} since no existing record")
                from models.user import UserCreate
                user_data = UserCreate(
                    firebase_uid=user_id,
                    email=email or f"{user_id}@example.com",
                    name=preferences.preferred_name or "User"
                )
                print(f"DEBUG: Creating user with data: {user_data.dict()}")
                await db.create_user(user_data)
                print(f"DEBUG: User {user_id} created successfully")
                # Get the new user
                user = await db.get_user_by_firebase_uid(user_id)
        
        # Now update the preferences
        print(f"DEBUG: Calling update_user_preferences for user {user_id}")
        try:
            # Try a direct approach first - use the numeric ID instead of firebase_uid
            if hasattr(user, 'id') and user.id:
                print(f"DEBUG: Trying to save preferences with numeric ID: {user.id}")
                # Try with the numeric ID first
                try:
                    # Use a direct SQL approach to bypass the ORM
                    conn = await db.get_connection()
                    try:
                        # Check if user_preferences table exists
                        table_exists = await conn.fetchval("""
                            SELECT EXISTS (
                                SELECT FROM information_schema.tables 
                                WHERE table_name = 'user_preferences'
                            )
                        """)
                        print(f"DEBUG: user_preferences table exists: {table_exists}")
                        
                        if not table_exists:
                            print("DEBUG: Creating user_preferences table")
                            await conn.execute('''
                                CREATE TABLE IF NOT EXISTS user_preferences (
                                    user_id TEXT PRIMARY KEY,
                                    monthly_salary REAL,
                                    weight_goal TEXT,
                                    current_weight REAL,
                                    target_weight REAL,
                                    daily_calorie_target INTEGER,
                                    preferred_name TEXT,
                                    height REAL,
                                    age INTEGER,
                                    sex TEXT,
                                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                                )
                            ''')
                        
                        # Insert or update with numeric ID
                        print(f"DEBUG: Inserting preferences with user_id={str(user.id)}")
                        result = await conn.execute('''
                            INSERT INTO user_preferences 
                            (user_id, monthly_salary, weight_goal, current_weight, 
                             target_weight, daily_calorie_target, preferred_name, height, age, sex, updated_at)
                            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, CURRENT_TIMESTAMP)
                            ON CONFLICT (user_id) 
                            DO UPDATE SET 
                                monthly_salary = $2,
                                weight_goal = $3,
                                current_weight = $4,
                                target_weight = $5,
                                daily_calorie_target = $6,
                                preferred_name = $7,
                                height = $8,
                                age = $9,
                                sex = $10,
                                updated_at = CURRENT_TIMESTAMP
                        ''', 
                            str(user.id),
                            preferences.monthly_salary,
                            preferences.weight_goal.value if preferences.weight_goal else None,
                            preferences.current_weight,
                            preferences.target_weight,
                            preferences.daily_calorie_target,
                            preferences.preferred_name,
                            preferences.height,
                            preferences.age,
                            preferences.sex
                        )
                        print(f"DEBUG: Direct SQL result: {result}")
                        return {"message": "Preferences updated successfully"}
                    finally:
                        await conn.close()
                except Exception as direct_error:
                    print(f"DEBUG: Error with direct SQL approach: {str(direct_error)}")
                    # Fall back to the regular method
            
            # If direct approach failed or wasn't attempted, try the regular method
            await db.update_user_preferences(user_id, preferences)
            print(f"DEBUG: Preferences updated successfully for user {user_id}")
            return {"message": "Preferences updated successfully"}
        except Exception as pref_error:
            import traceback
            print(f"DEBUG: Error updating preferences: {str(pref_error)}")
            print(f"DEBUG: Error traceback: {traceback.format_exc()}")
            raise HTTPException(status_code=500, detail=f"Failed to update preferences: {str(pref_error)}")
    except Exception as e:
        import traceback
        print(f"DEBUG: Unhandled exception in update_preferences: {str(e)}")
        print(f"DEBUG: Exception traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/preferences")
async def get_preferences(
    token=Depends(verify_firebase_token),
    db: VirtualAssistantDB = Depends()
):
    try:

        prefs = await db.get_user_preferences(token['uid'])
        
        if not prefs:

            default_prefs = {
                'monthly_salary': None,
                'weight_goal': None,
                'current_weight': None,
                'target_weight': None,
                'daily_calorie_target': None,
                'preferred_name': None,
            }

            return default_prefs

        return prefs
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to get preferences: {str(e)}"
        )