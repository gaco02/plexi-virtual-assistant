from fastapi import APIRouter, Depends, HTTPException, Request
from typing import Optional, List, Dict
from datetime import datetime
import logging
from models.chat import ChatRequest
from services.tools.budget_tool import BudgetTool
from services.db_service import VirtualAssistantDB
from middleware.auth_middleware import verify_firebase_token, get_current_user
from models.budget import BudgetAnalysis, BudgetAllocation, Transaction
from services.tools.budget_analysis_tool import BudgetAnalysisTool

# Remove the relative import and use absolute path
def get_db():
    db = VirtualAssistantDB()
    try:
        yield db
    finally:
        pass  # Remove db.close() if no cleanup is needed

router = APIRouter()  # Remove the prefix here since it's added in main.py

@router.post("/track")
async def track_expense(
    request: Request,
    transaction: dict,
    token: dict = Depends(verify_firebase_token),
    db = Depends(get_db)
):
    user_id = token["uid"]
    await db.save_transaction(
        user_id=user_id,
        amount=transaction['amount'],
        category=transaction['category'],
        description=transaction['description']
    )
    return {"success": True}

@router.post("/transactions/add", response_model=Dict)
async def add_transaction(
    transaction: Transaction,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Add a new transaction directly without using OpenAI processing.
    This is more efficient for direct transaction logging.
    """
    try:

        # Save the transaction to the database
        await db.save_transaction(
            user_id=current_user["id"],
            amount=transaction.amount,
            category=transaction.category,
            description=transaction.description,
            timestamp=timestamp
        )
        
        # Get updated daily summary
        daily_summary = await db.get_transactions_by_period(current_user["id"], 'daily')
        total_today = sum(daily_summary.values())
        
        response = {
            "success": True,
            "message": f"Transaction of ${transaction.amount:.2f} for {transaction.category} added successfully",
            "total_today": total_today,
            "expense_info": {
                "actions_logged": 1,
                "total_amount": total_today,
                "categories": daily_summary
            }
        }
        return response
    except Exception as e:
        
        raise HTTPException(
            status_code=500,
            detail=f"Failed to add transaction: {str(e)}"
        )

@router.get("/transactions", response_model=List[Dict])
async def get_transactions(
    period: str = "daily",
    month: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Get transactions for a specific period directly from the database.
    This endpoint bypasses the OpenAI processing for efficiency.
    """
    try:
        # Validate period parameter
        valid_periods = ["daily", "weekly", "monthly", "yearly"]
        if period not in valid_periods:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid period. Must be one of: {', '.join(valid_periods)}"
            )
        
        # Get raw transactions from database
        transactions = await db.get_raw_transactions(
            user_id=current_user["id"],
            period=period,
            month=month
        )
        
        return transactions
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to get transactions: {str(e)}"
        )

