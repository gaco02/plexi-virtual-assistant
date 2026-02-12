import requests
import json
from requests.exceptions import Timeout, ConnectionError

def test_chat_api():
    # API endpoint
    BASE_URL = "http://192.168.1.229:8000"
    
    # Add timeout for requests
    TIMEOUT_SECONDS = 10
    
    try:
        # Test health endpoint first
        print("\n1. Testing health endpoint...")
        health_response = requests.get(
            f"{BASE_URL}/health",
            timeout=TIMEOUT_SECONDS
        )
        print(f"Health Response: {health_response.json()}")
        
        # Test data
        chat_request = {
            "message": "I'm looking for a good restaurant for a date in Vancouver",
            "conversation_history": [
                {
                    "role": "user",
                    "content": "I want to find a restaurant"
                },
                {
                    "role": "assistant",
                    "content": "I can help you find restaurants. What type of cuisine are you interested in?"
                }
            ]
        }
        
        # Test chat endpoint
        print("\n2. Testing chat endpoint...")
        print("Sending request to:", f"{BASE_URL}/chat")
        print("Request data:", json.dumps(chat_request, indent=2))
        
        chat_response = requests.post(
            f"{BASE_URL}/chat",
            json=chat_request,
            headers={"Content-Type": "application/json"},
            timeout=TIMEOUT_SECONDS
        )
        
        print(f"Response status code: {chat_response.status_code}")
        print("Response headers:", chat_response.headers)
        
        if chat_response.status_code != 200:
            print(f"Error response: {chat_response.text}")
            return
            
        print("\nChat Response:")
        response_data = chat_response.json()
        print(json.dumps(response_data, indent=2))
        
        if 'restaurant_suggestions' in response_data:
            print(f"\nNumber of restaurant suggestions: {len(response_data['restaurant_suggestions'])}")
            
    except Timeout:
        print("Error: Request timed out. The server took too long to respond.")
    except ConnectionError:
        print("Error: Could not connect to the server. Is it running?")
    except requests.exceptions.RequestException as e:
        print(f"Error making request: {e}")
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    print("Starting API test...")
    test_chat_api()
    print("Test completed.") 