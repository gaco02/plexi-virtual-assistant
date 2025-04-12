import 'dart:async';
import '../../models/transaction.dart';
import 'transaction_api_service.dart';
import 'transaction_cache.dart';
import 'transaction_query_repository.dart';
import 'transaction_analysis_repository.dart';

/// Repository responsible for write operations on transactions
class TransactionCommandRepository {
  final TransactionApiService _apiService;
  final TransactionCache _cache;
  final TransactionQueryRepository _queryRepository;
  final TransactionAnalysisRepository _analysisRepository;

  // Track if we're currently invalidating caches to prevent redundant calls
  bool _isInvalidatingCaches = false;

  TransactionCommandRepository(
    this._apiService, 
    this._cache, 
    this._queryRepository,
    this._analysisRepository,
  );

  /// Helper method to clean category strings
  String _cleanCategoryString(String category) {
    // If the category starts with the enum prefix, remove it
    if (category.startsWith('TransactionCategory.')) {
      return category.substring('TransactionCategory.'.length);
    }
    return category;
  }

  /// Log a new transaction
  Future<void> logTransaction(
      double amount, String category, String description) async {
    try {
      // Clean the category string to remove any enum prefix
      final cleanCategory = _cleanCategoryString(category);

      print(
          '📝 [TransactionCommandRepository] Logging transaction: $amount, $cleanCategory, $description');

      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      // Prepare the transaction data
      final transactionData = {
        'user_id': userId,
        'amount': amount,
        'category': cleanCategory,
        'description': description,
      };

      // Send the transaction to the server
      await _apiService.post('/budget/transactions/add', transactionData);
      print('✅ [TransactionCommandRepository] Transaction logged successfully');

      // Invalidate all transaction-related caches except monthly analysis
      print('🗑️ [TransactionCommandRepository] Invalidating transaction caches');
      invalidateTransactionCaches();

      // Force refresh the monthly transactions to ensure up-to-date categories
      print(
          '🔄 [TransactionCommandRepository] Force refreshing monthly data after logging transaction');
      await _queryRepository.getMonthlyTransactions(forceRefresh: true);

      // Force refresh the analysis data to ensure it includes the new transaction
      // but don't await it to avoid blocking the UI
      print(
          '🔄 [TransactionCommandRepository] Refreshing analysis data in background');
      _analysisRepository.forceRefreshAnalysis().then((analysis) {
        print(
            '✅ [TransactionCommandRepository] Analysis data refreshed after transaction logged');
        print('📊 [TransactionCommandRepository] Updated analysis data: needs=${analysis.actual.needs}, wants=${analysis.actual.wants}, savings=${analysis.actual.savings}');
      });

      // Also refresh the daily total
      await _queryRepository.getDailyTotal(forceRefresh: true);
    } catch (e) {
      print('❌ [TransactionCommandRepository] Error logging transaction: $e');
      throw Exception('Failed to log transaction: $e');
    }
  }

  /// Update an existing transaction
  Future<bool> updateTransaction(
      String id, double amount, String category, String description) async {
    try {
      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      // Clean category string if it has the enum prefix
      final cleanCategory = _cleanCategoryString(category);

      final response = await _apiService.post('/budget/transactions/update', {
        'user_id': userId,
        'transaction_id': id,
        'amount': amount,
        'category': cleanCategory,
        'description': description,
      });

      // Check if the update was successful
      if (response is Map<String, dynamic> && response['success'] == true) {
        // Invalidate transaction caches to ensure we get fresh data
        invalidateTransactionCaches();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  /// Delete a transaction
  Future<bool> deleteTransaction(String id) async {
    try {
      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      final response = await _apiService.post('/budget/transactions/delete', {
        'user_id': userId,
        'transaction_id': id,
      });

      // Check if the deletion was successful
      if (response is Map<String, dynamic> && response['success'] == true) {
        // Invalidate transaction caches to ensure we get fresh data
        invalidateTransactionCaches();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  /// Add a transaction with custom data
  Future<Transaction> addTransaction(
      Map<String, dynamic> transactionData) async {
    try {
      // Invalidate transaction caches
      invalidateTransactionCaches();

      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      // Add user_id to transaction data if not present
      if (!transactionData.containsKey('user_id')) {
        transactionData['user_id'] = userId;
      }

      final response =
          await _apiService.post('/budget/transactions/add', transactionData);

      if (response == null) {
        throw Exception('Failed to add transaction: Invalid response');
      }

      // Handle both response formats
      if (response is Map<String, dynamic>) {
        if (response.containsKey('transaction')) {
          return Transaction.fromJson(response['transaction']);
        } else if (response.containsKey('success') &&
            response['success'] == true) {
          // Create a basic transaction from the request data
          return Transaction(
            id: response['id'] ??
                'temp-${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            amount: transactionData['amount'] is num
                ? (transactionData['amount'] as num).toDouble()
                : double.parse(transactionData['amount'].toString()),
            category: TransactionCategoryExtension.fromString(
                transactionData['category'].toString()),
            description: transactionData['description'].toString(),
            timestamp: DateTime.now(),
          );
        }
      }

      throw Exception('Failed to add transaction: Invalid response format');
    } catch (e) {
      print('❌ [TransactionCommandRepository] Error adding transaction: $e');
      throw Exception('Failed to add transaction: $e');
    }
  }

  /// Method to invalidate all caches when a new transaction is added
  void invalidateTransactionCaches() {
    // Prevent redundant invalidations
    if (_isInvalidatingCaches) {
      print(
          '🔄 [TransactionCommandRepository] Cache invalidation already in progress, skipping');
      return;
    }

    _isInvalidatingCaches = true;

    try {
      print('🗑️ [TransactionCommandRepository] Invalidating transaction caches');
      _cache.invalidateTransactionCaches();
      
      // IMPORTANT: Also invalidate the analysis cache to ensure it gets refreshed
      print('🗑️ [TransactionCommandRepository] Explicitly invalidating analysis cache');
      _cache.invalidate('transaction_analysis_current');
      
      // Force refresh the analysis data
      print('🔄 [TransactionCommandRepository] Triggering analysis refresh');
      _analysisRepository.forceRefreshAnalysis().then((analysis) {
        print('✅ [TransactionCommandRepository] Analysis refreshed with new values:');
        print('  - needs: ${analysis.actual.needs}');
        print('  - wants: ${analysis.actual.wants}');
        print('  - savings: ${analysis.actual.savings}');
      });
    } finally {
      _isInvalidatingCaches = false;
    }
  }
}
