import 'dart:async';
import '../../models/transaction.dart';
import '../../models/transaction_analysis.dart';
import '../../local/transaction_local_data_source.dart';
import '../../local/network_connectivity_service.dart';
import 'transaction_api_service.dart';
import 'transaction_cache.dart';
import 'transaction_query_repository.dart';
import 'transaction_command_repository.dart';
import 'transaction_analysis_repository.dart';

/// Main repository that serves as a facade for all transaction operations
class TransactionRepository {
  final TransactionApiService _apiService;
  final TransactionCache _cache;
  final TransactionLocalDataSource _localDataSource;
  final NetworkConnectivityService _connectivityService;

  // Specialized repositories
  late final TransactionQueryRepository _queryRepository;
  late final TransactionAnalysisRepository _analysisRepository;
  late final TransactionCommandRepository _commandRepository;

  // Expose command repository for the sync service
  TransactionCommandRepository get commandRepository => _commandRepository;

  TransactionRepository(
    this._apiService,
    this._cache, {
    TransactionLocalDataSource? localDataSource,
    NetworkConnectivityService? connectivityService,
  })  : _localDataSource = localDataSource ?? TransactionLocalDataSource(),
        _connectivityService =
            connectivityService ?? NetworkConnectivityService() {
    // Initialize specialized repositories with offline support
    _queryRepository = TransactionQueryRepository(_apiService, _cache,
        localDataSource: _localDataSource,
        connectivityService: _connectivityService);

    _analysisRepository = TransactionAnalysisRepository(_apiService, _cache);

    _commandRepository = TransactionCommandRepository(
        _apiService, _cache, _queryRepository, _analysisRepository,
        localDataSource: _localDataSource,
        connectivityService: _connectivityService);
  }

  // ===== Command Operations =====

  /// Log a new transaction
  Future<void> logTransaction(
      double amount, String category, String description) {
    return _commandRepository.logTransaction(amount, category, description);
  }

  /// Update an existing transaction
  Future<bool> updateTransaction(
      String id, double amount, String category, String description) {
    return _commandRepository.updateTransaction(
        id, amount, category, description);
  }

  /// Delete a transaction
  Future<bool> deleteTransaction(String id) {
    return _commandRepository.deleteTransaction(id);
  }

  /// Add a transaction with custom data
  Future<Transaction> addTransaction(Map<String, dynamic> transactionData) {
    return _commandRepository.addTransaction(transactionData);
  }

  /// Synchronize offline transactions with the server
  Future<void> syncOfflineTransactions() {
    return _commandRepository.syncOfflineTransactions();
  }

  // ===== Query Operations =====

  /// Get daily transactions for the current user
  Future<List<Transaction>> getDailyTransactions({bool forceRefresh = false}) {
    return _queryRepository.getDailyTransactions(forceRefresh: forceRefresh);
  }

  /// Get monthly transactions for the current user
  Future<List<Transaction>> getMonthlyTransactions(
      {bool forceRefresh = false}) {
    return _queryRepository.getMonthlyTransactions(forceRefresh: forceRefresh);
  }

  /// Get transactions by period (day, week, month, year)
  Future<List<Transaction>> getTransactionsByPeriod(String period,
      {bool forceRefresh = false}) {
    return _queryRepository.getTransactionsByPeriod(period,
        forceRefresh: forceRefresh);
  }

  /// Get the daily total spent
  Future<double> getDailyTotal({bool forceRefresh = false}) {
    return _queryRepository.getDailyTotal(forceRefresh: forceRefresh);
  }

  /// Get transaction history grouped by date
  Future<Map<String, List<Transaction>>> getTransactionHistory(
      [String? period, String? date, bool forceRefresh = false]) {
    return _queryRepository.getTransactionHistory(period, date, forceRefresh);
  }

  // ===== Analysis Operations =====

  /// Get transaction analysis data for the current month or specified month
  Future<TransactionAnalysis> getTransactionAnalysis([String? month]) {
    return _analysisRepository.getTransactionAnalysis(month);
  }

  /// Force a refresh of the transaction analysis
  Future<TransactionAnalysis> forceRefreshAnalysis([String? month]) {
    return _analysisRepository.forceRefreshAnalysis(month);
  }

  // ===== Utility Methods =====

  /// Invalidate all transaction-related caches
  void invalidateTransactionCaches() {
    _commandRepository.invalidateTransactionCaches();
  }

  /// Check if the device is currently online
  Future<bool> isOnline() {
    return _connectivityService.checkConnectivity();
  }

  /// Get a stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityService.connectionStatus;
}
