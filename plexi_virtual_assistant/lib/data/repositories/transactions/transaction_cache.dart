import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cache/cache_manager.dart';
import '../../models/transaction.dart';
import '../../models/transaction_analysis.dart';

class TransactionCache {
  final CacheManager _cacheManager = CacheManager();

  // Key for storing the last analysis refresh timestamp
  static const String _lastAnalysisRefreshKey =
      'last_analysis_refresh_timestamp';

  // Cache durations that can be used by the repository
  static const Duration shortCacheDuration = Duration(minutes: 2);
  static const Duration mediumCacheDuration = Duration(minutes: 5);
  static const Duration longCacheDuration = Duration(minutes: 15);

  // Check if a request is already in flight
  bool isRequestInFlight(String cacheKey) {
    return _cacheManager.isRequestInFlight(cacheKey);
  }

  // Register a request as in flight
  void registerRequest<T>(String cacheKey, Completer<T> completer) {
    _cacheManager.registerRequest(cacheKey, completer);
  }

  // Complete a request
  void completeRequest(String cacheKey) {
    _cacheManager.completeRequest(cacheKey);
  }

  // Complete a request with error
  void completeRequestWithError(String cacheKey, dynamic error) {
    _cacheManager.completeRequestWithError(cacheKey, error);
  }

  // Get data from cache with proper type conversion
  Future<T?> get<T>(String cacheKey, {Duration? maxAge}) async {
    final dynamic data = await _cacheManager.get(cacheKey, maxAge: maxAge);

    if (data == null) {
      return null;
    }

    // Handle specific type conversions
    if (T == List<Transaction>) {
      if (data is List<Transaction>) {
        return data as T;
      } else if (data is List) {
        try {
          final convertedList = <Transaction>[];
          for (var item in data) {
            if (item is Transaction) {
              convertedList.add(item);
            } else if (item is Map<String, dynamic>) {
              convertedList.add(Transaction.fromJson(item));
            }
          }
          return convertedList as T;
        } catch (e) {
          return null;
        }
      }
      return null;
    } else if (T == TransactionAnalysis) {
      if (data is TransactionAnalysis) {
        return data as T;
      } else if (data is Map<String, dynamic>) {
        try {
          return TransactionAnalysis.fromJson(data) as T;
        } catch (e) {
          return null;
        }
      }
      return null;
    } else if (T == Map<String, List<Transaction>>) {
      if (data is Map<String, List<Transaction>>) {
        return data as T;
      } else if (data is Map) {
        try {
          final convertedMap = <String, List<Transaction>>{};
          for (var entry in data.entries) {
            if (entry.value is List) {
              final convertedList = <Transaction>[];
              for (var item in entry.value) {
                if (item is Transaction) {
                  convertedList.add(item);
                } else if (item is Map<String, dynamic>) {
                  convertedList.add(Transaction.fromJson(item));
                }
              }
              convertedMap[entry.key.toString()] = convertedList;
            }
          }
          return convertedMap as T;
        } catch (e) {
          return null;
        }
      }
      return null;
    } else if (T == double) {
      if (data is double) {
        return data as T;
      } else if (data is num) {
        return data.toDouble() as T;
      } else if (data is String) {
        try {
          return double.parse(data) as T;
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // For other types, try a direct cast
    try {
      return data as T;
    } catch (e) {
      return null;
    }
  }

  // Set data in cache
  void set<T>(String cacheKey, T data) {
    _cacheManager.set(cacheKey, data);
  }

  // Invalidate cache
  void invalidate(String cacheKey) {
    _cacheManager.invalidate(cacheKey);
  }

  // Invalidate all transaction-related caches
  void invalidateTransactionCaches() {
    _cacheManager.invalidate('daily_transactions');
    _cacheManager.invalidate('monthly_transactions');
    _cacheManager.invalidate('daily_total');
    _cacheManager.invalidate('transactions_month');
    _cacheManager.invalidate('transactions_day');
    _cacheManager.invalidate('transactions_week');
    _cacheManager.invalidate('transactions_year');

    // IMPORTANT: Also invalidate the analysis cache to ensure it gets refreshed
    // Previous comment: "Don't invalidate the monthly analysis cache to preserve monthly view"
    // This was causing the needs/wants/savings values to not update

    _cacheManager.invalidate('transaction_analysis_current');
  }

  // Checks if the analysis data should be refreshed based on time
  Future<bool> shouldRefreshAnalysis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefreshTimestamp = prefs.getInt(_lastAnalysisRefreshKey);

      // If no timestamp exists, we should refresh
      if (lastRefreshTimestamp == null) {
        return true;
      }

      final lastRefreshTime =
          DateTime.fromMillisecondsSinceEpoch(lastRefreshTimestamp);
      final now = DateTime.now();

      // Check if it's a new day since the last refresh
      final isNewDay = lastRefreshTime.day != now.day ||
          lastRefreshTime.month != now.month ||
          lastRefreshTime.year != now.year;

      return isNewDay;
    } catch (e) {
      // On error, assume we should refresh
      return true;
    }
  }

  // Updates the timestamp of the last analysis refresh
  Future<void> updateLastAnalysisRefreshTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt(_lastAnalysisRefreshKey, now.millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail if we can't update the timestamp
    }
  }
}
