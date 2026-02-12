from services.db_service import DBService
import sqlite3
from datetime import datetime, timedelta

def view_database():
    db = DBService()
    
    try:
        with db.get_connection() as conn:
            cursor = conn.cursor()
            
            # 1. Check if tables exist
            print("\n1. Checking Database Structure:")
            cursor.execute("""
                SELECT name FROM sqlite_master 
                WHERE type='table'
            """)
            tables = cursor.fetchall()
            print(f"Found tables: {[table[0] for table in tables]}")
            
            # 2. Show meals table schema
            print("\n2. Meals Table Schema:")
            cursor.execute("PRAGMA table_info(meals)")
            schema = cursor.fetchall()
            print("Columns:")
            for col in schema:
                print(f"- {col[1]} ({col[2]})")
            
            # 3. Show recent meals
            print("\n3. Recent Meals (Last 7 days):")
            cursor.execute("""
                SELECT 
                    food_item,
                    calories,
                    quantity,
                    unit,
                    timestamp
                FROM meals
                WHERE timestamp >= datetime('now', '-7 days')
                ORDER BY timestamp DESC
            """)
            meals = cursor.fetchall()
            
            if meals:
                for meal in meals:
                    print("\n-------------------")
                    print(f"Food: {meal[0]}")
                    print(f"Calories: {meal[1]}")
                    print(f"Amount: {meal[2]} {meal[3]}")
                    print(f"Time: {meal[4]}")
            else:
                print("No meals found in the last 7 days")
            
            # 4. Show daily calorie totals
            print("\n4. Daily Calorie Totals:")
            cursor.execute("""
                SELECT 
                    date(timestamp) as day,
                    SUM(calories) as total_calories,
                    COUNT(*) as meals_count
                FROM meals
                WHERE timestamp >= datetime('now', '-7 days')
                GROUP BY date(timestamp)
                ORDER BY day DESC
            """)
            
            daily_totals = cursor.fetchall()
            if daily_totals:
                for day in daily_totals:
                    print(f"\n{day[0]}:")
                    print(f"- Total Calories: {day[1]}")
                    print(f"- Number of Meals: {day[2]}")
            else:
                print("No calorie data found")
                
    except sqlite3.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    print("Viewing database contents...")
    view_database() 