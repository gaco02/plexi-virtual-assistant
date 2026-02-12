from services.tiktok_service import fetch_tiktok_data
from services.nlp_service import analyze_restaurant_caption
from services.db_service import RestaurantDBService
from services.batch_processor import RestaurantBatchProcessor

def test_complete_flow():
    # 1. Fetch TikTok data
    print("Fetching TikTok data...")
    tiktok_videos = fetch_tiktok_data(max_videos=10)
    
    # 2. Process each video through NLP and prepare for database
    captions_data = []
    for video in tiktok_videos:
        caption_data = {
            "text": video["caption"],
            "source_id": video["video_id"],
            "likes": video["likes"]
        }
        captions_data.append(caption_data)
    
    # 3. Process and store in database
    db_service = RestaurantDBService()
    batch_processor = RestaurantBatchProcessor(db_service)
    batch_processor.process_batch(captions_data)
    
    # 4. Verify stored data
    with db_service.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM restaurants')
        restaurants = cursor.fetchall()
        print(f"\nStored Restaurants: {len(restaurants)}")
        for restaurant in restaurants:
            print(f"- {restaurant}")

if __name__ == "__main__":
    test_complete_flow() 