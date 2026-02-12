# app.py
from fastapi import FastAPI, HTTPException
from services.tiktok_service import fetch_tiktok_data, TikTokService
# from services.nlp_service import extract_restaurant_name  # Uncomment when needed
from typing import List, Dict
from pydantic import BaseModel
from services.nlp_service import analyze_restaurant_caption
import datetime
from urllib.parse import unquote
from services.db_service import RestaurantDBService
from services.batch_processor import RestaurantBatchProcessor
import openai
import os
from dotenv import load_dotenv
import json
from fastapi.middleware.cors import CORSMiddleware
from routers import chat, restaurants, budget, calories, auth

# Load environment variables
load_dotenv()

# Initialize OpenAI
openai.api_key = os.getenv("OPENAI_API_KEY")

# Create FastAPI instance
app = FastAPI(
    title="TikTok Analyzer API",
    description="API for analyzing TikTok data",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Initialize TikTok service
tiktok_service = TikTokService()

# Initialize database service
db_service = RestaurantDBService()

# Initialize batch processor
batch_processor = RestaurantBatchProcessor(db_service)

# Include routers
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(chat.router, prefix="/chat", tags=["Chat"])
app.include_router(restaurants.router, prefix="/restaurants", tags=["Restaurants"])
app.include_router(budget.router, prefix="/budget", tags=["Budget"])
app.include_router(calories.router, prefix="/calories", tags=["Calories"])

# Define a Pydantic model for the video data.
class Video(BaseModel):
    video_id: str
    caption: str
    hashtags: List[str]
    likes: int
    comments: int
    shares: int
    author: str
    video_url: str

@app.get("/")
async def root():
    return {"message": "Welcome to TikTok Analyzer API"}

@app.get("/analyze")
async def analyze_tiktoks(query: str = "vancouver restaurants", max_videos: int = 100):
    """
    Analyze TikTok videos based on search query
    """
    results = tiktok_service.analyze_tiktoks(query, max_videos)
    return results

@app.get("/videos", response_model=List[Video])
async def get_videos(max_videos: int = 20):
    """
    Endpoint to fetch TikTok videos.
    You can call this endpoint to trigger data retrieval.
    """
    videos = fetch_tiktok_data(max_videos=max_videos)
    if not videos:
        raise HTTPException(status_code=404, detail="No videos found")
    return videos

# Future endpoint: analyze and extract restaurant info
@app.get("/restaurants", response_model=List[dict])
async def get_restaurant_recommendations(max_videos: int = 20):
    """
    Fetch videos, extract restaurant information, and store in database.
    """
    videos = fetch_tiktok_data(max_videos=max_videos)
    processed = []
    
    for video in videos:
        insights = analyze_restaurant_caption(video["caption"])
        if insights["restaurant_name"]:  # Only include if we found a restaurant name
            # Store in database
            try:
                # Prepare data for storage
                caption_data = {
                    "text": video["caption"],
                    "source_id": video["video_id"],
                    "likes": video["likes"]
                }
                
                # Process and store in database
                batch_processor.process_batch([caption_data])
                
                # Create response object
                restaurant_info = {
                    "video_id": video["video_id"],
                    "restaurant_name": insights["restaurant_name"],
                    "cuisine_type": insights["cuisine_type"],
                    "highlights": insights["highlights"],
                    "confidence_score": insights["confidence_score"],
                    "engagement": {
                        "likes": video["likes"],
                        "comments": video["comments"],
                        "shares": video["shares"]
                    },
                    "author": video["author"],
                    "video_url": video["video_url"],
                    "original_caption": video["caption"]
                }
                processed.append(restaurant_info)
                
            except Exception as e:
                print(f"Error storing data for {video['video_id']}: {str(e)}")
                continue
    
    if not processed:
        raise HTTPException(status_code=404, detail="No restaurant data found")
    
    # Sort by engagement (likes) and then confidence score
    processed.sort(key=lambda x: (x["engagement"]["likes"], x["confidence_score"]), reverse=True)
    
    return processed

@app.get("/analyze-caption")
async def analyze_caption(caption: str):
    """
    Analyze a TikTok caption to extract restaurant insights
    """
    try:
        # Decode the URL-encoded caption
        decoded_caption = unquote(caption)
        insights = analyze_restaurant_caption(decoded_caption)
        return insights
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing caption: {str(e)}")

@app.get("/health")
async def health_check():
    """
    Simple health check endpoint to verify the API is running
    """
    return {
        "status": "healthy",
        "timestamp": datetime.datetime.now().isoformat(),
        "version": "1.0.0"
    }