@router.post("/transactions", response_model=List[Dict])
async def post_transactions(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Get transactions for a specific period directly from the database via POST.
    This endpoint allows clients to send parameters in the request body.
    """
    try:

        
        # Extract parameters from request body
        period = request.get("period", "daily")
        month = request.get("month", None)
        date = request.get("date", None)  # Extract the date parameter
        user_id = request.get("user_id", current_user["id"])
        
        # Validate period parameter
        valid_periods = ["daily", "weekly", "monthly", "yearly"]
        if period not in valid_periods:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid period. Must be one of: {', '.join(valid_periods)}"
            )
        
        # Get raw transactions from database
        transactions = await db.get_raw_transactions(
            user_id=user_id,
            period=period,
            month=month,
            date=date  # Pass the date parameter to the database function
        )
        
        
        return transactions
    except Exception as e:
        
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get transactions: {str(e)}"
        )

@router.post("/transactions/update", response_model=Dict)
async def update_transaction(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Update an existing transaction.
    
    Required fields in request:
    - transaction_id: ID of the transaction to update
    - amount: New amount for the transaction
    - category: New category for the transaction
    - description: New description for the transaction
    """
    try:
        # Log the request
        logging.info(f"Update transaction request: {request}")
        
        # Extract parameters from request body
        transaction_id = request.get("transaction_id")
        amount = request.get("amount")
        category = request.get("category")
        description = request.get("description")
        
        # Validate required parameters
        if not transaction_id:
            logging.warning("Missing transaction_id in update request")
            raise HTTPException(
                status_code=400,
                detail="transaction_id is required"
            )
        
        if amount is None:  # Allow 0 as a valid amount
            logging.warning("Missing amount in update request")
            raise HTTPException(
                status_code=400,
                detail="amount is required"
            )
        
        if not category:
            logging.warning("Missing category in update request")
            raise HTTPException(
                status_code=400,
                detail="category is required"
            )
        
        if description is None:  # Allow empty string as a valid description
            logging.warning("Missing description in update request")
            raise HTTPException(
                status_code=400,
                detail="description is required"
            )
        
        try:
            # Update the transaction in the database
            success = await db.update_transaction(
                transaction_id=transaction_id,
                user_id=current_user["id"],
                amount=amount,  # Let the db_service handle the conversion
                category=category,
                description=description
            )
            
            if not success:
                logging.warning(f"Transaction with ID {transaction_id} not found or does not belong to user {current_user['id']}")
                raise HTTPException(
                    status_code=404,
                    detail=f"Transaction with ID {transaction_id} not found or does not belong to the current user"
                )
        except ValueError as e:
            # Handle value errors (e.g., invalid amount format)
            logging.error(f"Value error updating transaction: {e}")
            raise HTTPException(
                status_code=400,
                detail=str(e)
            )
        except Exception as e:
            # Handle other database errors
            logging.error(f"Database error updating transaction: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"An error occurred while updating the transaction: {str(e)}"
            )
        
        # Get updated daily summary
        daily_summary = await db.get_transactions_by_period(current_user["id"], 'daily')
        total_today = sum(daily_summary.values())
        
        response = {
            "success": True,
            "message": f"Transaction with ID {transaction_id} updated successfully",
            "total_today": total_today,
            "expense_info": {
                "total_amount": total_today,
                "categories": daily_summary
            }
        }
        
        return response
    except HTTPException:
        raise
    except Exception as e:
        
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update transaction: {str(e)}"
        )

