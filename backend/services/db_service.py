import asyncpg
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import json
import time
import os
from models.user import User, UserCreate, UserPreferences
import calendar
import logging
from datetime import timedelta
import random


class RestaurantDBService:
    
    def __init__(self, db_name: str = "vancouver_restaurants"):
        self.db_name = db_name
        # We'll set up the database asynchronously later

    async def setup_database(self):
        """Initialize the database tables"""
        conn = await self.get_connection()
        try:
            # Create restaurants table with the correct schema
            await conn.execute('''
                CREATE TABLE IF NOT EXISTS restaurants (
                    id SERIAL PRIMARY KEY,
                    Name TEXT NOT NULL,
                    Address TEXT,
                    Website TEXT,
                    Description TEXT,
                    Type TEXT,
                    Cuisine TEXT,
                    Hours TEXT,
                    Price_Range TEXT
                )
            ''')
        finally:
            await conn.close()

    async def get_connection(self):
        """Get an asyncpg database connection for PostgreSQL"""
        db_host = os.getenv("DB_HOST", "127.0.0.1")

        if db_host.startswith("/cloudsql"):
            return await asyncpg.connect(
                user=os.getenv("DB_USER", "postgres"),
                password=os.getenv("DB_PASSWORD", "postgres"),
                database=os.getenv("DB_NAME", "postgres"),
                host=db_host  # Unix socket path
            )
        else:
            return await asyncpg.connect(
                user=os.getenv("DB_USER", "postgres"),
                password=os.getenv("DB_PASSWORD", "postgres"),
                database=os.getenv("DB_NAME", "postgres"),
                host=db_host,
                port=int(os.getenv("DB_PORT", 5432))
            )

    async def insert_or_update_restaurant(self, name, cuisine_type, price_level, highlights=None, image_url="", cuisine=None, address="", description="", rating=0, menu=None):
        """Insert or update a restaurant in the database"""
        try:
            conn = await self.get_connection()
            try:
                # First try to insert the restaurant
                result = await conn.execute('''
                    INSERT INTO restaurants 
                    (Name, Type, Price_Range, highlights_summary, image_url, Cuisine, Address, Description, rating, menu)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                    ON CONFLICT (Name) DO UPDATE SET
                    Type = $2,
                    Price_Range = $3,
                    highlights_summary = $4,
                    image_url = $5,
                    Cuisine = $6,
                    Address = $7,
                    Description = $8,
                    rating = $9,
                    menu = $10
                    RETURNING id
                ''', 
                    name,
                    cuisine_type,
                    price_level,
                    json.dumps(highlights) if highlights else '[]',
                    image_url,
                    json.dumps(cuisine) if cuisine else '[]',
                    address,
                    description,
                    rating,
                    json.dumps(menu) if menu else '[]'
                )
                
                # Get the ID of the inserted/updated restaurant
                restaurant_id = await conn.fetchval('SELECT lastval()')
                return restaurant_id
                
            finally:
                await conn.close()
                
        except Exception as e:
            raise e

    async def get_all_restaurants(self) -> List[Dict[str, Any]]:
        """Get all restaurants from the database"""
        conn = await self.get_connection()
        try:
            rows = await conn.fetch('''
                SELECT * FROM restaurants
                ORDER BY Name
            ''')
            
            restaurants = []
            for row in rows:
                restaurant = dict(row)
                # Map the columns to the expected format
                restaurant['name'] = restaurant['name']
                restaurant['cuisine_type'] = restaurant['type']
                restaurant['price_level'] = restaurant['price_range']
                restaurant['address'] = restaurant['address']
                restaurant['description'] = restaurant['description']
                # Safely parse JSON fields with fallbacks
                try:
                    restaurant['cuisine'] = json.loads(restaurant['cuisine']) if restaurant.get('cuisine') else []
                except (json.JSONDecodeError, TypeError):
                    restaurant['cuisine'] = []
                # Set defaults for missing fields
                restaurant['highlights'] = []
                restaurant['image_url'] = ""
                restaurant['rating'] = 0
                restaurant['menu'] = []
                restaurants.append(restaurant)
            
            return restaurants
        finally:
            await conn.close()
    
    async def get_restaurant_by_id(self, restaurant_id: int) -> Optional[Dict[str, Any]]:
        """Get a restaurant by its ID"""
        conn = await self.get_connection()
        try:
            row = await conn.fetchrow('''
                SELECT * FROM restaurants
                WHERE id = $1
            ''', restaurant_id)
            
            if not row:
                return None
            
            restaurant = dict(row)
            # Map the columns to the expected format
            restaurant['name'] = restaurant['name']
            restaurant['cuisine_type'] = restaurant['type']
            restaurant['price_level'] = restaurant['price_range']
            restaurant['address'] = restaurant['address']
            restaurant['description'] = restaurant['description']
            # Safely parse JSON fields with fallbacks
            try:
                restaurant['cuisine'] = json.loads(restaurant['cuisine']) if restaurant.get('cuisine') else []
            except (json.JSONDecodeError, TypeError):
                restaurant['cuisine'] = []
            # Set defaults for missing fields
            restaurant['highlights'] = []
            restaurant['image_url'] = ""
            restaurant['rating'] = 0
            restaurant['menu'] = []
            
            return restaurant
        finally:
            await conn.close()
    
    async def get_random_restaurants(self, count: int = 5, seed: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Get a random selection of restaurants
        
        Args:
            count: Number of restaurants to return
            seed: Optional seed for random selection (e.g., date string)
        
        Returns:
            List of restaurant dictionaries
        """
        conn = await self.get_connection()
        try:
            # Use the seed if provided
            if seed:
                # PostgreSQL doesn't have a direct way to seed RANDOM()
                # We'll use a different approach by using the seed in our application
                random.seed(seed)
            
            rows = await conn.fetch(f'''
                SELECT * FROM restaurants
                ORDER BY RANDOM()
                LIMIT {count}
            ''')
            
            restaurants = []
            for row in rows:
                restaurant = dict(row)
                # Map the columns to the expected format
                restaurant['name'] = restaurant['name']
                restaurant['cuisine_type'] = restaurant['type']
                restaurant['price_level'] = restaurant['price_range']
                restaurant['address'] = restaurant['address']
                restaurant['description'] = restaurant['description']
                # Safely parse JSON fields with fallbacks
                try:
                    restaurant['cuisine'] = json.loads(restaurant['cuisine']) if restaurant.get('cuisine') else []
                except (json.JSONDecodeError, TypeError):
                    restaurant['cuisine'] = []
                # Set defaults for missing fields
                restaurant['highlights'] = []
                restaurant['image_url'] = ""
                restaurant['rating'] = 0
                restaurant['menu'] = []
                restaurants.append(restaurant)
            
            return restaurants
        finally:
            await conn.close()
    
    async def search_restaurants(self, query: str) -> List[Dict[str, Any]]:
        """Search for restaurants by name, cuisine type, or description"""
        conn = await self.get_connection()
        try:
            search_term = f"%{query}%"
            rows = await conn.fetch('''
                SELECT * FROM restaurants
                WHERE Name ILIKE $1 OR Type ILIKE $2 OR Description ILIKE $3
                ORDER BY Name
            ''', search_term, search_term, search_term)
            
            restaurants = []
            for row in rows:
                restaurant = dict(row)
                # Map the columns to the expected format
                restaurant['name'] = restaurant['name']
                restaurant['cuisine_type'] = restaurant['type']
                restaurant['price_level'] = restaurant['price_range']
                restaurant['address'] = restaurant['address']
                restaurant['description'] = restaurant['description']
                # Safely parse JSON fields with fallbacks
                try:
                    restaurant['cuisine'] = json.loads(restaurant['cuisine']) if restaurant.get('cuisine') else []
                except (json.JSONDecodeError, TypeError):
                    restaurant['cuisine'] = []
                # Set defaults for missing fields
                restaurant['highlights'] = []
                restaurant['image_url'] = ""
                restaurant['rating'] = 0
                restaurant['menu'] = []
                restaurants.append(restaurant)
            
            return restaurants
        finally:
            await conn.close()
    
    async def get_restaurants_by_cuisine(self, cuisine_type: str) -> List[Dict[str, Any]]:
        """Get restaurants by cuisine type"""
        conn = await self.get_connection()
        try:
            rows = await conn.fetch('''
                SELECT * FROM restaurants
                WHERE Type ILIKE $1
                ORDER BY Name
            ''', f"%{cuisine_type}%")
            
            restaurants = []
            for row in rows:
                restaurant = dict(row)
                # Map the columns to the expected format
                restaurant['name'] = restaurant['name']
                restaurant['cuisine_type'] = restaurant['type']
                restaurant['price_level'] = restaurant['price_range']
                restaurant['address'] = restaurant['address']
                restaurant['description'] = restaurant['description']
                # Safely parse JSON fields with fallbacks
                try:
                    restaurant['cuisine'] = json.loads(restaurant['cuisine']) if restaurant.get('cuisine') else []
                except (json.JSONDecodeError, TypeError):
                    restaurant['cuisine'] = []
                # Set defaults for missing fields
                restaurant['highlights'] = []
                restaurant['image_url'] = ""
                restaurant['rating'] = 0
                restaurant['menu'] = []
                restaurants.append(restaurant)
            
            return restaurants
        finally:
            await conn.close()
    
    # Legacy methods for backward compatibility
    async def view_all_restaurants(self) -> List[Dict[str, Any]]:
        """Legacy method to get all restaurants"""
        return await self.get_all_restaurants()
    
    async def get_restaurant_details(self, restaurant_id: int) -> Optional[Dict[str, Any]]:
        """Legacy method to get restaurant details"""
        return await self.get_restaurant_by_id(restaurant_id)
    
    async def view_restaurants(self, count: int = 3) -> List[Dict[str, Any]]:
        """Legacy method to get random restaurants"""
        return await self.get_random_restaurants(count)

class VirtualAssistantDB:
    def __init__(self):
        pass


    async def get_connection(self):
        """Get an asyncpg database connection for PostgreSQL"""
        db_host = os.getenv("DB_HOST", "127.0.0.1")

        if db_host.startswith("/cloudsql"):
            return await asyncpg.connect(
                user=os.getenv("DB_USER", "postgres"),
                password=os.getenv("DB_PASSWORD", "postgres"),
                database=os.getenv("DB_NAME", "postgres"),
                host=db_host  # Unix socket path
            )
        else:
            return await asyncpg.connect(
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", "postgres"),
            database=os.getenv("DB_NAME", "postgres"),
            host=db_host,
            port=int(os.getenv("DB_PORT", 5432))
        )


    async def fetch_one(self, query: str, params: tuple = None):
        """Fetch a single row from the database"""
        try:
            conn = await self.get_connection()
            try:
                return await conn.fetchrow(query, *(params if params else ()))
            finally:
                await conn.close()
        except Exception as e:

            raise

    async def fetch_all(self, query: str, params: tuple = None):
        """Fetch all rows from the database"""
        try:
            conn = await self.get_connection()
            try:
                return await conn.fetch(query, *(params if params else ()))
            finally:
                await conn.close()
        except Exception as e:

            raise

    async def execute(self, query: str, params: tuple = None):
        """Execute a query and return the last row id"""
        try:
            conn = await self.get_connection()
            try:
                return await conn.execute(query, *(params if params else ()))
            finally:
                await conn.close()
        except Exception as e:

            raise

    async def store_budget_allocation(self, **allocation_data):
        """Store budget allocation data"""
        query = """
        INSERT INTO budget_allocations (
            user_id, month, monthly_salary, needs_budget, wants_budget, 
            savings_budget, needs_spent, wants_spent, savings_actual
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        """
        params = (
            allocation_data['user_id'],
            allocation_data['month'],
            allocation_data['monthly_salary'],
            allocation_data['needs_budget'],
            allocation_data['wants_budget'],
            allocation_data['savings_budget'],
            allocation_data['needs_spent'],
            allocation_data['wants_spent'],
            allocation_data['savings_actual']
        )
        await self.execute(query, params)

    async def store_budget_recommendation(self, **recommendation_data):
        """Store budget recommendation data"""
        query = """
        INSERT INTO budget_recommendations (
            user_id, month, category, recommendation_type, 
            message, suggested_action, potential_savings
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        """
        params = (
            recommendation_data['user_id'],
            recommendation_data['month'],
            recommendation_data['category'],
            recommendation_data['recommendation_type'],
            recommendation_data['message'],
            recommendation_data['suggested_action'],
            recommendation_data['potential_savings']
        )
        await self.execute(query, params)

    async def get_budget_analysis(self, user_id: str, month: str = None):
        """Get budget analysis for a user and month"""
        query = """
        SELECT * FROM budget_allocations 
        WHERE user_id = $1 AND month = $2
        ORDER BY created_at DESC LIMIT 1
        """
        return await self.fetch_one(query, (user_id, month))

    async def get_user_preferences(self, user_id: str):
        """Get all user preferences"""
        query = "SELECT * FROM user_preferences WHERE user_id = $1"
        result = await self.fetch_one(query, (user_id,))
        if result:
            return {
                "monthly_salary": result["monthly_salary"],
                "weight_goal": result["weight_goal"],
                "current_weight": result["current_weight"],
                "target_weight": result["target_weight"],
                "daily_calorie_target": result["daily_calorie_target"],
                "preferred_name": result["preferred_name"],
                "height": result["height"],
                "age": result["age"],
                "sex": result["sex"]
            }
        return None

    def close(self):
        """Close any open database connections"""
        if hasattr(self, 'connection'):
            self.connection.close()

    async def setup_database(self):
        """Initialize virtual assistant tables"""

        try:
            conn = await self.get_connection()
            try:
                # Create users table if it doesn't exist
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS users (
                        id SERIAL PRIMARY KEY,
                        email TEXT UNIQUE NOT NULL,
                        firebase_uid TEXT UNIQUE NOT NULL,
                        name TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Create user_preferences table if it doesn't exist
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
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
                
                # Create chat_messages table if it doesn't exist
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS chat_messages (
                        id SERIAL PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        content TEXT NOT NULL,
                        is_user BOOLEAN NOT NULL,
                        timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        tool_used TEXT,
                        tool_response TEXT,
                        conversation_id TEXT,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
                
                # Create transactions table if it doesn't exist
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS transactions (
                        id SERIAL PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        amount REAL NOT NULL,
                        category TEXT NOT NULL,
                        description TEXT,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
                
                # Create meals table if it doesn't exist
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS meals (
                        id SERIAL PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        food_item TEXT NOT NULL,
                        calories INTEGER NOT NULL,
                        carbs REAL,
                        protein REAL,
                        fat REAL,
                        quantity REAL DEFAULT 1.0,
                        unit TEXT DEFAULT 'serving',
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
                
                # Create budget_allocations table if it doesn't exist
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS budget_allocations (
                        id SERIAL PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        month TEXT NOT NULL,
                        monthly_salary REAL NOT NULL,
                        needs_budget REAL NOT NULL,
                        wants_budget REAL NOT NULL,
                        savings_budget REAL NOT NULL,
                        needs_spent REAL NOT NULL,
                        wants_spent REAL NOT NULL,
                        savings_actual REAL NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
                
                # Create budget_recommendations table if it doesn't exist
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS budget_recommendations (
                        id SERIAL PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        month TEXT NOT NULL,
                        category TEXT NOT NULL,
                        recommendation_type TEXT NOT NULL,
                        message TEXT NOT NULL,
                        suggested_action TEXT NOT NULL,
                        potential_savings REAL NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
                
                # Check if columns exist and add them if they don't
                # In PostgreSQL, we need to check information_schema.columns
                
                # Check if the carbs, protein, and fat columns exist in the meals table
                columns_result = await conn.fetch('''
                    SELECT column_name FROM information_schema.columns 
                    WHERE table_name = 'meals' AND column_name IN ('carbs', 'protein', 'fat')
                ''')
                
                existing_columns = [row['column_name'] for row in columns_result]
                
                if 'carbs' not in existing_columns:
                    await conn.execute("ALTER TABLE meals ADD COLUMN carbs REAL DEFAULT 0")

                if 'protein' not in existing_columns:
                    await conn.execute("ALTER TABLE meals ADD COLUMN protein REAL DEFAULT 0")

                if 'fat' not in existing_columns:
                    await conn.execute("ALTER TABLE meals ADD COLUMN fat REAL DEFAULT 0")

                # Check if the height, age, and sex columns exist in the user_preferences table
                columns_result = await conn.fetch('''
                    SELECT column_name FROM information_schema.columns 
                    WHERE table_name = 'user_preferences' AND column_name IN ('height', 'age', 'sex')
                ''')
                
                existing_columns = [row['column_name'] for row in columns_result]
                
                if 'height' not in existing_columns:
                    await conn.execute("ALTER TABLE user_preferences ADD COLUMN height REAL")

                if 'age' not in existing_columns:
                    await conn.execute("ALTER TABLE user_preferences ADD COLUMN age INTEGER")

                if 'sex' not in existing_columns:
                    await conn.execute("ALTER TABLE user_preferences ADD COLUMN sex TEXT")


            finally:
                await conn.close()
        except Exception as e:

            raise

    async def create_user(self, user_data: UserCreate) -> str:
        """Create a new user in our database"""
        try:
            print(f"DEBUG DB: Starting create_user for firebase_uid: {user_data.firebase_uid}")
            print(f"DEBUG DB: User data: email={user_data.email}, name={user_data.name}")
            
            # Check if user already exists
            existing_user = await self.get_user_by_firebase_uid(user_data.firebase_uid)
            if existing_user:
                print(f"DEBUG DB: User {user_data.firebase_uid} already exists, returning existing user")
                return existing_user.id
                
            conn = await self.get_connection()
            try:
                # Create the user
                print(f"DEBUG DB: Inserting new user into users table")
                user_id = await conn.fetchval('''
                    INSERT INTO users (firebase_uid, email, name, created_at)
                    VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
                    RETURNING id
                ''', user_data.firebase_uid, user_data.email, user_data.name)
                
                print(f"DEBUG DB: User created with ID: {user_id}")
                
                # Create default user preferences
                print(f"DEBUG DB: Creating default user preferences for user_id: {user_data.firebase_uid}")
                await conn.execute('''
                    INSERT INTO user_preferences 
                    (user_id, monthly_salary, preferred_name, created_at, updated_at)
                    VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ''', user_data.firebase_uid, 0.0, user_data.name)
                
                print(f"DEBUG DB: Default preferences created successfully")
                # Convert the numeric ID to a string to match the User model's expectation
                if isinstance(user_id, int):
                    print(f"DEBUG DB: Converting numeric ID {user_id} to string for return value")
                    user_id = str(user_id)
                return user_id
            finally:
                await conn.close()
        except Exception as e:
            print(f"DEBUG DB: Error in create_user: {str(e)}")
            raise

    async def get_user_by_firebase_uid(self, firebase_uid: str) -> Optional[User]:
        """Get user by Firebase UID"""
        try:
            print(f"DEBUG DB: Looking up user by firebase_uid: {firebase_uid}")
            conn = await self.get_connection()
            try:
                # Check if the users table exists
                table_exists = await conn.fetchval("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_name = 'users'
                    )
                """)
                print(f"DEBUG DB: Users table exists: {table_exists}")
                
                if not table_exists:
                    print("DEBUG DB: Users table does not exist! Database may not be properly set up.")
                    return None
                
                # Check the structure of the users table
                columns = await conn.fetch("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_name = 'users'
                """)
                print(f"DEBUG DB: Users table columns: {[dict(col) for col in columns]}")
                
                # Now try to fetch the user
                row = await conn.fetchrow('SELECT * FROM users WHERE firebase_uid = $1', firebase_uid)
                print(f"DEBUG DB: User lookup result: {row is not None}")
                
                if row:
                    user_dict = dict(row)
                    print(f"DEBUG DB: Found user: {user_dict}")
                    
                    # Convert the numeric ID to a string to match the User model's expectation
                    if 'id' in user_dict and isinstance(user_dict['id'], int):
                        print(f"DEBUG DB: Converting numeric ID {user_dict['id']} to string")
                        user_dict['id'] = str(user_dict['id'])
                    
                    # Create the User object with the modified dictionary
                    return User(**user_dict)
                else:
                    print(f"DEBUG DB: No user found with firebase_uid: {firebase_uid}")
                    return None
            finally:
                await conn.close()
        except Exception as e:

            raise

    async def fix_user_preferences_table(self):
        """Fix the user_preferences table to correctly reference the users table"""
        print("DEBUG DB: Attempting to fix user_preferences table")
        conn = await self.get_connection()
        try:
            # First, check the users table structure to understand what we're referencing
            users_columns = await conn.fetch("""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns 
                WHERE table_name = 'users'
                ORDER BY ordinal_position
            """)
            print(f"DEBUG DB: Users table structure: {[dict(col) for col in users_columns]}")
            
            # Check primary key of users table
            users_pk = await conn.fetch("""
                SELECT a.attname
                FROM pg_index i
                JOIN pg_attribute a ON a.attnum = ANY(i.indkey) AND a.attrelid = i.indrelid
                WHERE i.indrelid = 'users'::regclass AND i.indisprimary
            """)
            print(f"DEBUG DB: Users table primary key: {[dict(pk) for pk in users_pk]}")
            
            # First, check if we need to back up existing preferences
            table_exists = await conn.fetchval("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = 'user_preferences'
                )
            """)
            
            if table_exists:
                print("DEBUG DB: Backing up existing user preferences")
                # Check existing data in user_preferences
                existing_prefs = await conn.fetch("SELECT * FROM user_preferences LIMIT 5")
                print(f"DEBUG DB: Sample of existing preferences: {[dict(pref) for pref in existing_prefs]}")
                
                # Create a backup table
                await conn.execute("""
                    CREATE TABLE IF NOT EXISTS user_preferences_backup AS 
                    SELECT * FROM user_preferences
                """)
                
                # Drop the existing table with its constraints
                await conn.execute("DROP TABLE IF EXISTS user_preferences CASCADE")
                print("DEBUG DB: Dropped existing user_preferences table")
            
            # Create the table with the correct foreign key reference
            # The key insight from PostgreSQL migration is that we need to reference the correct column
            print("DEBUG DB: Creating user_preferences table with correct constraints")
            
            # Check if the primary key of users is 'id' or 'firebase_uid'
            # If it's 'id', we need to change our approach
            primary_key_is_id = any(pk['attname'] == 'id' for pk in users_pk) if users_pk else False
            
            if primary_key_is_id:
                print("DEBUG DB: Users table primary key is 'id', adjusting user_preferences to match")
                # Create table with reference to id instead of firebase_uid
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
                
                # Create a view to map between firebase_uid and user_id
                await conn.execute('''
                    CREATE OR REPLACE VIEW user_preferences_view AS
                    SELECT p.*, u.firebase_uid 
                    FROM user_preferences p
                    JOIN users u ON p.user_id = u.id::text
                ''')
            else:
                print("DEBUG DB: Creating standard user_preferences table with firebase_uid reference")
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
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(firebase_uid)
                    )
                ''')
            
            # Restore data from backup if it existed
            if table_exists:
                print("DEBUG DB: Restoring user preferences from backup")
                try:
                    await conn.execute("""
                        INSERT INTO user_preferences
                        SELECT * FROM user_preferences_backup
                        ON CONFLICT (user_id) DO NOTHING
                    """)
                    print("DEBUG DB: Successfully restored preferences from backup")
                except Exception as restore_error:
                    print(f"DEBUG DB: Error restoring preferences: {str(restore_error)}")
                    # If restoring fails, try to convert user_id to match the expected format
                    if primary_key_is_id:
                        print("DEBUG DB: Attempting to convert user_ids to match the users.id format")
                        try:
                            # Get mapping of firebase_uid to id
                            user_mapping = await conn.fetch("SELECT id, firebase_uid FROM users")
                            print(f"DEBUG DB: User mapping sample: {[dict(u) for u in user_mapping[:5]]}")
                            
                            # For each user in the mapping, try to update their preferences
                            for user in user_mapping:
                                try:
                                    old_prefs = await conn.fetchrow(
                                        "SELECT * FROM user_preferences_backup WHERE user_id = $1", 
                                        user['firebase_uid']
                                    )
                                    if old_prefs:
                                        print(f"DEBUG DB: Found preferences for {user['firebase_uid']}, converting to id {user['id']}")
                                        old_prefs_dict = dict(old_prefs)
                                        # Insert with the numeric ID instead
                                        await conn.execute('''
                                            INSERT INTO user_preferences 
                                            (user_id, monthly_salary, weight_goal, current_weight, 
                                            target_weight, daily_calorie_target, preferred_name, height, age, sex,
                                            created_at, updated_at)
                                            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                                            ON CONFLICT (user_id) DO NOTHING
                                        ''', 
                                            str(user['id']),
                                            old_prefs_dict.get('monthly_salary'),
                                            old_prefs_dict.get('weight_goal'),
                                            old_prefs_dict.get('current_weight'),
                                            old_prefs_dict.get('target_weight'),
                                            old_prefs_dict.get('daily_calorie_target'),
                                            old_prefs_dict.get('preferred_name'),
                                            old_prefs_dict.get('height'),
                                            old_prefs_dict.get('age'),
                                            old_prefs_dict.get('sex'),
                                            old_prefs_dict.get('created_at', 'CURRENT_TIMESTAMP'),
                                            old_prefs_dict.get('updated_at', 'CURRENT_TIMESTAMP')
                                        )
                                except Exception as user_error:
                                    print(f"DEBUG DB: Error converting preferences for user {user['firebase_uid']}: {str(user_error)}")
                        except Exception as mapping_error:
                            print(f"DEBUG DB: Error with user mapping: {str(mapping_error)}")
                
                # Drop the backup table
                await conn.execute("DROP TABLE IF EXISTS user_preferences_backup")
            
            print("DEBUG DB: User preferences table fixed successfully")
            return True
        except Exception as e:
            print(f"DEBUG DB: Error fixing user_preferences table: {str(e)}")
            raise
        finally:
            await conn.close()
    
    async def update_user_preferences(self, user_id: str, preferences: UserPreferences):
        """Update user preferences"""
        try:
            print(f"DEBUG DB: Starting update_user_preferences for user_id: {user_id}")
            # First check if user exists
            user = await self.get_user_by_firebase_uid(user_id)
            print(f"DEBUG DB: User exists check result: {user is not None}")
            
            if not user:
                print(f"DEBUG DB: User {user_id} not found in database!")
                # Check if the user exists in the users table directly
                conn = await self.get_connection()
                try:
                    user_exists = await conn.fetchval('SELECT COUNT(*) FROM users WHERE firebase_uid = $1', user_id)
                    print(f"DEBUG DB: Direct user check count: {user_exists}")
                finally:
                    await conn.close()
                    
                if not user_exists:
                    print(f"DEBUG DB: User {user_id} doesn't exist in users table, cannot update preferences")
                    raise Exception(f"User {user_id} not found in database")
            
            # Check user_preferences table structure
            conn = await self.get_connection()
            try:
                # Check if the user_preferences table exists
                table_exists = await conn.fetchval("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_name = 'user_preferences'
                    )
                """)
                print(f"DEBUG DB: user_preferences table exists: {table_exists}")
                
                # Check the structure of the user_preferences table
                columns = await conn.fetch("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_name = 'user_preferences'
                """)
                print(f"DEBUG DB: user_preferences table columns: {[dict(col) for col in columns]}")
                
                # Check foreign key constraint
                fk_constraint = await conn.fetch("""
                    SELECT conname, conrelid::regclass AS table_from, 
                           a.attname AS col, confrelid::regclass AS table_to, 
                           af.attname AS ref_col
                    FROM pg_constraint c
                    JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
                    JOIN pg_attribute af ON af.attnum = ANY(c.confkey) AND af.attrelid = c.confrelid
                    WHERE c.contype = 'f' AND c.conrelid = 'user_preferences'::regclass
                """)
                print(f"DEBUG DB: Foreign key constraints on user_preferences: {[dict(fk) for fk in fk_constraint]}")
                
                print(f"DEBUG DB: Executing update_user_preferences SQL for user_id: {user_id}")
                print(f"DEBUG DB: Preference values: monthly_salary={preferences.monthly_salary}, "
                      f"weight_goal={preferences.weight_goal.value if preferences.weight_goal else None}, "
                      f"current_weight={preferences.current_weight}, "
                      f"target_weight={preferences.target_weight}, "
                      f"daily_calorie_target={preferences.daily_calorie_target}, "
                      f"preferred_name={preferences.preferred_name}")
                
                try:
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
                        user_id,
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
                    print(f"DEBUG DB: SQL execution result: {result}")
                except Exception as sql_error:
                    print(f"DEBUG DB: SQL error: {str(sql_error)}")
                    print(f"DEBUG DB: SQL error TYPE: {type(sql_error)}")
                    print(f"DEBUG DB: SQL error DETAILS: {str(sql_error)}")
                    
                    # If there's a foreign key constraint error, try to fix it
                    if "violates foreign key constraint" in str(sql_error):
                        print(f"DEBUG DB: Foreign key constraint violation. Attempting to fix...")
                        
                        # Check if the error is specifically about user_id not being in users table
                        if "user_preferences_user_id_fkey" in str(sql_error):
                            print(f"DEBUG DB: The issue is with the user_preferences_user_id_fkey constraint")
                            
                            # Try to fix the specific issue - the user exists but the foreign key is failing
                            try:
                                # Get the user's actual ID from the database
                                user_row = await conn.fetchrow('SELECT id, firebase_uid FROM users WHERE firebase_uid = $1', user_id)
                                if user_row:
                                    print(f"DEBUG DB: Found user with ID: {user_row['id']} and firebase_uid: {user_row['firebase_uid']}")
                                    
                                    # Check if we need to use id instead of firebase_uid
                                    try:
                                        # Try inserting with the numeric ID instead
                                        print(f"DEBUG DB: Trying with numeric ID instead of firebase_uid")
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
                                            str(user_row['id']),  # Use the numeric ID as a string
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
                                        print(f"DEBUG DB: Success with numeric ID: {result}")
                                        return True
                                    except Exception as id_error:
                                        print(f"DEBUG DB: Error using numeric ID: {str(id_error)}")
                            except Exception as user_error:
                                print(f"DEBUG DB: Error getting user details: {str(user_error)}")
                        
                        # If specific fixes didn't work, try to recreate the user_preferences table
                        print(f"DEBUG DB: Attempting to fix the user_preferences table structure")
                        await self.fix_user_preferences_table()
                        # Try again with the fixed table
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
                            user_id,
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
                        print(f"DEBUG DB: Retry SQL execution result: {result}")
                    else:
                        raise
                print(f"DEBUG DB: SQL execution result: {result}")
                return True
            finally:
                await conn.close()
        except Exception as e:

            raise

    async def save_transaction(self, user_id: str, amount: float, category: str, description: str, timestamp = None):
        """Save a transaction with timestamp"""
        try:
            print(f"save_transaction called with timestamp: {timestamp}, type: {type(timestamp)}")

            # Handle timestamp conversion
            if timestamp is None:
                # Use current time if no timestamp provided
                ts = datetime.now()
                print(f"Using current time: {ts}")
            elif isinstance(timestamp, str):
                # Convert string timestamp to datetime
                try:
                    ts = datetime.fromisoformat(timestamp)
                    print(f"Converted string timestamp to datetime: {ts}")
                except ValueError as e:
                    print(f"Error converting timestamp string: {e}")
                    # If conversion fails, use current time
                    ts = datetime.now()
                    print(f"Falling back to current time: {ts}")
            else:
                # Assume it's already a datetime object
                ts = timestamp
                print(f"Using provided datetime: {ts}")
            
            conn = await self.get_connection()
            try:
                print(f"Executing SQL with timestamp: {ts}, type: {type(ts)}")
                transaction_id = await conn.fetchval('''
                    INSERT INTO transactions 
                    (user_id, amount, category, description, timestamp)
                    VALUES ($1, $2, $3, $4, $5)
                    RETURNING id
                ''', user_id, amount, category, description, ts)

                print(f"Transaction saved with ID: {transaction_id}")
                return transaction_id
            finally:
                await conn.close()
        except Exception as e:
            print(f"Error in save_transaction: {e}")
            import traceback
            print(f"Traceback: {traceback.format_exc()}")
            raise

    async def save_meal(self, user_id: str, food_info: dict):
        """Save a meal with its nutritional information"""
        try:
            logging.info(f"save_meal called with food_info: {food_info}")
            
            # Validate required fields
            if "food_item" not in food_info:
                logging.error("Missing food_item in food_info")
                raise ValueError("food_item is required")
                
            if "calories" not in food_info:
                logging.error("Missing calories in food_info")
                raise ValueError("calories is required")
            
            # Convert string values to appropriate types for PostgreSQL
            # Calories should be an integer
            try:
                calories = food_info["calories"]
                if calories is None:
                    calories = 0
                elif isinstance(calories, str):
                    calories = int(float(calories))  # Handle both "100" and "100.0" formats
                    logging.info(f"Converted calories from string to int: {calories}")
                elif isinstance(calories, float):
                    calories = int(calories)  # Convert float to int
                    logging.info(f"Converted calories from float to int: {calories}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting calories to int: {calories}, error: {e}")
                calories = 0
            
            # Macros should be floats or None
            try:
                carbs = food_info.get("carbs")
                if carbs is not None:
                    if isinstance(carbs, str):
                        carbs = float(carbs) if carbs.strip() else None
                        logging.info(f"Converted carbs from string to float: {carbs}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting carbs to float: {carbs}, error: {e}")
                carbs = None
            
            try:
                protein = food_info.get("protein")
                if protein is not None:
                    if isinstance(protein, str):
                        protein = float(protein) if protein.strip() else None
                        logging.info(f"Converted protein from string to float: {protein}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting protein to float: {protein}, error: {e}")
                protein = None
            
            try:
                fat = food_info.get("fat")
                if fat is not None:
                    if isinstance(fat, str):
                        fat = float(fat) if fat.strip() else None
                        logging.info(f"Converted fat from string to float: {fat}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting fat to float: {fat}, error: {e}")
                fat = None
            
            # Quantity should be a float
            try:
                quantity = food_info.get("quantity", 1.0)
                if quantity is None:
                    quantity = 1.0
                elif isinstance(quantity, str):
                    quantity = float(quantity) if quantity.strip() else 1.0
                    logging.info(f"Converted quantity from string to float: {quantity}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting quantity to float: {quantity}, error: {e}")
                quantity = 1.0
            
            # Handle unit
            unit = food_info.get("unit", "serving")
            if not unit or unit is None:
                unit = "serving"
            
            # Handle timestamp conversion
            try:
                timestamp = food_info.get("timestamp")
                
                # Fix: Check if timestamp is None first, then check if it's a string
                if timestamp is None:
                    timestamp = datetime.now()
                    logging.info("Using current time for timestamp")
                elif isinstance(timestamp, str):
                    # Try different timestamp formats
                    try:
                        # Try ISO format with Z
                        if 'Z' in timestamp:
                            timestamp = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        # Try ISO format without Z
                        else:
                            timestamp = datetime.fromisoformat(timestamp)
                        logging.info(f"Converted timestamp from ISO format: {timestamp}")
                    except ValueError:
                        # Try standard datetime format: YYYY-MM-DD HH:MM:SS
                        try:
                            timestamp = datetime.strptime(timestamp, "%Y-%m-%d %H:%M:%S")
                            logging.info(f"Converted timestamp from standard format: {timestamp}")
                        except ValueError:
                            logging.error(f"Error converting timestamp: {timestamp}")
                            timestamp = datetime.now()
                elif not isinstance(timestamp, datetime):
                    # If it's neither a string nor a datetime, use current time
                    logging.warning(f"Timestamp is not a string or datetime: {timestamp}, type: {type(timestamp)}")
                    timestamp = datetime.now()
            except Exception as e:
                logging.error(f"Error processing timestamp: {e}")
                timestamp = datetime.now()
            
            # Log all the processed values for debugging
            logging.info(f"Processed values - food_item: {food_info.get('food_item')}, calories: {calories}, "
                         f"carbs: {carbs}, protein: {protein}, fat: {fat}, quantity: {quantity}, "
                         f"unit: {unit}, timestamp: {timestamp}")
            
            # Print detailed debug information
            print(f"DEBUG: save_meal - Processed values with types:")
            print(f"DEBUG: food_item: {food_info.get('food_item')} ({type(food_info.get('food_item'))})") 
            print(f"DEBUG: calories: {calories} ({type(calories)})")
            print(f"DEBUG: carbs: {carbs} ({type(carbs)})")
            print(f"DEBUG: protein: {protein} ({type(protein)})")
            print(f"DEBUG: fat: {fat} ({type(fat)})")
            print(f"DEBUG: quantity: {quantity} ({type(quantity)})")
            print(f"DEBUG: unit: {unit} ({type(unit)})")
            print(f"DEBUG: timestamp: {timestamp} ({type(timestamp)})")
            
            conn = await self.get_connection()
            try:
                # Print the SQL query and parameters for debugging
                print(f"DEBUG: SQL Query: INSERT INTO meals (user_id, food_item, calories, carbs, protein, fat, quantity, unit, timestamp) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id")
                print(f"DEBUG: SQL Parameters:")
                print(f"DEBUG: $1 (user_id): {user_id} ({type(user_id)})")
                print(f"DEBUG: $2 (food_item): {food_info['food_item']} ({type(food_info['food_item'])})")
                print(f"DEBUG: $3 (calories): {calories} ({type(calories)})")
                print(f"DEBUG: $4 (carbs): {carbs} ({type(carbs)})")
                print(f"DEBUG: $5 (protein): {protein} ({type(protein)})")
                print(f"DEBUG: $6 (fat): {fat} ({type(fat)})")
                print(f"DEBUG: $7 (quantity): {quantity} ({type(quantity)})")
                print(f"DEBUG: $8 (unit): {unit} ({type(unit)})")
                print(f"DEBUG: $9 (timestamp): {timestamp} ({type(timestamp)})")
                
                try:
                    meal_id = await conn.fetchval('''
                        INSERT INTO meals 
                        (user_id, food_item, calories, carbs, protein, fat, quantity, unit, timestamp)
                        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                        RETURNING id
                    ''', 
                        user_id,
                        food_info["food_item"],
                        calories,
                        carbs,
                        protein,
                        fat,
                        quantity,
                        unit,
                        timestamp
                    )
                except Exception as sql_error:
                    print(f"DEBUG: SQL Execution Error: {sql_error}")
                    print(f"DEBUG: SQL Error Type: {type(sql_error)}")
                    raise

                logging.info(f"Meal saved with ID: {meal_id}")
                return meal_id
            except Exception as db_error:
                logging.error(f"Database error while saving meal: {db_error}")
                raise ValueError(f"Database error: {str(db_error)}")
            finally:
                await conn.close()
        except Exception as e:
            logging.error(f"Error in save_meal: {e}")
            import traceback
            logging.error(f"Traceback: {traceback.format_exc()}")
            raise

    async def save_chat_message(self, user_id: str, message: str, is_user: bool, conversation_id: str = None):
        """Save a chat message to the database"""
        try:
            conn = await self.get_connection()
            try:
                message_id = await conn.fetchval('''
                    INSERT INTO chat_messages 
                    (user_id, content, is_user, conversation_id, timestamp)
                    VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
                    RETURNING id
                ''', user_id, message, is_user, conversation_id)
                
                return message_id
            finally:
                await conn.close()
        except Exception as e:
            raise

    async def update_transaction(self, transaction_id: str, user_id: str, amount: float, category: str, description: str):
        """Update an existing transaction"""
        try:
            # Validate inputs
            if not transaction_id or not user_id:
                logging.error(f"Invalid parameters: transaction_id={transaction_id}, user_id={user_id}")
                raise ValueError("Both transaction_id and user_id are required")
                
            # Ensure amount is a float
            try:
                amount = float(amount)
            except (TypeError, ValueError) as e:
                logging.error(f"Error converting amount to float: {e}")
                raise ValueError(f"Invalid amount format: {amount}. Must be a number.")

            # Ensure user_id is a string
            user_id = str(user_id).strip()
            
            # Convert transaction_id to integer (since it's a SERIAL PRIMARY KEY in the database)
            try:
                # Remove any whitespace and convert to integer
                transaction_id_int = int(str(transaction_id).strip())
                logging.info(f"Converted transaction_id to integer: {transaction_id_int}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting transaction_id to integer: {e}")
                raise ValueError(f"Invalid transaction ID format: {transaction_id}. Must be a number.")
            
            logging.info(f"Updating transaction {transaction_id_int} for user {user_id} with amount {amount}, category {category}, description {description}")
            
            conn = await self.get_connection()
            try:
                # Execute the update query
                try:
                    result = await conn.execute('''
                        UPDATE transactions 
                        SET amount = $1, category = $2, description = $3
                        WHERE id = $4 AND user_id = $5
                    ''', amount, category, description, transaction_id_int, user_id)
                    
                    # Check if any rows were affected
                    if result == "UPDATE 0":
                        logging.warning(f"No transaction found with ID {transaction_id_int} for user {user_id}")
                        return False

                    logging.info(f"Successfully updated transaction {transaction_id_int}")
                    return True
                except Exception as db_error:
                    logging.error(f"Database error while updating transaction: {db_error}")
                    raise ValueError(f"Database error: {str(db_error)}")
            finally:
                await conn.close()
        except Exception as e:
            logging.error(f"Error updating transaction: {e}")
            raise

    async def delete_transaction(self, transaction_id: str, user_id: str):
        """Delete a transaction"""
        try:
            # Validate inputs
            if not transaction_id or not user_id:
                logging.error(f"Invalid parameters: transaction_id={transaction_id}, user_id={user_id}")
                raise ValueError("Both transaction_id and user_id are required")
            
            # Log the request
            logging.info(f"Deleting transaction {transaction_id} for user {user_id}")
            
            # Ensure user_id is a string
            user_id = str(user_id).strip()
            
            # Convert transaction_id to integer (since it's a SERIAL PRIMARY KEY in the database)
            try:
                # Remove any whitespace and convert to integer
                transaction_id_int = int(str(transaction_id).strip())
                logging.info(f"Converted transaction_id to integer: {transaction_id_int}")
            except (ValueError, TypeError) as e:
                logging.error(f"Error converting transaction_id to integer: {e}")
                raise ValueError(f"Invalid transaction ID format: {transaction_id}. Must be a number.")
            
            conn = await self.get_connection()
            try:
                # Execute the delete query
                try:
                    result = await conn.execute('''
                        DELETE FROM transactions 
                        WHERE id = $1 AND user_id = $2
                    ''', transaction_id_int, user_id)
                    
                    # Check if any rows were affected
                    if result == "DELETE 0":
                        logging.warning(f"No transaction found with ID {transaction_id_int} for user {user_id}")
                        return False

                    logging.info(f"Successfully deleted transaction {transaction_id_int}")
                    return True
                except Exception as db_error:
                    logging.error(f"Database error while deleting transaction: {db_error}")
                    raise ValueError(f"Database error: {str(db_error)}")
            finally:
                await conn.close()
        except Exception as e:
            logging.error(f"Error deleting transaction: {e}")
            raise

    async def get_chat_history(self, user_id: str, conversation_id: str = None, limit: int = 10):
        """Get chat history for a user, optionally filtered by conversation_id"""
        try:
            conn = await self.get_connection()
            try:
                if conversation_id:
                    query = '''
                        SELECT 
                            id,
                            user_id,
                            content,
                            is_user,
                            timestamp,
                            conversation_id
                        FROM chat_messages 
                        WHERE user_id = $1 AND conversation_id = $2
                        ORDER BY timestamp DESC LIMIT $3
                    '''
                    rows = await conn.fetch(query, user_id, conversation_id, limit)
                else:
                    query = '''
                        SELECT 
                            id,
                            user_id,
                            content,
                            is_user,
                            timestamp,
                            conversation_id
                        FROM chat_messages 
                        WHERE user_id = $1
                        ORDER BY timestamp DESC LIMIT $2
                    '''
                    rows = await conn.fetch(query, user_id, limit)
                
                # Convert to list of dictionaries
                messages = [dict(row) for row in rows]
                return messages
            finally:
                await conn.close()
        except Exception as e:
            raise

    async def get_conversations(self, user_id: str):
        """Get all conversations for a user"""
        try:
            conn = await self.get_connection()
            try:
                rows = await conn.fetch('''
                    SELECT DISTINCT conversation_id, MAX(timestamp) as last_message_time
                    FROM chat_messages
                    WHERE user_id = $1 AND conversation_id IS NOT NULL
                    GROUP BY conversation_id
                    ORDER BY last_message_time DESC
                ''', user_id)
                
                # Convert to list of dictionaries
                conversations = [dict(row) for row in rows]
                return conversations
            finally:
                await conn.close()
        except Exception as e:
            raise

    async def get_messages_by_content(self, user_id: str, content: str, limit: int = 10):
        """Get messages by content for a user"""
        try:
            conn = await self.get_connection()
            try:
                rows = await conn.fetch('''
                    SELECT 
                        id,
                        user_id,
                        content,
                        is_user,
                        timestamp,
                        conversation_id
                    FROM chat_messages 
                    WHERE user_id = $1 AND content ILIKE $2
                    ORDER BY timestamp DESC LIMIT $3
                ''', user_id, f"%{content}%", limit)
                
                # Convert to list of dictionaries
                messages = [dict(row) for row in rows]
                return messages
            finally:
                await conn.close()
        except Exception as e:
            raise 

    async def update_calorie_entry(self, user_id: str, entry_id: str, food_info: dict):
        """Update an existing calorie entry"""
        try:
            # Log the parameters for debugging
            print(f"Attempting to update calorie entry with id={entry_id} for user_id={user_id}")
            print(f"Food info: {food_info}")
            
            # Convert entry_id to int if it's a string containing only digits
            entry_id_param = int(entry_id) if isinstance(entry_id, str) and entry_id.isdigit() else entry_id
            
            conn = await self.get_connection()
            try:
                # First check if the entry exists and belongs to the user
                entry_exists = await conn.fetchval('''
                    SELECT id FROM meals 
                    WHERE id = $1 AND user_id = $2
                ''', entry_id_param, user_id)
                
                print(f"Entry exists check result: {entry_exists}")
                
                if not entry_exists:
                    print(f"Entry with id={entry_id} not found for user_id={user_id}")
                    return False
                
                # Build the update query dynamically
                update_fields = []
                update_values = []
                
                # Add fields that are present in food_info
                if "food_item" in food_info:
                    update_fields.append("food_item = $" + str(len(update_values) + 1))
                    update_values.append(food_info["food_item"])
                
                if "calories" in food_info:
                    update_fields.append("calories = $" + str(len(update_values) + 1))
                    # Convert calories to integer if it's a string
                    try:
                        calories_value = int(food_info["calories"]) if isinstance(food_info["calories"], str) else food_info["calories"]
                        update_values.append(calories_value)
                    except ValueError:
                        print(f"Error converting calories value '{food_info['calories']}' to integer")
                        update_values.append(food_info["calories"])
                
                if "carbs" in food_info:
                    update_fields.append("carbs = $" + str(len(update_values) + 1))
                    # Convert carbs to float if it's a string
                    try:
                        carbs_value = float(food_info["carbs"]) if isinstance(food_info["carbs"], str) else food_info["carbs"]
                        update_values.append(carbs_value)
                    except (ValueError, TypeError):
                        print(f"Error converting carbs value '{food_info['carbs']}' to float, using NULL")
                        update_values.append(None)
                
                if "protein" in food_info:
                    update_fields.append("protein = $" + str(len(update_values) + 1))
                    # Convert protein to float if it's a string
                    try:
                        protein_value = float(food_info["protein"]) if isinstance(food_info["protein"], str) else food_info["protein"]
                        update_values.append(protein_value)
                    except (ValueError, TypeError):
                        print(f"Error converting protein value '{food_info['protein']}' to float, using NULL")
                        update_values.append(None)
                
                if "fat" in food_info:
                    update_fields.append("fat = $" + str(len(update_values) + 1))
                    # Convert fat to float if it's a string
                    try:
                        fat_value = float(food_info["fat"]) if isinstance(food_info["fat"], str) else food_info["fat"]
                        update_values.append(fat_value)
                    except (ValueError, TypeError):
                        print(f"Error converting fat value '{food_info['fat']}' to float, using NULL")
                        update_values.append(None)
                
                if "quantity" in food_info:
                    update_fields.append("quantity = $" + str(len(update_values) + 1))
                    # Convert quantity to float if it's a string
                    try:
                        quantity_value = float(food_info["quantity"]) if isinstance(food_info["quantity"], str) else food_info["quantity"]
                        update_values.append(quantity_value)
                    except (ValueError, TypeError):
                        print(f"Error converting quantity value '{food_info['quantity']}' to float, using 1.0")
                        update_values.append(1.0)
                
                if "unit" in food_info:
                    update_fields.append("unit = $" + str(len(update_values) + 1))
                    update_values.append(food_info["unit"])
                
                # Add entry_id and user_id to values
                update_values.extend([entry_id_param, user_id])
                
                print(f"Update query fields: {update_fields}")
                print(f"Update values: {update_values}")
                
                # Execute the update query
                query = f'''
                    UPDATE meals 
                    SET {", ".join(update_fields)}
                    WHERE id = ${len(update_values) - 1} AND user_id = ${len(update_values)}
                '''
                print(f"Executing query: {query}")
                
                result = await conn.execute(query, *update_values)
                print(f"Update result: {result}")
                
                # In PostgreSQL with asyncpg, the result is a string like 'UPDATE 1'
                # where the number indicates how many rows were affected
                if result and isinstance(result, str) and 'UPDATE' in result:
                    # Extract the number of rows updated
                    try:
                        rows_updated = int(result.split(' ')[1])
                        success = rows_updated > 0
                        print(f"Updated {rows_updated} rows, success={success}")
                        return success
                    except (IndexError, ValueError):
                        # If we can't parse the result, check if it contains UPDATE
                        success = 'UPDATE' in result and 'UPDATE 0' not in result
                        print(f"Could not parse row count, assuming success={success} based on result string")
                        return success
                else:
                    print(f"Unexpected update result format: {result}")
                    return False
            finally:
                await conn.close()
        except Exception as e:
            print(f"Error updating calorie entry: {str(e)}")
            # Re-raise the exception to provide more details in the API response
            raise

    async def delete_calorie_entry(self, user_id: str, entry_id: str):
        """Delete a calorie entry"""
        try:
            # Log the parameters for debugging
            print(f"Attempting to delete calorie entry with id={entry_id} for user_id={user_id}")
            
            # Handle both UUID strings and integer IDs
            # First, try to convert to int if it's a string containing only digits
            if isinstance(entry_id, str) and entry_id.isdigit():
                # It's a string representation of an integer (server ID)
                entry_id_param = int(entry_id)
                print(f"Converted string integer ID '{entry_id}' to integer: {entry_id_param}")
            elif isinstance(entry_id, int):
                # It's already an integer
                entry_id_param = entry_id
                print(f"Using integer ID: {entry_id_param}")
            else:
                # It's a UUID string - we need to find the corresponding server ID
                print(f"Received UUID string ID: {entry_id}")
                
                # For UUID strings, we can't delete directly from the server
                # because the server database only has integer IDs
                # This suggests the entry was created locally but not yet synced
                print(f"Cannot delete entry with UUID ID '{entry_id}' from server - entry may be local-only")
                return False
            
            conn = await self.get_connection()
            try:
                # First check if the entry exists and belongs to the user
                entry_exists = await conn.fetchval('''
                    SELECT id FROM meals 
                    WHERE id = $1 AND user_id = $2
                ''', entry_id_param, user_id)
                
                print(f"Entry exists check result: {entry_exists}")
                
                if not entry_exists:
                    print(f"Entry with id={entry_id_param} not found for user_id={user_id}")
                    return False
                
                # Delete the entry
                result = await conn.execute('''
                    DELETE FROM meals 
                    WHERE id = $1 AND user_id = $2
                ''', entry_id_param, user_id)
                
                print(f"Delete result: {result}")
                
                # In PostgreSQL with asyncpg, the result is a string like 'DELETE 1'
                # where the number indicates how many rows were affected
                if result and isinstance(result, str) and 'DELETE' in result:
                    # Extract the number of rows deleted
                    try:
                        rows_deleted = int(result.split(' ')[1])
                        success = rows_deleted > 0
                        print(f"Deleted {rows_deleted} rows, success={success}")
                        return success
                    except (IndexError, ValueError):
                        # If we can't parse the result, check if it contains DELETE
                        success = 'DELETE' in result and 'DELETE 0' not in result
                        print(f"Could not parse row count, assuming success={success} based on result string")
                        return success
                else:
                    print(f"Unexpected delete result format: {result}")
                    return False
            finally:
                await conn.close()
        except Exception as e:
            print(f"Error deleting calorie entry: {str(e)}")
            # Re-raise the exception to provide more details in the API response
            raise

    async def get_calories_by_period(self, user_id: str, period: str = 'daily', month: str = None):
        """
        Get summarized calorie data for a specific period.
        Returns a dictionary with total calories, macros, and a breakdown by food item.
        """
        try:
            print(f"DEBUG: get_calories_by_period called with user_id: {user_id}, period: {period}, month: {month}")
            
            # Get raw entries for the period
            entries = await self.get_raw_calorie_entries(user_id, period, month)
            print(f"DEBUG: get_calories_by_period retrieved {len(entries)} raw calorie entries")
            
            # Debug: Print each entry
            for i, entry in enumerate(entries):
                print(f"DEBUG: Entry {i+1}: {entry.get('food_item', 'Unknown')} - {entry.get('calories', 0)} calories, carbs: {entry.get('carbs', 0)}, protein: {entry.get('protein', 0)}, fat: {entry.get('fat', 0)}")
            
            # Initialize summary data
            summary = {
                'totalCalories': 0,
                'totalCarbs': 0,
                'totalProtein': 0,
                'totalFat': 0,
                'breakdown': []
            }
            
            # Calculate totals
            food_items = {}
            for entry in entries:
                # Add to totals
                calories = entry.get('calories', 0) or 0
                carbs = entry.get('carbs', 0) or 0
                protein = entry.get('protein', 0) or 0
                fat = entry.get('fat', 0) or 0
                
                print(f"DEBUG: Processing entry: {entry.get('food_item', 'Unknown')} - calories: {calories}, carbs: {carbs}, protein: {protein}, fat: {fat}")
                
                summary['totalCalories'] += calories
                summary['totalCarbs'] += carbs
                summary['totalProtein'] += protein
                summary['totalFat'] += fat
                
                print(f"DEBUG: Running totals - calories: {summary['totalCalories']}, carbs: {summary['totalCarbs']}, protein: {summary['totalProtein']}, fat: {summary['totalFat']}")
                
                # Group by food item for breakdown
                food_item = entry.get('food_item', 'Unknown')
                if food_item in food_items:
                    food_items[food_item]['calories'] += calories
                    food_items[food_item]['count'] += 1
                else:
                    food_items[food_item] = {
                        'calories': calories,
                        'count': 1
                    }
            
            # Create breakdown list
            for food_item, data in food_items.items():
                summary['breakdown'].append({
                    'food_item': food_item,
                    'calories': data['calories'],
                    'count': data['count']
                })
            
            # Sort breakdown by calories (highest first)
            summary['breakdown'] = sorted(summary['breakdown'], key=lambda x: x['calories'], reverse=True)
            
            print(f"DEBUG: Final calorie summary: total={summary['totalCalories']}, carbs={summary['totalCarbs']}, protein={summary['totalProtein']}, fat={summary['totalFat']}, items={len(summary['breakdown'])}")
            return summary
        except Exception as e:
            print(f"Error in get_calories_by_period: {e}")
            import traceback
            print(f"Traceback: {traceback.format_exc()}")
            # Return empty summary on error
            return {
                'totalCalories': 0,
                'totalCarbs': 0,
                'totalProtein': 0,
                'totalFat': 0,
                'breakdown': []
            }
    
    async def get_raw_calorie_entries(self, user_id: str, period: str = 'daily', month: str = None):
        """
        Get raw calorie entry data for a specific period.
        Returns a list of calorie entry objects with all details.
        """
        try:
            # Get the current date
            now = datetime.now()
            
            # Determine the date range based on the period
            if period == 'daily':
                # Today's entries - use datetime objects directly, not strings
                start_date = datetime(now.year, now.month, now.day)
                end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                print(f"Daily period: filtering entries between {start_date} and {end_date}")
            elif period == 'weekly':
                # This week's entries (starting from Monday)
                today = now.weekday()  # 0 is Monday, 6 is Sunday
                start_date = (datetime(now.year, now.month, now.day) - timedelta(days=today))
                end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                # end_date = start_date + timedelta(days=6, hours=23, minutes=59, seconds=59)  # Sunday at 23:59:59
            elif period == 'yearly':
                # This year's entries
                start_date = datetime(now.year, 1, 1)
                end_date = datetime(now.year, 12, 31, 23, 59, 59)
            else:  # monthly (default)
                # This month's entries or specific month if provided
                if month:
                    try:
                        # Check if month is just a month number (e.g., "03")
                        if len(month) <= 2 and month.isdigit():
                            # Use current year with the provided month
                            year = now.year
                            month_num = int(month)
                        else:
                            # Parse the month string (format: YYYY-MM)
                            year, month_num = map(int, month.split('-'))
                        
                        _, last_day = calendar.monthrange(year, month_num)
                        start_date = datetime(year, month_num, 1).isoformat()
                        end_date = datetime(year, month_num, last_day, 23, 59, 59).isoformat()
                    except Exception as e:

                        # Fallback to current month
                        start_date = datetime(now.year, now.month, 1).isoformat()
                        _, last_day = calendar.monthrange(now.year, now.month)
                        end_date = datetime(now.year, now.month, last_day, 23, 59, 59).isoformat()
                else:
                    # Current month
                    start_date = datetime(now.year, now.month, 1).isoformat()
                    _, last_day = calendar.monthrange(now.year, now.month)
                    end_date = datetime(now.year, now.month, last_day, 23, 59, 59).isoformat()
            
            # For daily period, use a different approach with DATE() function
            if period == 'daily':
                query = """
                SELECT id, user_id, food_item, calories, carbs, protein, fat, quantity, unit, timestamp
                FROM meals
                WHERE user_id = $1 AND DATE(timestamp) = $2::date
                ORDER BY timestamp DESC
                """
                
                # Format date as string in YYYY-MM-DD format
                date_str = f"{now.year}-{now.month:02d}-{now.day:02d}"
                print(f"DEBUG: get_raw_calorie_entries - Executing daily query with user_id: {user_id}, date: {date_str}")
                
                # First, let's check what entries exist for this user
                debug_query = "SELECT id, food_item, calories, timestamp, DATE(timestamp) as entry_date FROM meals WHERE user_id = $1 ORDER BY timestamp DESC LIMIT 5"
                
                conn = await self.get_connection()
                try:
                    # Debug: Check what entries exist for this user
                    debug_rows = await conn.fetch(debug_query, user_id)
                    print(f"DEBUG: Found {len(debug_rows)} total entries for user {user_id}")
                    for i, row in enumerate(debug_rows):
                        print(f"DEBUG: Entry {i+1}: ID={row['id']}, food={row['food_item']}, calories={row['calories']}, timestamp={row['timestamp']}, date={row['entry_date']}")
                    
                    date_obj = datetime.strptime(date_str, "%Y-%m-%d")
                    print(f"DEBUG: Searching for entries on date: {date_obj}")
                    rows = await conn.fetch(query, user_id, date_obj)
                    print(f"DEBUG: Daily query returned {len(rows)} rows for date {date_str}")
                    
                    # Convert to list of dictionaries
                    entries = []
                    for row in rows:
                        entry_data = {
                            "id": row["id"],
                            "food_item": row["food_item"],
                            "calories": int(row["calories"]),
                            "carbs": float(row["carbs"]) if row["carbs"] is not None else None,
                            "protein": float(row["protein"]) if row["protein"] is not None else None,
                            "fat": float(row["fat"]) if row["fat"] is not None else None,
                            "quantity": float(row["quantity"]) if row["quantity"] is not None else 1.0,
                            "unit": row["unit"] or "serving",
                            "timestamp": row["timestamp"]
                        }
                        entries.append(entry_data)
                        print(f"DEBUG: Found entry: {entry_data}")
                    
                    if not entries:
                        print("DEBUG: No daily entries found. Returning empty list.")
                        # We should NOT fall back to monthly data if daily entries are empty
                        # This ensures we accurately represent that no entries exist for today
                    else:
                        print(f"DEBUG: Returning {len(entries)} daily entries")
                    
                    return entries
                finally:
                    await conn.close()
            else:
                # For other periods, use a different approach
                # Format dates as strings in ISO format
                if period == 'weekly':
                    # This week's entries (starting from Monday)
                    today = now.weekday()  # 0 is Monday, 6 is Sunday
                    start_date_obj = (datetime(now.year, now.month, now.day) - timedelta(days=today))
                    end_date_obj = datetime(now.year, now.month, now.day, 23, 59, 59)
                    start_date_str = start_date_obj.strftime('%Y-%m-%d')
                    end_date_str = end_date_obj.strftime('%Y-%m-%d')
                elif period == 'yearly':
                    # This year's entries
                    start_date_str = f"{now.year}-01-01"
                    end_date_str = f"{now.year}-12-31"
                else:  # monthly
                    if month:
                        try:
                            # Check if month is just a month number (e.g., "03")
                            if len(month) <= 2 and month.isdigit():
                                # Use current year with the provided month
                                year = now.year
                                month_num = int(month)
                            else:
                                # Parse the month string (format: YYYY-MM)
                                year, month_num = map(int, month.split('-'))
                            
                            _, last_day = calendar.monthrange(year, month_num)
                            start_date_str = f"{year}-{month_num:02d}-01"
                            end_date_str = f"{year}-{month_num:02d}-{last_day:02d}"
                        except Exception as e:
                            print(f"Error parsing month: {str(e)}")
                            # Fallback to current month
                            start_date_str = f"{now.year}-{now.month:02d}-01"
                            _, last_day = calendar.monthrange(now.year, now.month)
                            end_date_str = f"{now.year}-{now.month:02d}-{last_day:02d}"
                    else:
                        # Current month
                        start_date_str = f"{now.year}-{now.month:02d}-01"
                        _, last_day = calendar.monthrange(now.year, now.month)
                        end_date_str = f"{now.year}-{now.month:02d}-{last_day:02d}"
                
                query = """
                SELECT id, user_id, food_item, calories, carbs, protein, fat, quantity, unit, timestamp
                FROM meals
                WHERE user_id = $1 AND DATE(timestamp) BETWEEN $2::date AND $3::date
                ORDER BY timestamp DESC
                """
                
                print(f"Executing query with user_id: {user_id}, start_date: {start_date_str}, end_date: {end_date_str}")
            
            # Only execute this part for non-daily periods
            if period != 'daily':
                conn = await self.get_connection()
                try:
                    # Convert string dates to datetime objects
                    start_date_obj = datetime.strptime(start_date_str, "%Y-%m-%d")
                    end_date_obj = datetime.strptime(end_date_str, "%Y-%m-%d")
                    rows = await conn.fetch(query, user_id, start_date_obj, end_date_obj)
                    
                    # Convert to list of dictionaries
                    entries = []
                    print(f"Query returned {len(rows)} rows")
                    
                    # Debug: print the first few rows if available
                    if rows:
                        print(f"First row timestamp: {rows[0]['timestamp']}")
                        
                    for row in rows:
                        entries.append({
                        "id": row["id"],
                        "food_item": row["food_item"],
                        "calories": int(row["calories"]),
                        "carbs": float(row["carbs"]) if row["carbs"] is not None else None,
                        "protein": float(row["protein"]) if row["protein"] is not None else None,
                        "fat": float(row["fat"]) if row["fat"] is not None else None,
                        "quantity": float(row["quantity"]) if row["quantity"] is not None else 1.0,
                        "unit": row["unit"] or "serving",
                        "timestamp": row["timestamp"]
                    })
                
                # This block is now handled by the daily-specific query above
                # Keeping this commented out for reference
                # if period == 'daily' and not entries:
                #     print("No daily entries found, trying more flexible date query")
                        
                    # This block is now handled by the daily-specific query above
                    # Keeping this commented out for reference
                    # try:
                    #     # Flexible query implementation
                    # except Exception as e:
                    #     print(f"Error in flexible date query: {str(e)}")
                    # 
                    # # If flexible query fails or returns no results, fall back to monthly
                    # print("Flexible query failed or returned no results, falling back to monthly")
                    # return await self.get_raw_calorie_entries(user_id, 'monthly', month)
                
                    return entries
                finally:
                    await conn.close()
        except Exception as e:
            print(f"Error in get_raw_calorie_entries: {str(e)}")
            return []

    async def get_transactions_by_period(self, user_id: str, period: str = 'monthly', month: str = None):
        """Get transactions by period (daily, weekly, monthly, yearly)"""
        try:
            # Get the current date
            now = datetime.now()
            print(f"Getting transactions for period: {period}, month: {month}, user_id: {user_id}")
            
            # Determine the date range based on the period
            if period == 'daily':
                # Today's transactions
                start_date = datetime(now.year, now.month, now.day)
                end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                print(f"Daily period: {start_date} to {end_date}")
            elif period == 'weekly':
                # This week's transactions (starting from Monday)
                today = now.weekday()  # 0 is Monday, 6 is Sunday
                start_date = (datetime(now.year, now.month, now.day) - timedelta(days=today))
                end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                print(f"Weekly period: {start_date} to {end_date}")
            elif period == 'yearly':
                # This year's transactions
                start_date = datetime(now.year, 1, 1)
                end_date = datetime(now.year, 12, 31, 23, 59, 59)
                print(f"Yearly period: {start_date} to {end_date}")
            else:  # monthly (default)
                # This month's transactions or specific month if provided
                if month:
                    try:
                        # Check if month is just a month number (e.g., "03")
                        if len(month) <= 2 and month.isdigit():
                            # Use current year with the provided month
                            year = now.year
                            month_num = int(month)
                        else:
                            # Parse the month string (format: YYYY-MM)
                            year, month_num = map(int, month.split('-'))
                        
                        _, last_day = calendar.monthrange(year, month_num)
                        start_date = datetime(year, month_num, 1)
                        end_date = datetime(year, month_num, last_day, 23, 59, 59)
                        print(f"Monthly period (specified): {start_date} to {end_date}")
                    except Exception as e:
                        print(f"Error parsing month '{month}': {str(e)}")
                        # Fallback to current month
                        start_date = datetime(now.year, now.month, 1)
                        _, last_day = calendar.monthrange(now.year, now.month)
                        end_date = datetime(now.year, now.month, last_day, 23, 59, 59)
                        print(f"Monthly period (fallback): {start_date} to {end_date}")
                else:
                    # Current month
                    start_date = datetime(now.year, now.month, 1)
                    _, last_day = calendar.monthrange(now.year, now.month)
                    end_date = datetime(now.year, now.month, last_day, 23, 59, 59)
                    print(f"Monthly period (current): {start_date} to {end_date}")
            
            # Query the database for transactions in the date range
            query = """
            SELECT category, SUM(amount) as total
            FROM transactions
            WHERE user_id = $1 AND timestamp BETWEEN $2 AND $3
            GROUP BY category
            """
            
            print(f"Executing query with start_date={start_date}, end_date={end_date}")
            
            conn = await self.get_connection()
            try:
                rows = await conn.fetch(query, user_id, start_date, end_date)
                
                # Convert to dictionary
                category_totals = {}
                for row in rows:
                    category_totals[row["category"]] = float(row["total"])
                
                print(f"Found {len(category_totals)} categories with transactions")
                print(f"Category totals: {category_totals}")
                
                # If no results found with the exact date range, try a more flexible query
                if not category_totals:
                    print("No transactions found with exact date range, trying date-only comparison")
                    # Try with date only comparison for PostgreSQL
                    date_query = """
                    SELECT category, SUM(amount) as total
                    FROM transactions
                    WHERE user_id = $1 AND DATE(timestamp) BETWEEN DATE($2) AND DATE($3)
                    GROUP BY category
                    """
                    
                    rows = await conn.fetch(date_query, user_id, start_date, end_date)
                    
                    for row in rows:
                        category_totals[row["category"]] = float(row["total"])
                    
                    print(f"Found {len(category_totals)} categories with date-only comparison")
                    print(f"Updated category totals: {category_totals}")
                
                return category_totals
            finally:
                await conn.close()
        except Exception as e:
            print(f"Error in get_transactions_by_period: {str(e)}")
            return {}
        
        # ... existing code...
    
    async def get_user_by_email(self, email):
        """
        Get a user by their email address.
        
        Args:
            email (str): The email address to search for
            
        Returns:
            User object or None if not found
        """
        try:
            conn = await self.get_connection()
            try:
                # Check if the users table exists
                table_exists = await conn.fetchval("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_name = 'users'
                    )
                """)
                
                if not table_exists:
                    print("DEBUG DB: Users table does not exist")
                    return None
                    
                # Query for the user by email
                print(f"DEBUG DB: Looking up user by email: {email}")
                user_record = await conn.fetchrow(
                    "SELECT * FROM users WHERE email = $1",
                    email
                )
                
                if not user_record:
                    print(f"DEBUG DB: No user found with email: {email}")
                    return None
                    
                # Convert the record to a User object
                from models.user import User
                user = User(
                    id=str(user_record['id']),
                    email=user_record['email'],
                    name=user_record['name'],
                    firebase_uid=user_record['firebase_uid'],
                    created_at=user_record['created_at']
                )
                print(f"DEBUG DB: Found user with id={user.id}, firebase_uid={user.firebase_uid}")
                return user
                
            finally:
                await conn.close()
        except Exception as e:
            import traceback
            print(f"DEBUG DB: Error in get_user_by_email: {str(e)}")
            print(f"DEBUG DB: {traceback.format_exc()}")
            return None

    async def get_raw_transactions(self, user_id: str, period: str = 'daily', month: str = None, date: str = None):
        """
        Get raw transaction data for a specific period.
        Returns a list of transaction objects with all details.
        """
        try:
            # Get the current date
            now = datetime.now()
            print(f"Getting raw transactions for period: {period}, month: {month}, date: {date}, user_id: {user_id}")
            
            # Determine the date range based on the period
            if period == 'daily':
                if date:
                    # Use the specific date provided in the request
                    try:
                        # Parse the date string (format: YYYY-MM-DD)
                        year, month_num, day = map(int, date.split('-'))
                        start_date = datetime(year, month_num, day)
                        end_date = datetime(year, month_num, day, 23, 59, 59)
                        print(f"Daily period (specified date): {start_date} to {end_date}")
                    except ValueError as e:
                        print(f"Error parsing date '{date}': {str(e)}")
                        # Fallback to today if date parsing fails
                        start_date = datetime(now.year, now.month, now.day)
                        end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                        print(f"Daily period (fallback to today): {start_date} to {end_date}")
                else:
                    # Today's transactions
                    start_date = datetime(now.year, now.month, now.day)
                    end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                    print(f"Daily period (today): {start_date} to {end_date}")
            elif period == 'weekly':
                # This week's transactions (starting from Monday)
                today = now.weekday()  # 0 is Monday, 6 is Sunday
                start_date = (datetime(now.year, now.month, now.day) - timedelta(days=today))
                end_date = datetime(now.year, now.month, now.day, 23, 59, 59)
                print(f"Weekly period: {start_date} to {end_date}")
            elif period == 'yearly':
                # This year's transactions
                start_date = datetime(now.year, 1, 1)
                end_date = datetime(now.year, 12, 31, 23, 59, 59)
                print(f"Yearly period: {start_date} to {end_date}")
            else:  # monthly (default)
                # This month's transactions or specific month if provided
                if month:
                    try:
                        # Check if month is just a month number (e.g., "03")
                        if len(month) <= 2 and month.isdigit():
                            # Use current year with the provided month
                            year = now.year
                            month_num = int(month)
                        else:
                            # Parse the month string (format: YYYY-MM)
                            year, month_num = map(int, month.split('-'))
                        
                        _, last_day = calendar.monthrange(year, month_num)
                        start_date = datetime(year, month_num, 1)
                        end_date = datetime(year, month_num, last_day, 23, 59, 59)
                        print(f"Monthly period (specified): {start_date} to {end_date}")
                    except Exception as e:
                        print(f"Error parsing month '{month}': {str(e)}")
                        # Fallback to current month
                        start_date = datetime(now.year, now.month, 1)
                        _, last_day = calendar.monthrange(now.year, now.month)
                        end_date = datetime(now.year, now.month, last_day, 23, 59, 59)
                        print(f"Monthly period (fallback): {start_date} to {end_date}")
                else:
                    # Current month
                    start_date = datetime(now.year, now.month, 1)
                    _, last_day = calendar.monthrange(now.year, now.month)
                    end_date = datetime(now.year, now.month, last_day, 23, 59, 59)
                    print(f"Monthly period (current): {start_date} to {end_date}")
            
            # Query the database for transactions in the date range
            query = """
            SELECT id, user_id, amount, category, description, timestamp
            FROM transactions
            WHERE user_id = $1 AND timestamp BETWEEN $2 AND $3
            ORDER BY timestamp DESC
            """
            
            print(f"Executing query with start_date={start_date}, end_date={end_date}")
            
            conn = await self.get_connection()
            try:
                rows = await conn.fetch(query, user_id, start_date, end_date)
                
                # Convert to list of dictionaries
                transactions = []
                for row in rows:
                    transactions.append({
                        "id": row["id"],
                        "amount": float(row["amount"]),
                        "category": row["category"],
                        "description": row["description"],
                        "timestamp": row["timestamp"]
                    })
                
                print(f"Found {len(transactions)} transactions with exact date range")
                
                # If no results found with the exact date range, try a more flexible query
                if not transactions:
                    print("No transactions found with exact date range, trying date-only comparison")
                    # Try with date only comparison for PostgreSQL
                    date_query = """
                    SELECT id, user_id, amount, category, description, timestamp
                    FROM transactions
                    WHERE user_id = $1 AND DATE(timestamp) BETWEEN DATE($2) AND DATE($3)
                    ORDER BY timestamp DESC
                    """
                    
                    rows = await conn.fetch(date_query, user_id, start_date, end_date)
                    
                    for row in rows:
                        transactions.append({
                            "id": row["id"],
                            "amount": float(row["amount"]),
                            "category": row["category"],
                            "description": row["description"],
                            "timestamp": row["timestamp"]
                        })
                    
                    print(f"Found {len(transactions)} transactions with date-only comparison")
                
                return transactions
            finally:
                await conn.close()
        except Exception as e:
            print(f"Error in get_raw_transactions: {str(e)}")
            return []

    async def link_firebase_uid_to_user(self, email: str, firebase_uid: str):
        """
        Link a new Firebase UID to an existing user account that has the same email.
        This handles the case of a user signing in with a different auth provider
        but the same email address.
        
        Args:
            email (str): The email address of the existing user
            firebase_uid (str): The new Firebase UID to link to the user
            
        Returns:
            User object or None if not found/updated
        """
        try:
            print(f"DEBUG DB: Linking Firebase UID {firebase_uid} to user with email {email}")
            
            # First check if the user exists by email
            existing_user = await self.get_user_by_email(email)
            if not existing_user:
                print(f"DEBUG DB: No user found with email: {email}")
                return None
                
            print(f"DEBUG DB: Found existing user with id={existing_user.id}, current firebase_uid={existing_user.firebase_uid}")
            
            # Update the user's firebase_uid
            conn = await self.get_connection()
            try:
                result = await conn.execute(
                    "UPDATE users SET firebase_uid = $1 WHERE email = $2",
                    firebase_uid, email
                )
                
                print(f"DEBUG DB: Update result: {result}")
                
                # Verify the update
                updated_user = await self.get_user_by_firebase_uid(firebase_uid)
                if updated_user:
                    print(f"DEBUG DB: Successfully linked Firebase UID {firebase_uid} to user {existing_user.id}")
                    return updated_user
                else:
                    print(f"DEBUG DB: Failed to link Firebase UID {firebase_uid} to user {existing_user.id}")
                    return None
            finally:
                await conn.close()
        except Exception as e:
            import traceback
            print(f"DEBUG DB: Error in link_firebase_uid_to_user: {str(e)}")
            print(f"DEBUG DB: {traceback.format_exc()}")
            return None