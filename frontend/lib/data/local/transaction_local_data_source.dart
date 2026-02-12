import '../models/transaction.dart';
import '../models/transaction_analysis.dart';
import 'database_helper.dart';

/// Class responsible for all local database operations related to transactions
class TransactionLocalDataSource {
  final DatabaseHelper _databaseHelper;

  TransactionLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper();

  // Transaction operations
  Future<void> saveTransaction(Transaction transaction) async {
    await _databaseHelper.insertTransaction(transaction);
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    await _databaseHelper.insertTransactions(transactions);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _databaseHelper.updateTransaction(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await _databaseHelper.deleteTransaction(id);
  }

  Future<Transaction?> getTransaction(String id) async {
    return _databaseHelper.getTransaction(id);
  }

  Future<List<Transaction>> getAllTransactions() async {
    return _databaseHelper.getAllTransactions();
  }

  Future<List<Transaction>> getTransactionsByPeriod(String period) async {
    return _databaseHelper.getTransactionsByPeriod(period);
  }

  Future<List<Transaction>> getTransactionsByUserIdAndPeriod(
      String userId, String period) async {
    return _databaseHelper.getTransactionsByUserIdAndPeriod(userId, period);
  }

  Future<double> getTotalByPeriod(String period) async {
    return _databaseHelper.getTotalByPeriod(period);
  }

  // Category totals operations
  Future<Map<TransactionCategory, double>> getCategoryTotals(
      String period) async {
    // Try to get cached totals first
    final cachedTotals = await _databaseHelper.getCachedCategoryTotals(period);

    if (cachedTotals != null) {
      return cachedTotals;
    }

    // If no cached totals, calculate them and cache the result
    final calculatedTotals = await _databaseHelper.getCategoryTotals(period);
    await _databaseHelper.saveCategoryTotals(period, calculatedTotals);

    return calculatedTotals;
  }

  // Transaction analysis operations
  Future<TransactionAnalysis?> getCachedTransactionAnalysis(
      String period, String date) async {
    return _databaseHelper.getTransactionAnalysis(period, date);
  }

  Future<void> saveTransactionAnalysis(
      TransactionAnalysis analysis, String period, String date) async {
    await _databaseHelper.saveTransactionAnalysis(analysis, period, date);
  }

  Future<bool> isAnalysisCacheStale(
      String period, String date, Duration maxAge) async {
    return _databaseHelper.isAnalysisCacheStale(period, date, maxAge);
  }

  // Sync queue operations
  Future<void> addToSyncQueue(String id, String entityType, String operation,
      Map<String, dynamic> data) async {
    await _databaseHelper.addToSyncQueue(id, entityType, operation, data);
  }

  Future<List<Map<String, dynamic>>> getSyncQueue({int maxAttempts = 3}) async {
    return _databaseHelper.getSyncQueue(maxAttempts: maxAttempts);
  }

  Future<void> updateSyncAttempt(String id, bool success) async {
    await _databaseHelper.updateSyncAttempt(id, success);
  }
}
