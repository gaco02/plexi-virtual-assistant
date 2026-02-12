import 'dart:async';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../local/network_connectivity_service.dart';
import '../../local/transaction_local_data_source.dart';
import 'transaction_api_service.dart';
import 'transaction_cache.dart';

/// Repository responsible for read operations on transactions
class TransactionQueryRepository {
  final TransactionApiService _apiService;
  final TransactionCache _cache;
  final TransactionLocalDataSource _localDataSource;
  final NetworkConnectivityService _connectivityService;

  TransactionQueryRepository(
    this._apiService,
    this._cache, {
    TransactionLocalDataSource? localDataSource,
    NetworkConnectivityService? connectivityService,
  })  : _localDataSource = localDataSource ?? TransactionLocalDataSource(),
        _connectivityService =
            connectivityService ?? NetworkConnectivityService();

  /// Helper method to convert dynamic data to Transaction objects
  List<Transaction> _convertToTransactions(List<dynamic> data) {
    final transactions = <Transaction>[];
    for (var tx in data) {
      try {
        if (tx is Transaction) {
          transactions.add(tx);
        } else if (tx is Map<String, dynamic>) {
          transactions.add(Transaction.fromJson(tx));
        }
      } catch (e) {
        // Continue with next transaction
      }
    }
    return transactions;
  }

  /// Get daily transactions for the current user
  Future<List<Transaction>> getDailyTransactions(
      {bool forceRefresh = false}) async {
    try {
      // Generate cache key
      final cacheKey = 'daily_transactions';

      // If forcing refresh, invalidate cache
      if (forceRefresh) {
        _cache.invalidate(cacheKey);
      } else {
        // Check cache first if not forcing refresh
        final cachedData = await _cache.get<List<Transaction>>(cacheKey,
            maxAge: TransactionCache.shortCacheDuration);
        if (cachedData != null) {
          return cachedData;
        }
      }

      // Check if request is already in flight
      if (_cache.isRequestInFlight(cacheKey)) {
        // We can't return the future directly anymore, so we need to wait for it to complete
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _cache.isRequestInFlight(cacheKey);
        });

        // Now try to get from cache
        final cachedData = await _cache.get<List<Transaction>>(cacheKey);
        if (cachedData != null) {
          return cachedData;
        }
        // If not in cache, continue with the request
      }

