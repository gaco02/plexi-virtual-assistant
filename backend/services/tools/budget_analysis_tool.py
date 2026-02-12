from datetime import datetime, timedelta
from typing import Dict, List
from openai import OpenAI
import json
from config.settings import get_settings

settings = get_settings()
client = OpenAI(api_key=settings.OPENAI_API_KEY)

class BudgetAnalysisTool:
    # Expanded CATEGORY_MAPPING so that transactions with additional labels (like "housing" and "transport") are categorized.
    CATEGORY_MAPPING = {
        'needs': ['groceries', 'utilities', 'rent', 'healthcare', 'housing', 'transport'],
        'wants': ['food', 'entertainment', 'dining', 'shopping', 'other'],
        'savings': ['savings', 'investment']
    }
    WANTS_CATEGORIES = ['food', 'entertainment', 'dining', 'shopping', 'other']

    def __init__(self, db):
        self.db = db

    async def log_transaction(self, user_id: str, amount: float, category: str = 'other', description: str = None) -> Dict:
        """Log a transaction and return updated budget analysis"""
        try:
            # Save the transaction
            await self.db.save_transaction(
                user_id=user_id,
                amount=amount,
                category=category,
                description=description or f"Transaction of ${amount}"
            )
            
            # Get updated budget analysis
            return await self.analyze_budget(user_id)
        except Exception as e:
            print(f"Error logging transaction: {e}")
            return {"error": "Failed to log transaction"}

    async def analyze_budget(self, user_id: str, month: str = None, monthly_salary: float = None) -> Dict:
        """Analyze the user's budget for a given month."""
        try:
            # Estimate the user's monthly income if not provided
            if monthly_salary is None:
                monthly_salary = await self._estimate_monthly_income(user_id)
            
            # Define ideal allocations based on the 50/30/20 rule
            ideal_allocations = {
                "needs": monthly_salary * 0.50,   # 50% for needs
                "wants": monthly_salary * 0.30,   # 30% for wants
                "savings": monthly_salary * 0.20  # 20% for savings
            }

            # Get categorized spending
            actual = await self.get_categorized_spending(user_id, month)

            # Calculate total actual spending
            total_actual = sum(actual.values())
            
            # Generate recommendations based on the budget analysis
            recommendations = await self._generate_recommendations(
                ideal=ideal_allocations,
                actual=actual,
                salary=monthly_salary,
                user_id=user_id,
                month=month
            )
            
            print(f"Generated {len(recommendations)} recommendations")
            
            return {
                "monthly_salary": monthly_salary,
                "ideal": ideal_allocations,
                "actual": actual,
                "total": total_actual,
                "recommendations": recommendations
            }
        except Exception as e:
            # Re-raise the exception to be handled by the caller
            raise e
            
    async def get_categorized_spending(self, user_id: str, month: str = None) -> Dict:
        """Get spending categorized into needs, wants, and savings."""
        # Fetch transactions (returns a dictionary of category totals)
        transactions = await self.db.get_transactions_by_period(user_id, 'monthly', month)
        print(f"Fetched transactions for user {user_id} in month {month}:")
        for category, amount in transactions.items():
            print(f"  - {category}: ${amount:.2f}")
        
        # Initialize spending categories
        spending = {"needs": 0, "wants": 0, "savings": 0}
        
        # Map each transaction category to needs/wants/savings
        for category, amount in transactions.items():
            category_lower = category.lower()
            print(f"Processing category: {category_lower} (${amount:.2f})")
            
            # Check which budget category this transaction belongs to
            if any(need in category_lower for need in self.CATEGORY_MAPPING['needs']):
                print(f"  - Categorized as NEEDS")
                spending["needs"] += amount
            elif any(want in category_lower for want in self.CATEGORY_MAPPING['wants']):
                print(f"  - Categorized as WANTS")
                spending["wants"] += amount
            elif any(save in category_lower for save in self.CATEGORY_MAPPING['savings']):
                print(f"  - Categorized as SAVINGS")
                spending["savings"] += amount
            else:
                # Default to "wants" for uncategorized spending
                print(f"  - Categorized as WANTS (default)")
                spending["wants"] += amount
        
        print(f"Final categorized spending: {spending}")
        return spending

    async def _estimate_monthly_income(self, user_id: str) -> float:
        """
        Estimate the user's monthly income based on available data.
        This is a fallback method when we don't have direct access to the user's salary.
        
        Args:
            user_id: The user ID to estimate income for
            
        Returns:
            Estimated monthly income
        """
        try:
            # First, try to get the monthly salary from user_preferences using the proper method
            try:
                user_preferences = await self.db.get_user_preferences(user_id)
                if user_preferences and "monthly_salary" in user_preferences and user_preferences["monthly_salary"]:
                    salary = float(user_preferences["monthly_salary"])
                    print(f"Found monthly salary in user_preferences: ${salary}")
                    return salary
            except Exception as e:
                print(f"Could not get monthly salary from user_preferences: {e}")
            
            # If that fails, try to estimate based on income transactions
            try:
                # Look for income transactions in the last 3 months
                three_months_ago = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")
                query = """
                SELECT SUM(amount) as total_income 
                FROM transactions 
                WHERE user_id = ? AND category = 'income' AND timestamp >= ?
                """
                result = await self.db.fetch_one(query, (user_id, three_months_ago))
                if result and "total_income" in result and result["total_income"]:
                    # Average over 3 months
                    salary = float(result["total_income"]) / 3
                    print(f"Estimated monthly salary from income transactions: ${salary}")
                    return salary
            except Exception as e:
                print(f"Could not estimate income from transactions: {e}")
            
            # If all else fails, use a reasonable default based on local economy
            print("No salary data available, using estimate based on median income")
            # This could be improved by using location data to estimate local median income
            return 3000.0  # A more conservative estimate
            
        except Exception as e:
            print(f"Error estimating monthly income: {e}")
            # Return a conservative estimate as fallback
            return 3000.0

    async def _generate_recommendations(
        self,
        ideal: Dict[str, float],
        actual: Dict[str, float],
        salary: float,
        user_id: str,
        month: str
    ) -> List[Dict]:
        """Generate personalized budget recommendations comparing ideal vs. actual spending."""
        # First, generate basic recommendations using rule-based approach
        basic_recommendations = []
        for category in ["needs", "wants", "savings"]:
            actual_percent = (actual[category] / salary) * 100 if salary else 0
            ideal_percent = (ideal[category] / salary) * 100 if salary else 0
            difference = actual_percent - ideal_percent

            if category == "wants" and difference > 5:
                basic_recommendations.append({
                    "category": category,
                    "type": "reduce_spending",
                    "message": f"Your spending on wants is {actual_percent:.1f}% of your salary, which is higher than the recommended {ideal_percent:.1f}%.",
                    "suggested_action": "Consider reducing discretionary spending.",
                    "potential_savings": actual[category] - ideal[category]
                })
            elif category == "savings" and difference < -5:
                basic_recommendations.append({
                    "category": category,
                    "type": "increase_savings",
                    "message": f"Your savings rate is {actual_percent:.1f}% of your salary, which is below the target of {ideal_percent:.1f}%.",
                    "suggested_action": "Try to increase your monthly savings.",
                    "potential_savings": ideal[category] - actual[category]
                })
        
        # Now, enhance with OpenAI-driven detailed analysis
        try:
            ai_recommendations = await self._generate_ai_recommendations(
                ideal=ideal,
                actual=actual,
                salary=salary,
                user_id=user_id,
                month=month
            )
            # Combine both sets of recommendations, with AI recommendations first
            return ai_recommendations + basic_recommendations
        except Exception as e:
            print(f"Error generating AI recommendations: {e}")
            # Fall back to basic recommendations if AI fails
            return basic_recommendations

    async def _generate_ai_recommendations(
        self,
        ideal: Dict[str, float],
        actual: Dict[str, float],
        salary: float,
        user_id: str,
        month: str
    ) -> List[Dict]:
        """Generate detailed, personalized recommendations using OpenAI."""
        try:
            # Calculate percentages for the prompt
            needs_actual_percent = (actual["needs"] / salary) * 100 if salary else 0
            wants_actual_percent = (actual["wants"] / salary) * 100 if salary else 0
            savings_actual_percent = (actual["savings"] / salary) * 100 if salary else 0
            
            needs_ideal_percent = (ideal["needs"] / salary) * 100 if salary else 0
            wants_ideal_percent = (ideal["wants"] / salary) * 100 if salary else 0
            savings_ideal_percent = (ideal["savings"] / salary) * 100 if salary else 0
            
            # Fetch detailed category spending
            transactions = await self.db.get_transactions_by_period(user_id, 'monthly', month)
            category_breakdown = "\nDetailed Category Breakdown:\n"
            for category, amount in sorted(transactions.items(), key=lambda x: x[1], reverse=True):
                category_percent = (amount / salary) * 100 if salary else 0
                category_breakdown += f"- {category.capitalize()}: ${amount:.2f} ({category_percent:.1f}% of income)\n"
            
            # Create a detailed wants subcategory breakdown
            wants_breakdown = "\nIn the 'wants' category, your spending is broken down as follows:\n"
            for category, amount in sorted(transactions.items(), key=lambda x: x[1], reverse=True):
                if any(want in category.lower() for want in self.WANTS_CATEGORIES):
                    category_percent = (amount / salary) * 100 if salary else 0
                    wants_breakdown += f"  - {category.capitalize()}: ${amount:.2f} ({category_percent:.1f}% of income)\n"
            
            # Create a detailed prompt for OpenAI
            prompt = f"""
My monthly income is ${salary:.2f}. According to the 50/30/20 rule, I should spend about ${ideal['needs']:.2f} on needs, ${ideal['wants']:.2f} on wants, and save ${ideal['savings']:.2f}. However, my actual spending is as follows:

- Needs: ${actual['needs']:.2f} ({needs_actual_percent:.1f}% of income)
- Wants: ${actual['wants']:.2f} ({wants_actual_percent:.1f}% of income)
- Savings: ${actual['savings']:.2f} ({savings_actual_percent:.1f}% of income)
{wants_breakdown}

Please analyze the detailed breakdown of the 'wants' category provided above. Identify if any specific subcategory (for example, shopping, food, dining, or entertainment) is disproportionately high, and offer targeted recommendations to address this overspending.

Provide 3-4 specific, actionable recommendations to help me optimize my spending in the categories where I'm most over budget or where there's the greatest opportunity for improvement.

For each recommendation, include:
1. The specific category it applies to (e.g., food, transport, entertainment, shopping, housing, savings, investment, or other)
2. The type of recommendation (reduce_spending, increase_savings, optimize_category, or budget_achievement)
3. A clear message explaining the issue or opportunity
4. A specific, actionable suggestion that I can implement immediately
5. The potential savings amount where applicable

Format your response as a JSON array of recommendation objects with these fields:
- category: The specific spending category
- type: The recommendation type
- message: Clear explanation of the issue or opportunity
- suggested_action: Specific actionable advice
- potential_savings: The potential savings amount (if applicable)"""
            
            # Call OpenAI API
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a financial advisor specializing in personal budgeting using the 50/30/20 rule."},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object"},
            )
            
            # Parse and print the response
            try:
                response_json = json.loads(response.choices[0].message.content)
                return response_json.get("recommendations", [])
            except Exception as e:

                return []
                
        except Exception as e:

            return []

    async def _store_budget_data(
        self,
        user_id: str,
        month: str,
        salary: float,
        ideal: Dict[str, float],
        actual: Dict[str, float],
        recommendations: List[Dict]
    ):
        """Store budget analysis data into the database."""
        # Use current month as default if month is not provided.
        month_str = month or datetime.now().strftime("%Y-%m")
        await self.db.store_budget_allocation(
            user_id=user_id,
            month=month_str,
            monthly_salary=salary,
            needs_budget=ideal["needs"],
            wants_budget=ideal["wants"],
            savings_budget=ideal["savings"],
            needs_spent=actual["needs"],
            wants_spent=actual["wants"],
            savings_actual=actual["savings"]
        )

        for rec in recommendations:
            await self.db.store_budget_recommendation(
                user_id=user_id,
                month=month_str,
                category=rec["category"],
                recommendation_type=rec["type"],
                message=rec["message"],
                suggested_action=rec["suggested_action"],
                potential_savings=rec["potential_savings"]
            )