@router.post("/transactions/delete", response_model=Dict)
async def delete_transaction(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Delete an existing transaction.
    
    Required fields in request:
    - transaction_id: ID of the transaction to delete
    """
    try:
        # Log the request
        logging.info(f"Delete transaction request: {request}")
        
        # Extract transaction_id from request body
        transaction_id = request.get("transaction_id")
        
        # Validate required parameters
        if not transaction_id:
            logging.warning("Missing transaction_id in delete request")
            raise HTTPException(
                status_code=400,
                detail="transaction_id is required"
            )
            
        # Log the transaction_id type and value for debugging
        logging.debug(f"Transaction ID type: {type(transaction_id)}, value: {transaction_id}")
        
        try:
            # Delete the transaction from the database
            success = await db.delete_transaction(
                transaction_id=transaction_id,
                user_id=current_user["id"]
            )
            
            if not success:
                logging.warning(f"Transaction with ID {transaction_id} not found or does not belong to user {current_user['id']}")
                raise HTTPException(
                    status_code=404,
                    detail=f"Transaction with ID {transaction_id} not found or does not belong to the current user"
                )
        except Exception as e:
            # Handle database errors
            logging.error(f"Database error deleting transaction: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"An error occurred while deleting the transaction: {str(e)}"
            )
        
        # Get updated daily summary
        daily_summary = await db.get_transactions_by_period(current_user["id"], 'daily')
        total_today = sum(daily_summary.values())
        
        response = {
            "success": True,
            "message": f"Transaction with ID {transaction_id} deleted successfully",
            "total_today": total_today,
            "expense_info": {
                "total_amount": total_today,
                "categories": daily_summary
            }
        }

        return response
    except HTTPException:
        raise
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete transaction: {str(e)}"
        )

@router.get("/daily-total")
async def get_daily_total(
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """Get the total amount spent today"""
    try:
        # Get transactions for today
        transactions = await db.get_raw_transactions(
            user_id=current_user["id"],
            period="daily"
        )
        
        # Calculate total
        total = sum(float(tx.get("amount", 0)) for tx in transactions)
        
        # Get category breakdown
        daily_summary = await db.get_transactions_by_period(current_user["id"], 'daily')
        
        return {
            "success": True,
            "total": total,
            "expense_info": {
                "total_amount": total,
                "categories": daily_summary
            }
        }
    except Exception as e:

        return {
            "success": False,
            "error": str(e),
            "total": 0,
            "expense_info": {
                "total_amount": 0,
                "categories": {}
            }
        }

@router.post("/daily-total")
async def post_daily_total(
    request: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """Get the total amount spent today via POST"""
    try:
        # Extract user_id from request if provided
        user_id = request.get("user_id", current_user["id"])
        
        # Get transactions for today
        transactions = await db.get_raw_transactions(
            user_id=user_id,
            period="daily"
        )
        
        # Calculate total
        total = sum(float(tx.get("amount", 0)) for tx in transactions)
        
        # Get category breakdown
        daily_summary = await db.get_transactions_by_period(user_id, 'daily')
        
        return {
            "success": True,
            "total": total,
            "expense_info": {
                "total_amount": total,
                "categories": daily_summary
            }
        }
    except Exception as e:

        return {
            "success": False,
            "error": str(e),
            "total": 0,
            "expense_info": {
                "total_amount": 0,
                "categories": {}
            }
        }

@router.post("/query")
async def query_expenses(request: ChatRequest):
    """Handle expense queries"""
    try:
        # Ensure user_id is present
        if not request.user_id:
            return {
                "response": "No user ID provided",
                "success": False,
                "expense_info": {
                    "is_query_response": True,
                    "total_amount": 0,
                    "categories": {}
                }
            }
        
        # Process the query using the BudgetTool
        tool = BudgetTool()
        response = await tool.handle_query(request)
        
        return response
    except Exception as e:

        return {
            "response": f"Error querying expenses: {str(e)}",
            "success": False,
            "expense_info": {
                "is_query_response": True,
                "total_amount": 0,
                "categories": {}
            }
        }

@router.get("/summary")
async def get_summary(token=Depends(verify_firebase_token)):
    """Get expense summary for the user"""
    user_id = token["uid"]
    tool = BudgetTool()
    request = ChatRequest(message="show me my expenses today", user_id=user_id)
    return await tool.handle_query(request)

@router.post("/budget-analysis")
async def get_budget_analysis(
    request: Request,
    month: Optional[str] = None,
    monthly_salary: Optional[float] = None,
    token: dict = Depends(verify_firebase_token),
    db = Depends(get_db)
):
    """
    Get budget analysis for the specified month.
    If month is not provided, the current month is used.
    """
    try:
        user_id = token["uid"]
        
        # If month is not provided, use the current month
        if not month:
            current_date = datetime.now()
            month = current_date.strftime("%m")
        
        # Get the budget analysis tool
        analysis_tool = BudgetAnalysisTool(db)
        
        # Get the analysis
        analysis = await analysis_tool.analyze_budget(
            user_id=user_id,
            month=month,
            monthly_salary=monthly_salary
        )
        
        return analysis
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to get budget analysis: {str(e)}"
        )

@router.get("/budget-analysis")
async def get_budget_analysis_get(
    period: str = "monthly",
    month: Optional[str] = None,
    monthly_salary: Optional[float] = None,
    token: dict = Depends(verify_firebase_token),
    db = Depends(get_db)
):
    """
    Get budget analysis for the specified month via GET.
    If month is not provided, the current month is used.
    """
    try:
        user_id = token["uid"]
        
        # If month is not provided, use the current month
        if not month:
            current_date = datetime.now()
            month = current_date.strftime("%m")
        
        # Get the budget analysis tool
        analysis_tool = BudgetAnalysisTool(db)
        
        # Get the analysis
        analysis = await analysis_tool.analyze_budget(
            user_id=user_id,
            month=month,
            monthly_salary=monthly_salary
        )
        
        return analysis
    except Exception as e:
        print(f"Error in budget-analysis GET handler: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get budget analysis: {str(e)}"
        )

@router.get("/recommendations")
async def get_budget_recommendations(
    month: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_db)
):
    """
    Get budget recommendations based on spending patterns.
    """
    try:
        # If month is not provided, use the current month
        if not month:
            current_date = datetime.now()
            month = current_date.strftime("%m")
        
        # Get the budget analysis tool
        analysis_tool = BudgetAnalysisTool(db)
        
        # Get recommendations
        recommendations = await analysis_tool.get_recommendations(
            user_id=current_user["id"],
            month=month
        )
        
        return recommendations
    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Failed to get budget recommendations: {str(e)}"
        )