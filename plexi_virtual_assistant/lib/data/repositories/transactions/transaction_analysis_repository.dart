import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction_analysis.dart';
import 'transaction_api_service.dart';
import 'transaction_cache.dart';

/// Repository responsible for transaction analysis operations
class TransactionAnalysisRepository {
  final TransactionApiService _apiService;
  final TransactionCache _cache;

  TransactionAnalysisRepository(this._apiService, this._cache);

  /// Get transaction analysis data for the current month or specified month
  Future<TransactionAnalysis> getTransactionAnalysis([String? month]) async {
    try {
      // Generate cache key
      final cacheKey = 'transaction_analysis_${month ?? "current"}';

      // If we should use cached data or force a refresh
      final shouldRefresh = await _cache.shouldRefreshAnalysis();
      print(
          '🔄 [TransactionAnalysisRepository] Should refresh analysis: $shouldRefresh');

      // Check cache first if we're not forcing a refresh
      if (!shouldRefresh) {
        final cachedData = await _cache
            .get<TransactionAnalysis>(cacheKey, maxAge: TransactionCache.longCacheDuration);
        if (cachedData != null) {
          print('📋 [TransactionAnalysisRepository] Using cached analysis data');
          return cachedData;
        }
      } else {
        // If we should refresh, invalidate the cache
        _cache.invalidate(cacheKey);
        print('🗑️ [TransactionAnalysisRepository] Invalidated analysis cache');
      }

      // Check if request is already in flight
      if (_cache.isRequestInFlight(cacheKey)) {
        print(
            '⏳ [TransactionAnalysisRepository] Request for transaction analysis already in flight');
        // We can't return the future directly anymore, so we need to wait for it to complete
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _cache.isRequestInFlight(cacheKey);
        });

        // Now try to get from cache
        final cachedData =
            await _cache.get<TransactionAnalysis>(cacheKey);
        if (cachedData != null) {
          return cachedData;
        }
        // If not in cache, continue with the request
      }

      // Register this request as in flight
      final completer = Completer<TransactionAnalysis>();
      _cache.registerRequest(cacheKey, completer);

      // Get current user ID
      final userId = _apiService.getCurrentUserId();

      if (userId == null) {
        final defaultAnalysis = TransactionAnalysis(
          monthlySalary: 0.0,
          ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        );
        _cache.completeRequest(cacheKey);
        return defaultAnalysis;
      }

      // Add user_id to query parameters
      final queryParams = <String, dynamic>{
        'user_id': userId,
      };

      if (month != null) {
        queryParams['month'] = month;
      }

      // Get the monthly salary from the PreferencesBloc
      try {
        final prefs = await SharedPreferences.getInstance();
        final monthlySalary = prefs.getDouble('monthly_salary');
        if (monthlySalary != null) {
          queryParams['monthly_salary'] = monthlySalary;
        } else {}
      } catch (e) {}

      final response = await _apiService.post(
        '/budget/budget-analysis',
        queryParams,
      );

      // Check if response contains an error
      if (response is Map<String, dynamic>) {
        if (response.containsKey('error')) {
          // Return a default empty transaction analysis
          final defaultAnalysis = TransactionAnalysis(
            monthlySalary: 0.0,
            ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
            actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          );
          _cache.completeRequest(cacheKey);
          return defaultAnalysis;
        }

        if (response.containsKey('status') && response['status'] == 'error') {
          // Return a default empty transaction analysis
          final defaultAnalysis = TransactionAnalysis(
            monthlySalary: 0.0,
            ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
            actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          );
          _cache.completeRequest(cacheKey);
          return defaultAnalysis;
        }
      }

      final analysis = TransactionAnalysis.fromJson(response);

      print(
          '✅ [TransactionAnalysisRepository] Fetched fresh analysis data from server');

      // Cache the result
      _cache.set(cacheKey, analysis);
      _cache.completeRequest(cacheKey);

      // Update the last refresh timestamp
      await _cache.updateLastAnalysisRefreshTime();
      print('⏱️ [TransactionAnalysisRepository] Updated last refresh timestamp');

