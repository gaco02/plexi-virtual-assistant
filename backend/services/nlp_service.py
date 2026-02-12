import re
from typing import Dict, List, Optional, Set
from textblob import TextBlob
import nltk
from nltk import ne_chunk, pos_tag, word_tokenize
from nltk.chunk import tree2conlltags


def setup_nltk():
    """Download required NLTK data."""
    try:
        # Download required NLTK data
        nltk.download('punkt')
        nltk.download('averaged_perceptron_tagger')
        nltk.download('brown')
        nltk.download('wordnet')
        print("✅ Successfully downloaded NLTK data")
    except Exception as e:
        print(f"❌ Error downloading NLTK data: {e}")

# Run setup when module is loaded
setup_nltk()

class RestaurantInsights:
    def __init__(self, text: str):
        self.text = text
        self.blob = TextBlob(text)
        self.suffix_keywords = [
            "Restaurant", "Cafe", "Diner", "Bar", "Grill", 
            "Bistro", "Kitchen", "Eatery", "Pub", "Lounge"
        ]
    
    def extract_restaurant_name(self) -> Optional[str]:
        """Extract restaurant name using multiple heuristics."""
        candidates: Set[str] = set()
        
        # Heuristic 1: Look for location markers "📍"
        pattern_location = r"📍\s*([^,\n]+)"
        matches_location = re.findall(pattern_location, self.text)
        for match in matches_location:
            candidates.add(match.strip())
        
        # Heuristic 2: Look for explicit "Restaurant:" labels
        # Updated pattern to capture the full name after "Restaurant:"
        pattern_explicit = r"Restaurant:\s*([\w\s'&-]+(?:Restaurant)?)"
        matches_explicit = re.findall(pattern_explicit, self.text, flags=re.IGNORECASE)
        for match in matches_explicit:
            candidates.add(match.strip())
        
        # Heuristic 3: Look for "at" followed by potential name
        pattern_at = r"\bat\s+((?:[A-Z][a-zA-Z0-9'&\s-]+)(?:Restaurant)?)"
        matches_at = re.findall(pattern_at, self.text)
        for match in matches_at:
            candidates.add(match.strip())
        
        # Heuristic 4: Look for words ending with "Restaurant"
        # Updated to better handle restaurant names
        pattern_standalone = r"([\w\s'&-]+?Restaurant)"
        matches_standalone = re.findall(pattern_standalone, self.text)
        for match in matches_standalone:
            if match.lower() != "restaurant":  # Exclude standalone "restaurant" word
                candidates.add(match.strip())
        
        print(f"Debug - Initial candidates: {candidates}")  # Debug print
        
        # Filter and rank candidates
        filtered_candidates = []
        for candidate in candidates:
            # Clean up candidate
            cleaned = self._clean_restaurant_name(candidate)
            if cleaned and cleaned.lower() != "restaurant":  # Additional check
                # Check if it has a restaurant-related suffix
                if any(keyword.lower() in cleaned.lower() for keyword in self.suffix_keywords):
                    filtered_candidates.append((cleaned, 2))  # Higher priority for names with restaurant keywords
                else:
                    filtered_candidates.append((cleaned, 1))  # Lower priority for other names
        
        print(f"Debug - Filtered candidates: {filtered_candidates}")  # Debug print
        
        # Return the best candidate (prioritize those with restaurant keywords)
        if filtered_candidates:
            # Sort by priority (descending) and length of name (ascending)
            filtered_candidates.sort(key=lambda x: (-x[1], len(x[0])))
            return filtered_candidates[0][0]
        
        return None
    
    def _clean_restaurant_name(self, name: str) -> Optional[str]:
        """Clean up extracted restaurant names."""
        if not name:
            return None
            
        # Remove common suffixes that might have been included
        address_patterns = [
            r'\s+\d+.*$',  # Remove street numbers and following text
            r'\s*,.*$',    # Remove everything after comma
            r'\s*-.*$',    # Remove everything after hyphen
            r'\s*\(.*\)',  # Remove parenthetical information
            r'\s*#.*$',    # Remove unit numbers
        ]
        
        cleaned = name.strip()
        for pattern in address_patterns:
            cleaned = re.sub(pattern, '', cleaned)
        
        # Remove extra whitespace and punctuation
        cleaned = ' '.join(cleaned.split())
        
        # Validate minimum length and content
        if len(cleaned) < 2 or not any(c.isalnum() for c in cleaned):
            return None
            
        return cleaned
    
    def extract_cuisine_type(self) -> Optional[str]:
        """Identify cuisine type and restaurant category."""
        cuisine_keywords = {
            'japanese': ['japanese', 'sushi', 'ramen'],
            'korean': ['korean', 'k-food', 'kimchi'],
            'chinese': ['chinese', 'dim sum', 'szechuan'],
            'seafood': ['seafood', 'fish', 'oyster'],
            'fine dining': ['fine dining', 'upscale', 'gourmet']
        }
        
        text_lower = self.text.lower()
        for cuisine, keywords in cuisine_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                return cuisine.title()
        return None
    
    def extract_price_indication(self) -> Optional[str]:
        """Extract price information."""
        price_pattern = r'\$(\d+(?:\.\d{2})?)'
        prices = re.findall(price_pattern, self.text)
        if prices:
            prices = [float(p) for p in prices]
            avg_price = sum(prices) / len(prices)
            if avg_price < 15:
                return "Budget-friendly"
            elif avg_price < 30:
                return "Moderate"
            else:
                return "High-end"
        return None
    
    def extract_highlights(self) -> List[str]:
        """Extract key positive aspects mentioned."""
        positive_keywords = [
            # Food-related positive words
            'delicious', 'amazing', 'great', 'good', 'excellent',
            'fresh', 'authentic', 'friendly', 'beautiful', 'recommended',
            'yummy', 'tasty', 'fantastic', 'favorite', 'best',
            'love', 'dream', 'must try', 'incredible', 'perfect',
            
            # Common food expressions
            'to die for', 'mouth watering', 'mind blowing',
            'worth it', 'hidden gem', 'spot on'
        ]
        
        # Emoji indicators of positive sentiment
        positive_emojis = ['😋', '😍', '🤤', '👌', '🔥', '⭐', '💯', '❤️']
        
        highlights = []
        # Split text into sentences, including emoji-only segments
        sentences = [sent.string.strip() for sent in self.blob.sentences]
        
        for sentence in sentences:
            # Check for positive emojis
            has_positive_emoji = any(emoji in sentence for emoji in positive_emojis)
            
            # Get sentiment score
            sentiment = TextBlob(sentence).sentiment.polarity
            
            # Consider a sentence positive if it has positive sentiment OR contains positive emoji
            is_positive = sentiment > 0 or has_positive_emoji
            
            if is_positive:
                # Check for positive keywords
                if any(keyword.lower() in sentence.lower() for keyword in positive_keywords):
                    highlights.append(sentence)
                # Also include sentences with positive emojis even without keywords
                elif has_positive_emoji and len(sentence.strip()) > 5:  # Avoid emoji-only sentences
                    highlights.append(sentence)
        
        # Remove duplicates and limit to 3 most relevant highlights
        unique_highlights = list(dict.fromkeys(highlights))
        
        # Sort highlights by length (prefer shorter, more concise highlights)
        unique_highlights.sort(key=len)
        
        return unique_highlights[:3]
    
    def get_full_insights(self) -> Dict:
        """Combine all insights into a structured format."""
        # Get basic insights
        insights = {
            "restaurant_name": self.extract_restaurant_name(),
            "cuisine_type": self.extract_cuisine_type(),
            "price_level": self.extract_price_indication(),
            "highlights": self.extract_highlights(),
            "raw_caption": self.text
        }
        
        # Add confidence score based on available information
        confidence_score = 0
        if insights["restaurant_name"]:
            confidence_score += 0.4
        if insights["cuisine_type"]:
            confidence_score += 0.2
        if insights["price_level"]:
            confidence_score += 0.2
        if insights["highlights"]:
            confidence_score += 0.2
            
        insights["confidence_score"] = round(confidence_score, 2)
        
        return insights

