import '../data/models/transaction.dart';
import '../data/models/transaction_analysis.dart';

/// Service for fast local budget calculations
class BudgetCalculationService {
  /// Calculate transaction allocation from a list of transactions
  static TransactionAllocation calculateAllocation(
      List<Transaction> transactions) {
    double needs = 0.0;
    double wants = 0.0;
    double savings = 0.0;

    for (final transaction in transactions) {
      final amount = transaction.amount;

      switch (transaction.category) {
        // Needs categories
        case TransactionCategory.housing:
        case TransactionCategory.groceries:
        case TransactionCategory.transport:
          needs += amount;
          break;

        // Savings categories
        case TransactionCategory.savingsAndInvestments:
          savings += amount;
          break;

        // Wants categories (everything else)
        case TransactionCategory.entertainment:
        case TransactionCategory.dining:
        case TransactionCategory.shopping:
        case TransactionCategory.other:
          wants += amount;
          break;
      }
    }

    return TransactionAllocation(
      needs: needs,
      wants: wants,
      savings: savings,
    );
  }

  /// Calculate allocation from chat transaction data
  static TransactionAllocation calculateAllocationFromChatData(
    List<Map<String, dynamic>> chatTransactions,
  ) {
    double needs = 0.0;
    double wants = 0.0;
    double savings = 0.0;

    for (final txData in chatTransactions) {
      final amount = (txData['amount'] as num?)?.toDouble() ?? 0.0;
      final categoryStr = txData['category'] as String? ?? 'other';

      // Convert string category to enum
      final category = TransactionCategoryExtension.fromString(categoryStr);

      switch (category) {
        // Needs categories
        case TransactionCategory.housing:
        case TransactionCategory.groceries:
        case TransactionCategory.transport:
          needs += amount;
          break;

        // Savings categories
        case TransactionCategory.savingsAndInvestments:
          savings += amount;
          break;

        // Wants categories (everything else)
        case TransactionCategory.entertainment:
        case TransactionCategory.dining:
        case TransactionCategory.shopping:
        case TransactionCategory.other:
          wants += amount;
          break;
      }
    }

    return TransactionAllocation(
      needs: needs,
      wants: wants,
      savings: savings,
    );
  }

  /// Merge two allocations (add amounts together)
  static TransactionAllocation mergeAllocations(
    TransactionAllocation base,
    TransactionAllocation addition,
  ) {
    return TransactionAllocation(
      needs: base.needs + addition.needs,
      wants: base.wants + addition.wants,
      savings: base.savings + addition.savings,
    );
  }
}