      return analysis;
    } catch (e) {
      print('❌ [TransactionAnalysisRepository] Error getting transaction analysis: $e');
      final cacheKey = 'transaction_analysis_${month ?? "current"}';

      // Return a default empty transaction analysis on error
      final defaultAnalysis = TransactionAnalysis(
        monthlySalary: 0.0,
        ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
      );

      _cache.completeRequestWithError(cacheKey, e);
      return defaultAnalysis;
    }
  }

  /// Force a refresh of the transaction analysis
  Future<TransactionAnalysis> forceRefreshAnalysis([String? month]) async {
    try {
      print(
          '🔄 [TransactionAnalysisRepository] Force refreshing analysis data for month: ${month ?? "current"}');

      // Generate cache key
      final cacheKey = 'transaction_analysis_${month ?? "current"}';

      // Invalidate the cache first
      _cache.invalidate(cacheKey);
      print(
          '🗑️ [TransactionAnalysisRepository] Invalidated analysis cache for force refresh');

      // Also invalidate transaction history caches to ensure fresh data
      _cache.invalidate('transaction_history_monthly_current');
      _cache.invalidate('transaction_history_daily_current');
      print(
          '🗑️ [TransactionAnalysisRepository] Also invalidated transaction history caches');

      // Check if a request is already in flight
      if (_cache.isRequestInFlight(cacheKey)) {
        print(
            '⏳ [TransactionAnalysisRepository] Request for analysis already in flight, waiting');
        // Wait for the existing request to complete
        final completer = Completer<TransactionAnalysis>();
        _cache.registerRequest(cacheKey, completer);
        return completer.future;
      }

      // Register this request as in flight
      final completer = Completer<TransactionAnalysis>();
      _cache.registerRequest(cacheKey, completer);

      // Get current user ID
      final userId = _apiService.getCurrentUserId();
      if (userId == null) {
        _cache.completeRequestWithError(
            cacheKey, Exception('No user ID available'));
        throw Exception('No user ID available');
      }

      // Prepare query parameters
      final queryParams = {
        'user_id': userId,
        'force_refresh': true,
      };

      // Add month parameter if provided
      if (month != null && month.isNotEmpty) {
        queryParams['month'] = month;
      }

      // Get the monthly salary from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final monthlySalary = prefs.getDouble('monthly_salary');
        if (monthlySalary != null) {
          queryParams['monthly_salary'] = monthlySalary;
          print('💰 [TransactionAnalysisRepository] Including monthly salary: $monthlySalary');
        }
      } catch (e) {
        print('⚠️ [TransactionAnalysisRepository] Error getting monthly salary: $e');
      }

      print(
          '🔄 [TransactionAnalysisRepository] Sending analysis request with payload: $queryParams');

      // Make the API request to the correct endpoint with POST method
      final response = await _apiService.post(
        '/budget/budget-analysis',
        queryParams,
      );

      print(
          '✅ [TransactionAnalysisRepository] Received analysis response: ${response.runtimeType}');
      print('📊 [TransactionAnalysisRepository] Analysis response content: $response');

      // Check if response contains an error
      if (response is Map<String, dynamic>) {
        if (response.containsKey('error') ||
            (response.containsKey('status') && response['status'] == 'error')) {
          print(
              '⚠️ [TransactionAnalysisRepository] Error in analysis response: ${response['error'] ?? response['message'] ?? "Unknown error"}');

          // Return a default empty transaction analysis
          final defaultAnalysis = TransactionAnalysis(
            monthlySalary: 0.0,
            ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
            actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          );

          // Complete the request and return the default analysis
          _cache.completeRequest(cacheKey);
          completer.complete(defaultAnalysis);
          return defaultAnalysis;
        }

        // Debug log the response contents
        if (response.containsKey('actual')) {
          print('📊 [TransactionAnalysisRepository] Analysis actual allocation:');
          final actual = response['actual'];
          if (actual is Map<String, dynamic>) {
            print('  - needs: ${actual['needs']}');
            print('  - wants: ${actual['wants']}');
            print('  - savings: ${actual['savings']}');
          }
        }

        // Parse the response into a TransactionAnalysis object
        try {
          final analysis = TransactionAnalysis.fromJson(response);

          // Log the parsed analysis data
          print('📊 [TransactionAnalysisRepository] Parsed analysis data:');
          print('  - monthlySalary: ${analysis.monthlySalary}');
          print(
              '  - ideal: needs=${analysis.ideal.needs}, wants=${analysis.ideal.wants}, savings=${analysis.ideal.savings}');
          print(
              '  - actual: needs=${analysis.actual.needs}, wants=${analysis.actual.wants}, savings=${analysis.actual.savings}');

          // Cache the analysis
          _cache.set(cacheKey, analysis);

          // Complete the request
          _cache.completeRequest(cacheKey);
          completer.complete(analysis);

          print(
              '✅ [TransactionAnalysisRepository] Successfully refreshed and cached analysis data');
          return analysis;
        } catch (e) {
          print(
              '❌ [TransactionAnalysisRepository] Error parsing analysis response: $e');

          // Return a default empty transaction analysis
          final defaultAnalysis = TransactionAnalysis(
            monthlySalary: 0.0,
            ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
            actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          );

          // Complete the request and return the default analysis
          _cache.completeRequest(cacheKey);
          completer.complete(defaultAnalysis);
          return defaultAnalysis;
        }
      } else {
        print(
            '❌ [TransactionAnalysisRepository] Unexpected response format: ${response.runtimeType}');

        // Return a default empty transaction analysis
        final defaultAnalysis = TransactionAnalysis(
          monthlySalary: 0.0,
          ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
          actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        );

        // Complete the request and return the default analysis
        _cache.completeRequest(cacheKey);
        completer.complete(defaultAnalysis);
        return defaultAnalysis;
      }
    } catch (e) {
      print('❌ [TransactionAnalysisRepository] Error refreshing analysis: $e');

      // Generate cache key for error handling
      final cacheKey = 'transaction_analysis_${month ?? "current"}';
      _cache.completeRequestWithError(cacheKey, e);

      // Return a default empty transaction analysis
      return TransactionAnalysis(
        monthlySalary: 0.0,
        ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
      );
    }
  }
}
