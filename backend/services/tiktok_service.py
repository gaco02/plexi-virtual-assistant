# services/tiktok_service.py
import requests, json, time, os
from typing import List, Dict
from tiktok_analyzer import fetch_tiktok_data

API_URL = "https://tiktok-scraper7.p.rapidapi.com/feed/search"
API_KEY = os.getenv("RAPIDAPI_KEY", "")

HEADERS = {
    "X-RapidAPI-Key": API_KEY,
    "X-RapidAPI-Host": "tiktok-scraper7.p.rapidapi.com",
    "Accept": "application/json",
    "Content-Type": "application/json"
}

# You can move these search parameters into a configuration or environment variable later.
BASE_PARAMS = {
    "keywords": "vancouver restaurants",
    "region": "us",
    "count": 50,
    "cursor": 0,
    "publish_time": 90,
    "sort_type": 0
}

def fetch_tiktok_data(max_videos: int = 100) -> List[Dict]:
    """Fetches data from the TikTok Scraper API."""
    all_videos = []
    cursor = 0
    params = BASE_PARAMS.copy()

    while len(all_videos) < max_videos:
        params["cursor"] = cursor
        try:
            response = requests.get(API_URL, headers=HEADERS, params=params)
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            print(f"API request failed: {e}")
            break

        data = response.json()
        videos = data.get("data", {}).get("videos", [])
        if not videos:
            break

        for video in videos:
            if len(all_videos) >= max_videos:
                break

            all_videos.append({
                "video_id": video.get("video_id"),
                "caption": video.get("title"),
                "hashtags": [tag.get("title") for tag in video.get("challenges", [])],
                "likes": video.get("digg_count", 0),
                "comments": video.get("comment_count", 0),
                "shares": video.get("share_count", 0),
                "author": video.get("author", {}).get("nickname", ""),
                "video_url": video.get("play_url", "")
            })
        
        cursor += len(videos)
        time.sleep(1)  # Respect API rate limits

    return all_videos

class TikTokService:
    def analyze_tiktoks(self, query: str, max_videos: int = 100):
        """
        Analyze TikTok videos based on search query
        """
        # Fetch TikTok data using the existing analyzer
        tiktok_data = fetch_tiktok_data(max_videos)
        
        # Here you can add more analysis logic
        return {
            "query": query,
            "total_videos": len(tiktok_data),
            "videos": tiktok_data
        }