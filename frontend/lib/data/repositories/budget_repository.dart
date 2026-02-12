import '../models/budget_analysis.dart';
import '../../services/api_service.dart';
import '../models/transaction.dart';

class BudgetRepository {
  final ApiService apiService;

  BudgetRepository(this.apiService);

  Future<BudgetAnalysis> getBudgetAnalysis(
      [String? month, String period = 'monthly']) async {
    try {
      // Debug log

      // Get current user ID for debugging
      final userId = apiService.getCurrentUserId();

      final queryParams = <String, dynamic>{};

      // Only add month if it's not 'monthly' (which is causing the server error)
      if (month != null && month != 'monthly') {
        queryParams['month'] = month;
      }

      // Always add period
      queryParams['period'] = period;

      final response = await apiService.get(
        '/budget/analysis',
        queryParameters: queryParams,
      );
      // Debug log

      // Check if response contains an error
      if (response is Map<String, dynamic> && response.containsKey('error')) {
        // Return a default empty budget analysis
        return BudgetAnalysis(
          monthlySalary: 0.0,
          ideal: BudgetAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          actual: BudgetAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        );
      }

      return BudgetAnalysis.fromJson(response);
    } catch (e) {
      // Debug log
      // Return a default empty budget analysis instead of throwing
      return BudgetAnalysis(
        monthlySalary: 0.0,
        ideal: BudgetAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        actual: BudgetAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
      );
    }
  }

  Future<List<Transaction>> getDailyTransactions() async {
    try {
      // Debug log

      // Get current user ID
      final userId = apiService.getCurrentUserId();
      if (userId == null) {
        return [];
      }

      final response = await apiService.post('/budget/transactions', {
        'user_id': userId,
        'period': 'daily',
      });
      // Debug log

      if (response is Map<String, dynamic> &&
          response.containsKey('success') &&
          response['success'] == true &&
          response.containsKey('transactions')) {
        final List<dynamic> transactionData = response['transactions'];
        return transactionData
            .map((data) => Transaction.fromJson(data))
            .toList();
      }

      return [];
    } catch (e) {
      // Debug log
      return [];
    }
  }

  Future<double> getDailyTotal() async {
    try {
      // Debug log

      // Get current user ID
      final userId = apiService.getCurrentUserId();
      if (userId == null) {
        return 0.0;
      }

      final response = await apiService.post('/budget/daily-total', {
        'user_id': userId,
      });
      // Debug log

      if (response is Map<String, dynamic> &&
          response.containsKey('success') &&
          response['success'] == true &&
          response.containsKey('total')) {
        return (response['total'] as num).toDouble();
      }

      return 0.0;
    } catch (e) {
      // Debug log
      return 0.0;
    }
  }

  Future<bool> addTransaction(Transaction transaction) async {
    try {
      // Debug log

      // Get current user ID
      final userId = apiService.getCurrentUserId();
      if (userId == null) {
        return false;
      }

      final response = await apiService.post('/budget/transactions/add', {
        'user_id': userId,
        'description': transaction.description,
        'amount': transaction.amount,
        'category': transaction.category.name,
        'timestamp': transaction.timestamp.toIso8601String(),
        'merchant': transaction.merchant,
        'source': transaction.source,
        'metadata': transaction.metadata,
      });
      // Debug log

      return response is Map<String, dynamic> &&
          response.containsKey('success') &&
          response['success'] == true;
    } catch (e) {
      // Debug log
      return false;
    }
  }

  Future<List<Transaction>> getTransactionsByPeriod(String period,
      [String? month]) async {
    try {
      // Debug log

      // Get current user ID
      final userId = apiService.getCurrentUserId();
      if (userId == null) {
        return [];
      }

      final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'period': period,
      };

      if (month != null) {
        requestBody['month'] = month;
      }

      final response =
          await apiService.post('/budget/transactions', requestBody);
      // Debug log

      // Handle different response formats
      if (response is List) {
        // If response is a List, assume it's a list of transactions
        return response.map((data) => Transaction.fromJson(data)).toList();
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('success')) {}
        if (response.containsKey('transactions')) {
          // If response is a Map with transactions key, extract the transactions
          final List<dynamic> transactionData = response['transactions'];
          return transactionData
              .map((data) => Transaction.fromJson(data))
              .toList();
        }
      } else {}

      return [];
    } catch (e) {
      // Debug log
      return [];
    }
  }
}
