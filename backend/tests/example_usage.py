from services.db_service import RestaurantDBService
from services.batch_processor import RestaurantBatchProcessor
import time

def main():
    # Initialize services
    db_service = RestaurantDBService("restaurant_insights.db")
    batch_processor = RestaurantBatchProcessor(db_service)

    # Example batch of captions
    sample_batch = [
        {
            "text": "📍 Sushi Delight - Amazing authentic Japanese restaurant! The fresh sashimi ($25) was incredible",
            "source_id": "post123",
            "likes": 150
        },
        {
            "text": "Another great meal at Sushi Delight! Their rolls are 🔥",
            "source_id": "post124",
            "likes": 75
        }
    ]

    try:
        # Process the batch
        print("Starting batch processing...")
        batch_processor.process_batch(sample_batch)
        print("Batch processing completed")
        
    except Exception as e:
        print(f"Error during batch processing: {str(e)}")
    
    finally:
        # Give time for any pending transactions to complete
        time.sleep(1)

if __name__ == "__main__":
    main() 