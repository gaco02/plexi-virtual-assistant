import time
from typing import List, Dict
from .db_service import RestaurantDBService
from .nlp_service import analyze_restaurant_caption

class RestaurantBatchProcessor:
    def __init__(self, db_service: RestaurantDBService):
        self.db_service = db_service
    
    def process_batch(self, captions_data):
        for caption in captions_data:
            try:
                # Extract complete restaurant information
                restaurant_info = analyze_restaurant_caption(caption['text'])
                
                # Clean and validate data
                restaurant_name = restaurant_info.get('name', '').strip()
                if not restaurant_name:
                    continue
                    
                # Insert with complete information
                self.db_service.insert_or_update_restaurant(
                    name=restaurant_name,
                    cuisine_type=restaurant_info.get('cuisine_type', 'Unknown'),
                    price_level=restaurant_info.get('price_level', 'Unknown'),
                    total_likes=caption.get('likes', 0),
                    highlights=restaurant_info.get('highlights', []),
                    source_id=caption.get('source_id')
                )
                
            except Exception as e:
                print(f"Error processing caption: {e}") 