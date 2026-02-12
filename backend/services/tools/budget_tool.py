import json
from datetime import datetime
import calendar
from models.chat import ChatRequest, ChatResponse
from services.db_service import VirtualAssistantDB
from openai import OpenAI
import logging
import re
from config.settings import get_settings
settings = get_settings()
client = OpenAI(api_key=settings.OPENAI_API_KEY)

class BudgetTool:
    def __init__(self):
        self.db = VirtualAssistantDB()
        # Updated function schema to include additional categories.
        self.functions = [
            {
                "name": "log_expense",
                "description": "Log a new expense or savings transaction",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "amount": {
                            "type": "number",
                            "description": "Amount spent or saved (in dollars)"
                        },
                        "category": {
                            "type": "string",
                            "description": ("Category of transaction "
                                            "(e.g., groceries, dining, transport, entertainment, shopping, housing, savings, investment, or other)"),
                        "enum": ["groceries", "dining", "transport", "entertainment", "shopping", "housing", "savings", "investment", "other"]
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the transaction"
                        }
                    },
                    "required": ["amount", "category"]
                }
            }
        ]
        
        self.schema = {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "description": ("Category of transaction "
                                    "(e.g., groceries, dining, transport, entertainment, shopping, housing, savings, investment, or other)"),
                    "enum": ["groceries", "dining", "transport", "entertainment", "shopping", "housing", "savings", "investment", "other"]
                },
                "description": {
                    "type": "string",
                    "description": "Description of the transaction"
                },
                "amount": {
                    "type": "number",
                    "description": "Amount of the transaction"
                }
            },
            "required": ["category", "description", "amount"]
        }
        
        # Precompile regex patterns for better performance
        self.category_patterns = {
            "dining": [re.compile(r"(?i)\b(restaurant|dining|dinning|dine|dinner|lunch|breakfast|eat|eating|ate|food|meal|cafe|bistro|brunch|takeout|take away|food delivery|fast food|pizza|sushi|burger|taco|restaurants|dining out|eat out|cafe|bistro|brunch|takeout|take away|food delivery|bar|pub|tavern|drinks|cocktail|beer|wine)\b")],
            "groceries": [re.compile(r"(?i)\b(grocery|supermarket|market|groceries|food|snacks|produce|dairy|meat|bakery|cereal|pantry|staples|walmart|kroger|trader joe's|whole foods)\b")],
            "transport": [re.compile(r"(?i)\b(bus|train|subway|metro|taxi|uber|lyft|car|fuel|car payment|car insurance|auto insurance|vehicle payment|vehicle insurance)\b")],
            "entertainment": [re.compile(r"(?i)\b(movie|theatre|concert|show|game|entertainment|netflix|subscription)\b")],
            "shopping": [re.compile(r"(?i)\b(clothes|shoes|shopping|amazon|online|store|mall)\b")],
            "housing": [re.compile(r"(?i)\b(rent|mortgage|utilities|electricity|water|internet|housing|gas bill|phone|cell phone|mobile plan|phone bill|insurance)\b")],
            "investment": [re.compile(r"(?i)\b(investment|invest|stock|bond|401k|ira)\b")],
            "savings": [re.compile(r"(?i)\b(save|saving)\b")]
        }

    def is_query_request(self, message: str) -> bool:
        """Determine if the message is a query."""
        query_patterns = [
            "how much", "what is the total", "what's the total",
            "show me", "tell me", "check my", "view my", "display my"
        ]
        return any(pattern in message.lower() for pattern in query_patterns)

    async def process_request(self, request: ChatRequest):
        """Process budget requests (both logging and queries)."""
        try:
            print(f"Processing budget request: {request.message}")
            message_lower = request.message.lower()
            
            # Check for query patterns first.
            if self.is_query_request(message_lower):
                print("Detected as a query request")  # Debug log
                response = await self.handle_query(request)
                print(f"Query response: {response.dict()}")
                return response
            else:
                print("Detected as a logging request")  # Debug log
                response = await self.handle_logging(request)
                print(f"Logging response: {response.dict()}")
                if response.success:
                    return response
                else:
                    return ChatResponse(
                        response="I couldn't identify any financial transactions to log.",
                        success=False,
                        expense_info={
                            "actions_logged": 0,
                            "total_amount": 0,
                            "categories": {}
                        }
                    )
        except Exception as e:
            print(f"Error in budget process_request: {e}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return ChatResponse(
                response="Sorry, I couldn't process your budget request.",
                success=False,
                expense_info={
                    "actions_logged": 0,
                    "total_amount": 0,
                    "categories": {}
                }
            )

    async def extract_expense_actions(self, message: str) -> list:
        """
        Ask the LM to extract all financial transaction actions (spending or saving)
        from the message and output them as a JSON array.
        Each action should be a JSON object with the following keys:
          - amount: a number representing the amount spent or saved (in dollars),
          - category: one of dining, transport, entertainment, shopping, housing, savings, investment, or other,
          - description: a short description (optional).
        Include actions that represent a financial transaction, regardless of whether it indicates spending or saving.
        If ambiguous, interpret it as a financial transaction logging event.
        Return ONLY the JSON array, with no markdown formatting.
        """
        try:
            # Check if the message is empty or None
            if not message or message.strip() == "":
                return []
                
            # For simple messages, try a direct pattern matching approach first
            simple_patterns = [
                (r'(?i)(?:spent|spend|pay|paid|bought|buy)\s+\$?(\d+(?:\.\d+)?)\s+(?:in|at|on)\s+(?:a\s+|an\s+|the\s+)?(.*)',
 lambda m: [{"amount": float(m.group(1)), "category": self.categorize_expense(m.group(2)), "description": m.group(2)}]),
                (r'(?i)(?:spent|spend|pay|paid|bought|buy)\s+\$?(\d+(?:\.\d+)?)(?:\s+(\w+))?', 
                 lambda m: [{"amount": float(m.group(1)), "category": self.categorize_expense(m.group(2)) if m.group(2) else "other", "description": m.group(2) if m.group(2) else ""}]),
                (r'(?i)(\d+(?:\.\d+)?)\s+(?:dollars|bucks|$)\s+(?:on|for)\s+(.*)', 
                 lambda m: [{"amount": float(m.group(1)), "category": self.categorize_expense(m.group(2)), "description": m.group(2)}]),
            ]
            
            for pattern, handler in simple_patterns:
                import re
                match = re.search(pattern, message)
                if match:
                    print(f"Matched simple pattern: {pattern}")
                    return handler(match)
            
            # If no simple pattern matched, use the LLM
            prompt = (
                "Extract all financial transaction actions (spending or saving) from the following message and output them as a JSON array. "
                "Each action should be a JSON object with the following keys:\n"
                "  - amount: a number representing the amount spent or saved (in dollars),\n"
                "  - category: one of groceries, dining, transport, entertainment, shopping, housing, savings, investment, or other,\n"
                "  - description: a short description (optional).\n"
                "Include actions that represent a financial transaction, regardless of whether it indicates spending or saving. "
                "If the person says investing, put it in the savings category. "
                "If ambiguous, interpret it as a financial transaction logging event.\n\n"
                f"Message: \"{message}\"\n\n"
                "Return ONLY the JSON array, no markdown formatting."
            )

            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant that extracts expense information."},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0
            )

            # Get the content from the response
            content = response.choices[0].message.content.strip()
            print(f"LLM response: {content}")
            
            # Try to extract JSON from the response
            try:
                data = json.loads(content)
                
                # Handle different response formats
                if isinstance(data, dict):
                    # Check if there's a transactions or expenses key
                    for key in ['transactions', 'expenses', 'actions', 'items']:
                        if key in data and isinstance(data[key], list):
                            actions = data[key]
                            break
                    else:
                        # If no known array key, look for any array in the response
                        for key, value in data.items():
                            if isinstance(value, list):
                                actions = value
                                break
                        else:
                            # If no array found, wrap the entire object in a list
                            actions = [data]
                elif isinstance(data, list):
                    actions = data
                else:
                    actions = []
                    
            except json.JSONDecodeError:
                print("Failed to parse JSON from OpenAI response")
                # Try to find a JSON array in the text
                import re
                json_match = re.search(r'\[.*\]', content, re.DOTALL)
                if json_match:
                    try:
                        json_str = json_match.group(0)
                        actions = json.loads(json_str)
                    except:
                        actions = []
                else:
                    actions = []
            
            # Ensure actions is a list
            if not isinstance(actions, list):
                print(f"Warning: Expected a list but got {type(actions)}")
                actions = []
                
            # Validate and clean up the actions
            validated_actions = []
            for action in actions:
                if not isinstance(action, dict):
                    continue
                    
                # Ensure all required fields are present
                if "amount" not in action:
                    continue
                    
                # Convert amount to float
                try:
                    action["amount"] = float(action["amount"])
                except (ValueError, TypeError):
                    continue
                
                # Set default category if missing
                if "category" not in action or not action["category"]:
                    if "description" in action and action["description"]:
                        action["category"] = self.categorize_expense(action["description"])
                    else:
                        action["category"] = "other"
                
                # Set default values for missing fields
                action.setdefault("description", "")
                
                validated_actions.append(action)
                
            return validated_actions

        except Exception as e:
            print(f"Error extracting expense actions: {e}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return []
            
    def categorize_expense(self, description: str) -> str:
        """Categorize an expense based on its description using precompiled regex patterns."""
        if not description:
            return "other"
            
        description = description.lower()
        print(f" Categorizing expense: '{description}'")
        
        # Check categories in a prioritized order
        for category in ["dining", "groceries", "transport", "entertainment", "shopping", "housing", "investment", "savings"]:
            for pattern in self.category_patterns[category]:
                if pattern.search(description):
                    print(f" Matched pattern for category: {category}")
                    return category
        
        # If no pattern matches, use AI to categorize
        try:
            print(f" No pattern match, using AI categorization for: '{description}'")
            ai_category = self._ai_categorize(description)
            print(f" AI categorized '{description}' as: {ai_category}")
            return ai_category
        except Exception as e:
            print(f" Error in AI categorization: {e}")
            return "other"
            
    def _ai_categorize(self, description: str) -> str:
        """Use AI to categorize an expense when regex patterns don't match."""
        prompt = f"""
        Categorize the following expense description into one of these categories:
        - dining (restaurants, cafes, bars, food delivery, etc.)
        - groceries (supermarket, food stores, etc.)
        - transport (bus, train, taxi, car expenses, etc.)
        - entertainment (movies, shows, games, subscriptions, etc.)
        - shopping (clothes, electronics, online shopping, etc.)
        - housing (rent, utilities, home expenses, etc.)
        - investment (stocks, bonds, etc.)
        - savings (money put aside)
        - other (if it doesn't fit any category)
        
        Description: "{description}"
        
        Return ONLY the category name, nothing else.
        """
        
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "You are a helpful assistant that categorizes expenses."},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=10  # Keep it short, we just need the category name
        )
        
        category = response.choices[0].message.content.strip().lower()
        
        # Validate the category
        valid_categories = ["dining", "groceries", "transport", "entertainment", "shopping", "housing", "investment", "savings", "other"]
        if category not in valid_categories:
            # Try to match to closest valid category
            if "food" in category or "restaurant" in category or "eat" in category or "bar" in category:
                return "dining"
            if "market" in category or "grocer" in category:
                return "groceries"
            if "travel" in category or "car" in category or "gas" in category:
                return "transport"
            if "movie" in category or "game" in category or "fun" in category:
                return "entertainment"
            if "cloth" in category or "buy" in category or "purchase" in category:
                return "shopping"
            if "home" in category or "rent" in category or "bill" in category:
                return "housing"
            if "invest" in category or "stock" in category:
                return "investment"
            if "save" in category:
                return "savings"
            return "other"
            
        return category

    async def handle_logging(self, request: ChatRequest):
        """Handle financial transaction logging."""
        try:
            print(f"Budget tool received request: {request.dict()}")
            print(f"Local time from request: {request.local_time}")

            actions = await self.extract_expense_actions(request.message)
            if not actions:
                return ChatResponse(
                    response="I couldn't identify any financial transactions to log.",
                    success=False,
                    expense_info={
                        "actions_logged": 0,
                        "total_amount": 0,
                        "categories": {}
                    }
                )
            
            responses = []
            total_logged = 0
            categories_logged = {}
            
            # Track transactions for summary
            print(" Processing transactions")
            
            for action in actions:
                try:
                    # Extract action data
                    amount = float(action['amount'])
                    category = action.get('category', 'other')
                    description = action.get('description', '')
                    
                    print(f" Processing transaction: {amount} for {category} ({description})")
                    
                    # Save the transaction
                    print(f" Saving transaction: amount={amount}, category={category}, timestamp={request.local_time}")
                    await self.db.save_transaction(
                        user_id=request.user_id,
                        amount=amount,
                        category=category,
                        description=description,
                        timestamp=request.local_time
                    )
                    
                    # Update our tracking
                    total_logged += 1
                    categories_logged[category] = categories_logged.get(category, 0) + amount
                    
                    # Format response
                    responses.append(f"${amount:.2f} for {category} ({description})")
                except Exception as e:
                    print(f"Error processing action {action}: {e}")
                    continue
            
            if not responses:
                return ChatResponse(
                    response="I couldn't process any of the transactions.",
                    success=False,
                    expense_info={
                        "actions_logged": 0,
                        "total_amount": 0,
                        "categories": {}
                    }
                )
            
            # Get all of today's transactions to calculate the daily total
            print(" Getting all transactions for today")
            today_date = datetime.now().strftime('%Y-%m-%d')
            try:
                # Get raw transactions for today
                today_transactions = await self.db.get_raw_transactions(
                    user_id=request.user_id,
                    period='daily',
                    date=today_date
                )
                
                # Calculate totals by category for today
                daily_totals = {}
                for tx in today_transactions:
                    category = tx['category']
                    amount = tx['amount']
                    daily_totals[category] = daily_totals.get(category, 0) + amount
                
                # Calculate total spent today
                total_spent_today = sum(daily_totals.values())
                
                print(" Today's spending summary:")
                for category, amount in daily_totals.items():
                    print(f"  - {category}: ${amount:.2f}")
                print(f" Total spent today: ${total_spent_today:.2f}")
                
                # Format the response
                response_text = f"Logged: {', '.join(responses)}. Total spent today: ${total_spent_today:.2f}"
                
                return ChatResponse(
                    response=response_text,
                    success=True,
                    expense_info={
                        "actions_logged": total_logged,
                        "total_amount": total_spent_today,
                        "categories": daily_totals
                    }
                )
            except Exception as e:
                print(f"Error getting today's transactions: {e}")
                # Fallback to just showing what we logged in this session
                total_amount = sum(categories_logged.values())
                response_text = f"Logged: {', '.join(responses)}. Total: ${total_amount:.2f}"
                
                return ChatResponse(
                    response=response_text,
                    success=True,
                    expense_info={
                        "actions_logged": total_logged,
                        "total_amount": total_amount,
                        "categories": categories_logged
                    }
                )
        except Exception as e:
            print(f"Error logging expense: {e}")
            return ChatResponse(
                response="Sorry, I couldn't log your transaction.",
                success=False,
                expense_info={
                    "actions_logged": 0,
                    "total_amount": 0,
                    "categories": {}
                }
            )

    def determine_query_scope(self, message: str) -> tuple[str, str | None]:
        """
        Determine query scope and specific month if applicable.
        Returns (scope, month) where month is None for non-specific queries.
        """
        message = message.lower()
        
        # Check for specific months.
        months = {
            'january': '01', 'february': '02', 'march': '03', 'april': '04',
            'may': '05', 'june': '06', 'july': '07', 'august': '08',
            'september': '09', 'october': '10', 'november': '11', 'december': '12'
        }
        
        for month_name, month_num in months.items():
            if month_name in message:
                return 'specific_month', month_num
        
        # Check for other time periods.
        if any(word in message for word in ["today", "now", "current"]):
            return 'daily', None
        elif any(word in message for word in ["week", "weekly", "7 days"]):
            return 'weekly', None
        elif any(word in message for word in ["year", "yearly", "this year"]):
            return 'yearly', None
        elif any(word in message for word in ["month", "monthly"]):
            return 'monthly', None
        
        return 'daily', None  # Default.

    async def handle_query(self, request: ChatRequest):
        """Handle expense queries."""
        try:
            if not request.user_id:
                print("No user ID provided for query")
                return ChatResponse(
                    response="No user ID provided",
                    success=True,
                    expense_info={
                        "is_query_response": True,
                        "total_amount": 0,
                        "categories": {}
                    }
                )

            scope, month = self.determine_query_scope(request.message)
            print(f"Query scope: {scope}, Month: {month}")
            print(f"User ID for query: {request.user_id}")

            # Get raw category amounts from database
            category_amounts = await self.db.get_transactions_by_period(request.user_id, scope, month)
            print(f"Raw category amounts from DB: {category_amounts}")

            # Format period text for response.
            period_text = {
                'daily': 'Today',
                'weekly': 'This week',
                'monthly': 'This month',
                'yearly': 'This year',
                'specific_month': f"In {list(calendar.month_name)[int(month)]}" if month else "This month"
            }.get(scope, 'Today')

            if not category_amounts:
                print("No transactions found for the period")
                return ChatResponse(
                    response=f"You haven't logged any transactions {period_text.lower()}.",
                    success=True,
                    expense_info={
                        "is_query_response": True,
                        "total_amount": 0,
                        "categories": {}
                    }
                )

            # Calculate total and format categories
            total = sum(category_amounts.values())
            
            # Format category breakdown for response text
            category_details = []
            for category, amount in category_amounts.items():
                category_details.append(f"${amount:.2f} on {category}")
            
            response_text = f"{period_text} you've spent ${total:.2f} total"
            if category_details:
                response_text += f" ({', '.join(category_details)})"
            
            print(f"Final response text: {response_text}")
            
            response = ChatResponse(
                response=response_text,
                success=True,
                expense_info={
                    "is_query_response": True,
                    "total_amount": total,
                    "categories": category_amounts
                }
            )
            print(f"Final response object: {response.dict()}")
            return response

        except Exception as e:
            print(f"Error in handle_query: {str(e)}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return ChatResponse(
                response="Sorry, I couldn't retrieve your transactions.",
                success=False,
                expense_info={
                    "is_query_response": True,
                    "total_amount": 0,
                    "categories": {}
                }
            )

    async def extract_expense_info(self, message: str):
        """(Legacy) Extract expense information using OpenAI function calling."""
        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "Extract expense information from the user's message."},
                    {"role": "user", "content": message}
                ],
                functions=self.functions,
                function_call={"name": "log_expense"}
            )
            if response.choices[0].message.function_call:
                function_args = json.loads(response.choices[0].message.function_call.arguments)
                return function_args
            return None
        except Exception as e:
            print(f"Error extracting expense info: {e}")
            return None