import requests
import json
import time

# API Configuration
API_URL = "https://tiktok-scraper7.p.rapidapi.com/feed/search"
API_KEY = "8a3868100emsh73f456d51587ec6p152cc8jsn186760a1e925"  # Replace with your actual API key

# Search query parameters
QUERY = "vancouver restaurants"
REGION = "us"  # Adjust region if needed
MAX_RESULTS = 50  # Increased from 10 to 50 results
PUBLISH_TIME = 90  # Filter posts from the last 90 days
SORT_TYPE = 0  # Default sorting type
CURSOR = 0  # Pagination start point

HEADERS = {
    "X-RapidAPI-Key": API_KEY,
    "X-RapidAPI-Host": "tiktok-scraper7.p.rapidapi.com",
    "Accept": "application/json",
    "Content-Type": "application/json"
}

PARAMS = {
    "keywords": QUERY,
    "region": REGION,
    "count": MAX_RESULTS,
    "cursor": CURSOR,
    "publish_time": PUBLISH_TIME,
    "sort_type": SORT_TYPE
}

def fetch_tiktok_data(max_videos=100):
    """Fetches data from the TikTok Scraper API."""
    try:
        all_videos = []
        cursor = 0
        
        while len(all_videos) < max_videos:
            # Update cursor for pagination
            PARAMS["cursor"] = cursor
            
            response = requests.get(API_URL, headers=HEADERS, params=PARAMS)
            response.raise_for_status()
            data = response.json()

            videos = data.get("data", {}).get("videos", [])
            if not videos:  # No more videos available
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
            
            cursor += len(videos)  # Update cursor for next page
            
            # Add a small delay to avoid hitting rate limits
            time.sleep(1)

        # Save data to JSON
        with open("tiktok_data.json", "w", encoding="utf-8") as file:
            json.dump(all_videos, file, indent=4, ensure_ascii=False)

        print(f"✅ Successfully saved {len(all_videos)} TikTok posts to 'tiktok_data.json'")
        return all_videos

    except requests.exceptions.RequestException as e:
        print(f"❌ API request failed: {e}")
        return []

# Run the script
if __name__ == "__main__":
    # Fetch 100 videos (or however many you want)
    fetch_tiktok_data(max_videos=100)