def analyze_restaurant_caption(caption: str) -> dict:
    """Analyze a caption to extract restaurant information"""
    print(f"\nAnalyzing caption: {caption[:100]}...")  # Debug print
    
    # Extract restaurant name
    restaurant_name = extract_restaurant_name(caption)
    if not restaurant_name:
        print(f"No restaurant name found in caption")
        return {}
        
    # Basic cuisine type detection
    cuisine_type = detect_cuisine_type(caption)
    
    # Price level detection ($ to $$$)
    price_level = detect_price_level(caption)
    
    # Extract highlights
    highlights = extract_highlights(caption)
    
    result = {
        'name': restaurant_name,
        'cuisine_type': cuisine_type,
        'price_level': price_level,
        'highlights': highlights,
        'confidence_score': 0.8  # You can adjust this based on your extraction confidence
    }
    
    print(f"Extracted info: {result}")  # Debug print
    return result

def extract_restaurant_name(text: str) -> str:
    """Extract restaurant name from text using patterns and rules"""
    print(f"Trying to extract name from: {text[:100]}...")  # Debug print
    
    # Common patterns for restaurant mentions
    patterns = [
        r"Restaurant:\s*([^🌶️\n,]+)",  # Matches "Restaurant: Name" before emoji or newline
        r"📍\s*([^#\n,]+)",  # Matches names after location pin emoji
        r"at\s+([A-Z][A-Za-z\s&'-]+)(?=\sin|,|\s)",  # Matches "at Restaurant Name"
        r"(?:called|named)\s+([A-Z][A-Za-z\s&'-]+)",  # Matches "called Restaurant Name"
        r"(?:visit|try|check out)\s+([A-Z][A-Za-z\s&'-]+)",  # Matches "try Restaurant Name"
        r"([A-Z][A-Za-z\s&'-]+)(?=\sRestaurant)",  # Matches "Name Restaurant"
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, text)
        if matches:
            # Clean up the extracted name
            name = matches[0].strip()
            # Remove common suffixes and prefixes
            name = re.sub(r'\s*(?:restaurant|cafe|bar|pub|grill)$', '', name, flags=re.IGNORECASE)
            name = re.sub(r'^(?:restaurant|cafe|bar|pub|grill)\s*', '', name, flags=re.IGNORECASE)
            # Clean up any remaining special characters
            name = re.sub(r'[^\w\s&\'-]', '', name).strip()
            
            # Debug print
            print(f"Found name using pattern {pattern}: {name}")
            
            # Validate the name
            if len(name) > 2:  # Basic validation
                return name
    
    # If no matches found with patterns, try to find restaurant name near cuisine keywords
    cuisine_indicators = ['chinese', 'japanese', 'italian', 'szechuan', 'thai', 'mexican']
    text_lower = text.lower()
    
    for cuisine in cuisine_indicators:
        if cuisine in text_lower:
            # Look for capitalized words near cuisine mention
            words = text.split()
            try:
                cuisine_index = [i for i, word in enumerate(words) if cuisine in word.lower()][0]
                # Check words before and after cuisine mention
                for i in range(max(0, cuisine_index-3), min(len(words), cuisine_index+4)):
                    if words[i][0].isupper():
                        potential_name = words[i]
                        if i+1 < len(words) and words[i+1][0].isupper():
                            potential_name += ' ' + words[i+1]
                        print(f"Found name near cuisine: {potential_name}")
                        return potential_name
            except IndexError:
                continue
    
    print("No restaurant name found")  # Debug print
    return None