      // Register this request as in flight
      final completer = Completer<List<Transaction>>();
      _cache.registerRequest(cacheKey, completer);

      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        _cache.completeRequest(cacheKey);
        return [];
      }

      // Check if we're online
      final isOnline = await _connectivityService.checkConnectivity();

      if (isOnline &&
          (forceRefresh || !(await _isCachedDataSufficient(userId, 'daily')))) {
        // Online: Get from API
        try {
          final response = await _apiService.post('/budget/transactions', {
            'user_id': userId,
            'period': 'daily',
            'force_refresh': forceRefresh,
          });

          // Handle both response formats: direct list or object with transactions key
          List<dynamic> transactionsList;
          if (response is List) {
            // Server returned a direct list
            transactionsList = response;
          } else if (response is Map<String, dynamic>) {
            // Server returned an object with a transactions key
            if (!response.containsKey('success') ||
                response['success'] != true) {
              _cache.completeRequest(cacheKey);
              return []; // Return empty list if response indicates failure
            }

            if (!response.containsKey('transactions')) {
              _cache.completeRequest(cacheKey);
              return []; // Return empty list if no transactions key
            }

            transactionsList = response['transactions'];
          } else {
            // Unexpected response format
            _cache.completeRequest(cacheKey);
            return [];
          }

          // Convert the dynamic list to a list of Transaction objects
          final transactions = _convertToTransactions(transactionsList);

          // Cache the result in memory
          _cache.set(cacheKey, transactions);

          // Also store in local database for offline access
          await _localDataSource.saveTransactions(transactions);

          _cache.completeRequest(cacheKey);
          return transactions;
        } catch (e) {
          // If API request fails, fall back to local database
          final transactions = await _localDataSource
              .getTransactionsByUserIdAndPeriod(userId, 'daily');
          _cache.set(cacheKey, transactions);
          _cache.completeRequest(cacheKey);
          return transactions;
        }
      } else {
        // Offline: Get from local database
        final transactions = await _localDataSource
            .getTransactionsByUserIdAndPeriod(userId, 'daily');
        _cache.set(cacheKey, transactions);
        _cache.completeRequest(cacheKey);
        return transactions;
      }
    } catch (e) {
      final cacheKey = 'daily_transactions';
      _cache.completeRequestWithError(cacheKey, e);
      return []; // Return empty list on error
    }
  }

  /// Get monthly transactions for the current user
  Future<List<Transaction>> getMonthlyTransactions(
      {bool forceRefresh = false}) async {
    try {
      // If forcing refresh, bypass cache and get fresh data
      if (forceRefresh) {
        final List<Transaction> transactions =
            await getTransactionsByPeriod('Month', forceRefresh: true);

        // Cache the result for future use
        _cache.set('monthly_transactions', transactions);
        return transactions;
      }

      // Check cache first if not forcing refresh
      final cachedData =
          await _cache.get<List<Transaction>>('monthly_transactions');
      if (cachedData != null) {
        return cachedData;
      }

      // Get fresh data
      final List<Transaction> transactions =
          await getTransactionsByPeriod('Month', forceRefresh: false);

      // Cache the result for future use
      _cache.set('monthly_transactions', transactions);
      return transactions;
    } catch (e) {
      // On error, try getting from local database
      try {
        final userId = _apiService.getCurrentUserId();
        if (userId != null) {
          return await _localDataSource.getTransactionsByUserIdAndPeriod(
              userId, 'monthly');
        }
      } catch (_) {}
      return [];
    }
  }

  /// Get transactions by period (day, week, month, year)
  Future<List<Transaction>> getTransactionsByPeriod(String period,
      {bool forceRefresh = false}) async {
    try {
      // Generate cache key
      final cacheKey = 'transactions_${period.toLowerCase()}';

      // If not forcing refresh, check cache first
      if (!forceRefresh) {
        final cachedData = await _cache.get<List<Transaction>>(cacheKey,
            maxAge: TransactionCache.mediumCacheDuration);
        if (cachedData != null) {
          return cachedData;
        }
      } else {
        // If forcing refresh, invalidate the cache
        _cache.invalidate(cacheKey);
      }

      // Check if request is already in flight
      if (_cache.isRequestInFlight(cacheKey)) {
        // We can't return the future directly anymore, so we need to wait for it to complete
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _cache.isRequestInFlight(cacheKey);
        });

        // Now try to get from cache
        final cachedData = await _cache.get<List<Transaction>>(cacheKey);
        if (cachedData != null) {
          return cachedData;
        }
        // If not in cache, continue with the request
      }

      // Register this request as in flight
      final completer = Completer<List<Transaction>>();
      _cache.registerRequest(cacheKey, completer);

      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        _cache.completeRequest(cacheKey);
        return [];
      }

      // Check if we're online
      final isOnline = await _connectivityService.checkConnectivity();
      final apiPeriod = _mapPeriodToApiFormat(period);

      if (isOnline &&
          (forceRefresh ||
              !(await _isCachedDataSufficient(userId, apiPeriod)))) {
        // Online and we need fresh data: Get from API
        try {
          final response = await _apiService.post('/budget/transactions', {
            'user_id': userId,
            'period': apiPeriod,
            'force_refresh': forceRefresh,
          });

          // Handle both response formats: direct list or object with transactions key
          List<dynamic> transactionsList;
          if (response is List) {
            // Server returned a direct list
            transactionsList = response;
          } else if (response is Map<String, dynamic>) {
            // Server returned an object with a transactions key
            if (!response.containsKey('success') ||
                response['success'] != true) {
              _cache.completeRequest(cacheKey);
              return []; // Return empty list if response indicates failure
            }

            if (!response.containsKey('transactions')) {
              _cache.completeRequest(cacheKey);
              return []; // Return empty list if no transactions key
            }

            transactionsList = response['transactions'] as List<dynamic>;
          } else {
            // Unexpected response format
            _cache.completeRequest(cacheKey);
            return [];
          }

          // Convert the dynamic list to a list of Transaction objects
          final transactions = _convertToTransactions(transactionsList);

          // Cache the result in memory
          _cache.set(cacheKey, transactions);

          // Also store in local database for offline access
          await _localDataSource.saveTransactions(transactions);

          _cache.completeRequest(cacheKey);
          return transactions;
        } catch (e) {
          // If API request fails, fall back to local database
          final transactions = await _localDataSource
              .getTransactionsByUserIdAndPeriod(userId, apiPeriod);
          _cache.set(cacheKey, transactions);
          _cache.completeRequest(cacheKey);
          return transactions;
        }
      } else {
        // Offline or we have sufficient data: Get from local database
        final transactions = await _localDataSource
            .getTransactionsByUserIdAndPeriod(userId, apiPeriod);
        _cache.set(cacheKey, transactions);
        _cache.completeRequest(cacheKey);
        return transactions;
      }
    } catch (e) {
      final cacheKey = 'transactions_${period.toLowerCase()}';
      _cache.completeRequestWithError(cacheKey, e);
      return []; // Return empty list on error
    }
  }

  /// Check if we have sufficient local data (prevent unnecessary API calls)
  Future<bool> _isCachedDataSufficient(String userId, String period) async {
    // Get local data for this period
    final localTransactions =
        await _localDataSource.getTransactionsByUserIdAndPeriod(userId, period);

    // If we have some data and not forcing refresh, consider it sufficient
    return localTransactions.isNotEmpty;
  }

  /// Get the daily total spent
  Future<double> getDailyTotal({bool forceRefresh = false}) async {
    try {
      // Check cache first, unless forceRefresh is true
      final cacheKey = 'daily_total';

      if (forceRefresh) {
        // Invalidate the cache if force refresh is requested
        _cache.invalidate(cacheKey);
      } else {
        final cachedData = await _cache.get<double>(cacheKey,
            maxAge: TransactionCache.shortCacheDuration);
        if (cachedData != null) {
          return cachedData;
        }
      }

      // Check if request is already in flight
      if (_cache.isRequestInFlight(cacheKey)) {
        // We can't return the future directly anymore, so we need to wait for it to complete
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _cache.isRequestInFlight(cacheKey);
        });

        // Now try to get from cache
        final cachedData = await _cache.get<double>(cacheKey);
        if (cachedData != null) {
          return cachedData;
        }
        // If not in cache, continue with the request
      }

      // Register this request as in flight
      final completer = Completer<double>();
      _cache.registerRequest(cacheKey, completer);

      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        _cache.completeRequest(cacheKey);
        return 0.0;
      }

      // Check if we're online
      final isOnline = await _connectivityService.checkConnectivity();

      if (isOnline && forceRefresh) {
        // Online and forcing refresh: Get from API
        try {
          final response = await _apiService.post('/budget/daily-total', {
            'user_id': userId,
            'force_refresh': forceRefresh,
          });

          // Handle both response formats
          double result = 0.0;
          if (response is Map<String, dynamic>) {
            if (response.containsKey('total')) {
              result = (response['total'] as num).toDouble();
            } else if (response.containsKey('success') &&
                response['success'] == false) {
              result = 0.0;
            }
          } else {
            // If we got here, try to calculate the total from daily transactions
            try {
              final transactions = await getDailyTransactions();
              if (transactions.isNotEmpty) {
                double total = 0.0;
                for (var tx in transactions) {
                  total += tx.amount;
                }
                result = total;
              }
            } catch (e) {}
          }

          // Cache the result
          _cache.set(cacheKey, result);
          _cache.completeRequest(cacheKey);
          return result;
        } catch (e) {
          // If API fails, calculate from local database
          final dailyTotal = await _localDataSource.getTotalByPeriod('daily');
          _cache.set(cacheKey, dailyTotal);
          _cache.completeRequest(cacheKey);
          return dailyTotal;
        }
      } else {
        // Offline or not forcing refresh: Calculate from local database
        final dailyTotal = await _localDataSource.getTotalByPeriod('daily');
        _cache.set(cacheKey, dailyTotal);
        _cache.completeRequest(cacheKey);
        return dailyTotal;
      }
    } catch (e) {
      final cacheKey = 'daily_total';
      _cache.completeRequestWithError(cacheKey, e);
      return 0.0; // Return 0 on error
    }
  }

  /// Get transaction history grouped by date
  Future<Map<String, List<Transaction>>> getTransactionHistory(
      [String? period, String? date, bool forceRefresh = false]) async {
    try {
      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        return {};
      }

      // Convert UI period to API period format
      String apiPeriod;
      switch (period?.toLowerCase()) {
        case 'week':
          apiPeriod = 'weekly';
          break;
        case 'month':
          apiPeriod = 'monthly';
          break;
        case 'year':
          apiPeriod = 'yearly';
          break;
        case 'day':
          apiPeriod = 'daily';
          break;
        default:
          apiPeriod = 'daily';
      }

      // Generate cache key
      final cacheKey = 'transaction_history_${apiPeriod}_${date ?? "current"}';

      // If forceRefresh is true, invalidate the cache first
      if (forceRefresh) {
        _cache.invalidate(cacheKey);
      } else {
        // Check cache first if not forcing a refresh
        final cachedData = await _cache.get<Map<String, List<Transaction>>>(
            cacheKey,
            maxAge: TransactionCache.mediumCacheDuration);

        if (cachedData != null) {
          return cachedData;
        }
      }

      // Register this request as in flight
      if (_cache.isRequestInFlight(cacheKey)) {
        // Wait for the existing request to complete
        final completer = Completer<Map<String, List<Transaction>>>();
        _cache.registerRequest(cacheKey, completer);
        return completer.future;
      }

      // Register this request as in flight
      final completer = Completer<Map<String, List<Transaction>>>();
      _cache.registerRequest(cacheKey, completer);

      // Check if we're online
      final isOnline = await _connectivityService.checkConnectivity();

      List<Transaction> transactions;

      if (isOnline && forceRefresh) {
        // Online and forcing refresh: Get from API
        try {
          // Prepare request payload
          final payload = {
            'user_id': userId,
            'period': apiPeriod,
            'force_refresh': forceRefresh,
          };

          // Add date parameter if provided
          if (date != null && date.isNotEmpty) {
            payload['date'] = date;
          }

          final response =
              await _apiService.post('/budget/transactions', payload);

          // Handle both response formats: direct list or object with transactions key
          List<dynamic> transactionsList;
          if (response is List) {
            // Server returned a direct list
            transactionsList = response;
          } else if (response is Map<String, dynamic>) {
            // Server returned an object with a transactions key
            if (response.containsKey('transactions')) {
              transactionsList = response['transactions'];
            } else {
              _cache.completeRequest(cacheKey);
              completer.complete({});
              return {}; // Return empty map if no transactions key
            }
          } else {
            // Unexpected response format
            _cache.completeRequest(cacheKey);
            completer.complete({});
            return {};
          }

          // Convert to Transaction objects
          transactions = _convertToTransactions(transactionsList);

          // Save to local database
          await _localDataSource.saveTransactions(transactions);
        } catch (e) {
          // If API fails, get from local database
          transactions = await _localDataSource
              .getTransactionsByUserIdAndPeriod(userId, apiPeriod);
        }
      } else {
        // Offline or not forcing refresh: Get from local database
        transactions = await _localDataSource.getTransactionsByUserIdAndPeriod(
            userId, apiPeriod);
      }

      // Group transactions by date
      final Map<String, List<Transaction>> transactionsByDate = {};

      for (var transaction in transactions) {
        // Format date as key
        final dateKey = DateFormat('yyyy-MM-dd').format(transaction.timestamp);

        if (!transactionsByDate.containsKey(dateKey)) {
          transactionsByDate[dateKey] = [];
        }

        transactionsByDate[dateKey]!.add(transaction);
      }

      // Cache the result
      _cache.set(cacheKey, transactionsByDate);

      // Complete the request
      _cache.completeRequest(cacheKey);
      completer.complete(transactionsByDate);

      return transactionsByDate;
    } catch (e) {
      // Generate cache key for error handling
      final cacheKey =
          'transaction_history_${period ?? "daily"}_${date ?? "current"}';
      _cache.completeRequestWithError(cacheKey, e);

      return {}; // Return empty map on error
    }
  }

  // Helper method to convert UI period to API period format
  String _mapPeriodToApiFormat(String period) {
    if (period.contains('Month')) {
      return 'monthly';
    } else if (period.contains('Year')) {
      return 'yearly';
    } else if (period.contains('Week')) {
      return 'weekly';
    } else {
      return 'daily';
    }
  }
}
