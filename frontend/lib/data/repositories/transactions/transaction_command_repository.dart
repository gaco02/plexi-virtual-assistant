import 'dart:async';
import 'dart:math';
import '../../models/transaction.dart';
import '../../local/network_connectivity_service.dart';
import '../../local/transaction_local_data_source.dart';
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
  final TransactionLocalDataSource _localDataSource;
  final NetworkConnectivityService _connectivityService;

  // Track if we're currently invalidating caches to prevent redundant calls
  bool _isInvalidatingCaches = false;

  TransactionCommandRepository(
    this._apiService,
    this._cache,
    this._queryRepository,
    this._analysisRepository, {
    TransactionLocalDataSource? localDataSource,
    NetworkConnectivityService? connectivityService,
  })  : _localDataSource = localDataSource ?? TransactionLocalDataSource(),
        _connectivityService =
            connectivityService ?? NetworkConnectivityService();

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

      // Check if online
      final isOnline = await _connectivityService.checkConnectivity();

      if (isOnline) {
        // Online: Send to server immediately
        try {
          // Send the transaction to the server
          await _apiService.post('/budget/transactions/add', transactionData);

          // Invalidate caches
          invalidateTransactionCaches();

          // Force refresh transactions
          await _queryRepository.getMonthlyTransactions(forceRefresh: true);

          // Force refresh analysis
          _analysisRepository.forceRefreshAnalysis().then((_) {});

          // Refresh daily total
          await _queryRepository.getDailyTotal(forceRefresh: true);
        } catch (e) {
          // If server call fails, fall back to offline mode
          await _handleOfflineTransaction('add', transactionData);
        }
      } else {
        // Offline: Save locally and queue for sync
        await _handleOfflineTransaction('add', transactionData);
      }
    } catch (e) {
      throw Exception('Failed to log transaction: $e');
    }
  }

  /// Handle an offline transaction
  Future<void> _handleOfflineTransaction(
      String operation, Map<String, dynamic> data) async {
    try {
      String id;

      if (operation == 'add') {
        // Generate a temporary local ID for new transactions
        id =
            'local_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
        data['id'] = id;

        // Create a Transaction object from the data
        final transaction = Transaction(
          id: id,
          userId: data['user_id'],
          amount: data['amount'] is num
              ? (data['amount'] as num).toDouble()
              : double.parse(data['amount'].toString()),
          category: TransactionCategoryExtension.fromString(
              data['category'].toString()),
          description: data['description'].toString(),
          timestamp: DateTime.now(),
          source: 'offline',
        );

        // Save to local database
        await _localDataSource.saveTransaction(transaction);

        // Add to sync queue for future synchronization
        await _localDataSource.addToSyncQueue(
            id, 'transaction', operation, data);
      } else if (operation == 'update' && data.containsKey('transaction_id')) {
        id = data['transaction_id'];

        // Get existing transaction
        final existingTransaction = await _localDataSource.getTransaction(id);

        if (existingTransaction != null) {
          // Update transaction with new data
          final updatedTransaction = Transaction(
            id: id,
            userId: existingTransaction.userId,
            amount: data['amount'] is num
                ? (data['amount'] as num).toDouble()
                : double.parse(data['amount'].toString()),
            category: TransactionCategoryExtension.fromString(
                data['category'].toString()),
            description: data['description'].toString(),
            timestamp: existingTransaction.timestamp,
            source: existingTransaction.source,
            merchant: existingTransaction.merchant,
            metadata: existingTransaction.metadata,
          );

          // Update in local database
          await _localDataSource.updateTransaction(updatedTransaction);

          // Add to sync queue for future synchronization
          await _localDataSource.addToSyncQueue(
              id, 'transaction', operation, data);
        }
      } else if (operation == 'delete' && data.containsKey('transaction_id')) {
        id = data['transaction_id'];

        // Delete from local database
        await _localDataSource.deleteTransaction(id);

        // Add to sync queue for future synchronization
        await _localDataSource.addToSyncQueue(
            id, 'transaction', operation, data);
      }

      // Invalidate caches to reflect local changes
      invalidateTransactionCaches();
    } catch (e) {
      throw Exception('Failed to process offline transaction: $e');
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

      // Prepare the transaction data
      final transactionData = {
        'user_id': userId,
        'transaction_id': id,
        'amount': amount,
        'category': cleanCategory,
        'description': description,
      };

      // Check if online
      final isOnline = await _connectivityService.checkConnectivity();

      if (isOnline) {
        // Online: Update on server
        try {
          final response = await _apiService.post(
              '/budget/transactions/update', transactionData);

          // Check if the update was successful
          if (response is Map<String, dynamic> && response['success'] == true) {
            // Also update in local database
            final transaction = await _localDataSource.getTransaction(id);
            if (transaction != null) {
              final updatedTransaction = Transaction(
                id: id,
                userId: userId,
                amount: amount,
                category:
                    TransactionCategoryExtension.fromString(cleanCategory),
                description: description,
                timestamp: transaction.timestamp,
                merchant: transaction.merchant,
                source: transaction.source,
                metadata: transaction.metadata,
              );

              await _localDataSource.updateTransaction(updatedTransaction);
            }

            // Invalidate caches
            invalidateTransactionCaches();
            return true;
          } else {
            // If server update failed, try offline mode
            await _handleOfflineTransaction('update', transactionData);
            return true;
          }
        } catch (e) {
          // If server call fails, fall back to offline mode
          await _handleOfflineTransaction('update', transactionData);
          return true;
        }
      } else {
        // Offline: Update locally and queue for sync
        await _handleOfflineTransaction('update', transactionData);
        return true;
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

      // Prepare the deletion data
      final deletionData = {
        'user_id': userId,
        'transaction_id': id,
      };

      // Check if online
      final isOnline = await _connectivityService.checkConnectivity();

      if (isOnline) {
        // Online: Delete on server
        try {
          final response = await _apiService.post(
              '/budget/transactions/delete', deletionData);

          // Check if the deletion was successful
          if (response is Map<String, dynamic> && response['success'] == true) {
            // Also delete from local database
            await _localDataSource.deleteTransaction(id);

            // Invalidate caches
            invalidateTransactionCaches();
            return true;
          } else {
            // If server deletion failed, try offline mode
            await _handleOfflineTransaction('delete', deletionData);
            return true;
          }
        } catch (e) {
          // If server call fails, fall back to offline mode
          await _handleOfflineTransaction('delete', deletionData);
          return true;
        }
      } else {
        // Offline: Delete locally and queue for sync
        await _handleOfflineTransaction('delete', deletionData);
        return true;
      }
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  /// Add a transaction with custom data
  Future<Transaction> addTransaction(
      Map<String, dynamic> transactionData) async {
    try {
      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      // Add user_id to transaction data if not present
      if (!transactionData.containsKey('user_id')) {
        transactionData['user_id'] = userId;
      }

      // Check if online
      final isOnline = await _connectivityService.checkConnectivity();

      if (isOnline) {
        // Online: Add on server
        try {
          final response = await _apiService.post(
              '/budget/transactions/add', transactionData);

          if (response == null) {
            throw Exception('Failed to add transaction: Invalid response');
          }

          // Handle both response formats
          Transaction transaction;

          if (response is Map<String, dynamic>) {
            if (response.containsKey('transaction')) {
              transaction = Transaction.fromJson(response['transaction']);
            } else if (response.containsKey('success') &&
                response['success'] == true) {
              // Create a basic transaction from the request data
              transaction = Transaction(
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
            } else {
              throw Exception(
                  'Failed to add transaction: Response indicates failure');
            }
          } else {
            throw Exception(
                'Failed to add transaction: Invalid response format');
          }

          // Save transaction to local database
          await _localDataSource.saveTransaction(transaction);

          // Invalidate caches
          invalidateTransactionCaches();

          return transaction;
        } catch (e) {
          // If server call fails, fall back to offline mode
          return await _addTransactionOffline(transactionData);
        }
      } else {
        // Offline: Add locally and queue for sync
        return await _addTransactionOffline(transactionData);
      }
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  /// Add a transaction offline
  Future<Transaction> _addTransactionOffline(
      Map<String, dynamic> transactionData) async {
    // Generate a temporary local ID
    final localId =
        'local_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    transactionData['id'] = localId;

    // Create a Transaction object
    final transaction = Transaction(
      id: localId,
      userId: transactionData['user_id'],
      amount: transactionData['amount'] is num
          ? (transactionData['amount'] as num).toDouble()
          : double.parse(transactionData['amount'].toString()),
      category: TransactionCategoryExtension.fromString(
          transactionData['category'].toString()),
      description: transactionData['description'].toString(),
      timestamp: DateTime.now(),
      source: 'offline',
    );

    // Save to local database
    await _localDataSource.saveTransaction(transaction);

    // Add to sync queue
    await _localDataSource.addToSyncQueue(
        localId, 'transaction', 'add', transactionData);

    // Invalidate caches
    invalidateTransactionCaches();

    return transaction;
  }

  /// Synchronize offline transactions with the server
  Future<void> syncOfflineTransactions() async {
    // Check if online
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      return; // Can't sync if offline
    }

    // Get items from sync queue
    final syncItems = await _localDataSource.getSyncQueue();

    // Process each item
    for (var item in syncItems) {
      final id = item['id'];
      final entityType = item['entity_type'];
      final operation = item['operation'];
      final data = item['data'];

      if (entityType != 'transaction') continue; // Skip non-transaction items

      try {
        if (operation == 'add') {
          // For 'add' operations, remove the local ID from data
          if (id.toString().startsWith('local_')) {
            data.remove('id');
          }

          // Send to server
          final response =
              await _apiService.post('/budget/transactions/add', data);

          if (response != null &&
              (response is Map<String, dynamic> &&
                  response['success'] == true)) {
            // Mark as synced
            await _localDataSource.updateSyncAttempt(id, true);

            // If server returned a new ID, update the local record
            if (response is Map<String, dynamic> &&
                response.containsKey('transaction') &&
                response['transaction'] is Map<String, dynamic>) {
              final serverTransaction =
                  Transaction.fromJson(response['transaction']);

              // Get local transaction
              final localTransaction =
                  await _localDataSource.getTransaction(id);

              if (localTransaction != null) {
                // Delete the old record with local ID
                await _localDataSource.deleteTransaction(id);

                // Add new record with server ID
                await _localDataSource.saveTransaction(serverTransaction);
              }
            }
          } else {
            // Mark as failed
            await _localDataSource.updateSyncAttempt(id, false);
          }
        } else if (operation == 'update') {
          // Send to server
          final response =
              await _apiService.post('/budget/transactions/update', data);

          // Mark sync status
          await _localDataSource.updateSyncAttempt(
              id,
              response != null &&
                  response is Map<String, dynamic> &&
                  response['success'] == true);
        } else if (operation == 'delete') {
          // Send to server
          final response =
              await _apiService.post('/budget/transactions/delete', data);

          // Mark sync status
          await _localDataSource.updateSyncAttempt(
              id,
              response != null &&
                  response is Map<String, dynamic> &&
                  response['success'] == true);
        }
      } catch (e) {
        // Mark sync attempt as failed
        await _localDataSource.updateSyncAttempt(id, false);
      }
    }

    // Refresh data if any items were synced
    if (syncItems.isNotEmpty) {
      invalidateTransactionCaches();
      await _queryRepository.getMonthlyTransactions(forceRefresh: true);
      _analysisRepository.forceRefreshAnalysis().then((_) {});
    }
  }

  /// Method to invalidate all caches when a new transaction is added
  void invalidateTransactionCaches() {
    // Prevent redundant invalidations
    if (_isInvalidatingCaches) {
      return;
    }

    _isInvalidatingCaches = true;

    try {
      _cache.invalidateTransactionCaches();

      // IMPORTANT: Also invalidate the analysis cache to ensure it gets refreshed
      _cache.invalidate('transaction_analysis_current');

      // Force refresh the analysis data
      _analysisRepository.forceRefreshAnalysis().then((analysis) {});
    } finally {
      _isInvalidatingCaches = false;
    }
  }
}