def detect_cuisine_type(text: str) -> str:
    """Detect cuisine type from text"""
    cuisine_keywords = {
        'japanese': ['japanese', 'sushi', 'ramen', 'sashimi'],
        'italian': ['italian', 'pasta', 'pizza'],
        'chinese': ['chinese', 'dimsum', 'noodles'],
        'szechuan': ['szechuan', 'sichuan', 'spicy chinese'],
        'mexican': ['mexican', 'tacos', 'burrito'],
        'thai': ['thai', 'pad thai', 'curry'],
        'korean': ['korean', 'kbbq', 'bibimbap'],
        'vietnamese': ['vietnamese', 'pho', 'banh mi'],
        'indian': ['indian', 'curry', 'tandoori'],
        'french': ['french', 'bistro', 'cafe']
    }
    
    text_lower = text.lower()
    for cuisine, keywords in cuisine_keywords.items():
        if any(keyword in text_lower for keyword in keywords):
            return cuisine.title()
    
    return 'Unknown'

def detect_price_level(text: str) -> str:
    """Detect price level from text"""
    # Look for dollar signs or price mentions
    if '$$$' in text or 'expensive' in text.lower():
        return '$$$'
    elif '$$' in text or 'moderate' in text.lower():
        return '$$'
    elif '$' in text or 'cheap' in text.lower():
        return '$'
    return 'Unknown'

def extract_highlights(text: str) -> list:
    """Extract key highlights from the caption"""
    highlights = []
    
    # Look for positive phrases
    positive_patterns = [
        r'(?:really |very |super |absolutely )?(?:good|great|amazing|excellent|awesome|delicious|fantastic|wonderful|best) ([^.!?\n]+)',
        r'must(?:-| )?try[: ]+([^.!?\n]+)',
        r'loved[: ]+([^.!?\n]+)',
    ]
    
    for pattern in positive_patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        highlights.extend([match.strip() for match in matches if match.strip()])
    
    return list(set(highlights))[:5]  # Return up to 5 unique highlights

# Example usage
if __name__ == "__main__":
    sample_caption = """
    📍 Sushi Delight - Amazing authentic Japanese restaurant! 
    The fresh sashimi ($25) was incredible and the service was super friendly. 
    Must try their signature rolls. #vancouver #foodie
    """
    
    insights = analyze_restaurant_caption(sample_caption)
    print("Restaurant Analysis:")
    print(f"Name: {insights['name']}")
    print(f"Cuisine: {insights['cuisine_type']}")
    print(f"Price Level: {insights['price_level']}")
    print("Highlights:")
    for highlight in insights['highlights']:
        print(f"- {highlight}")