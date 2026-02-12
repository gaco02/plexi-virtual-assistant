import json
from tiktok_analyzer import fetch_tiktok_data
from services.db_service import RestaurantDBService
from services.batch_processor import RestaurantBatchProcessor

def test_all_components():
    # 1. Test TikTok Data Fetching
    print("\n1. Testing TikTok Data Fetch...")
    tiktok_data = fetch_tiktok_data(max_videos=5)  # Start with just 5 videos
    print(f"Fetched {len(tiktok_data)} videos")
    
    # 2. Test Database Setup
    print("\n2. Testing Database Setup...")
    db_service = RestaurantDBService()
    
    # 3. Test Data Processing and Storage
    print("\n3. Testing Data Processing...")
    batch_processor = RestaurantBatchProcessor(db_service)
    
    # Process the TikTok data
    captions_data = []
    for video in tiktok_data:
        caption_data = {
            "text": video["caption"],
            "source_id": video["video_id"],
            "likes": video["likes"]
        }
        captions_data.append(caption_data)
        print(f"\nProcessing caption: {caption_data['text'][:100]}...")
    
    # Store in database
    batch_processor.process_batch(captions_data)
    
    # 4. Verify Database Contents
    print("\n4. Verifying Database Contents...")
    with db_service.get_connection() as conn:
        cursor = conn.cursor()
        
        # Check restaurants table
        cursor.execute('SELECT COUNT(*) FROM restaurants')
        restaurant_count = cursor.fetchone()[0]
        print(f"Total restaurants in database: {restaurant_count}")
        
        # Show all restaurants
        cursor.execute('''
            SELECT name, cuisine_type, price_level, total_likes, highlights_summary 
            FROM restaurants
        ''')
        print("\nStored Restaurants:")
        for restaurant in cursor.fetchall():
            print("\n-------------------")
            print(f"Name: {restaurant[0]}")
            print(f"Cuisine: {restaurant[1]}")
            print(f"Price: {restaurant[2]}")
            print(f"Likes: {restaurant[3]}")
            print(f"Highlights: {restaurant[4]}")

if __name__ == "__main__":
    test_all_components()