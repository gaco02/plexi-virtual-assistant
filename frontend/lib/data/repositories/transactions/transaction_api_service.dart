import 'dart:async';
import '../../../services/api_service.dart';

class TransactionApiService {
  final ApiService _apiService;

  TransactionApiService(this._apiService);

  String? getCurrentUserId() {
    return _apiService.getCurrentUserId();
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    return await _apiService.post(endpoint, data);
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _apiService.get(endpoint, queryParameters: queryParameters);
  }

  Future<dynamic> logTransaction(
      String userId, double amount, String category, String description) async {
    final transactionData = {
      'user_id': userId,
      'amount': amount,
      'category': category,
      'description': description,
    };

    return await _apiService.post('/budget/transactions/add', transactionData);
  }

  Future<dynamic> updateTransaction(
      String userId, String id, double amount, String category, String description) async {
    return await _apiService.post('/budget/transactions/update', {
      'user_id': userId,
      'transaction_id': id,
      'amount': amount,
      'category': category,
      'description': description,
    });
  }

  Future<dynamic> deleteTransaction(String userId, String id) async {
    return await _apiService.post('/budget/transactions/delete', {
      'user_id': userId,
      'transaction_id': id,
    });
  }

  Future<dynamic> getDailyTransactions(String userId) async {
    return await _apiService.post('/budget/transactions', {
      'user_id': userId,
      'period': 'daily',
    });
  }

  Future<dynamic> getTransactionsByPeriod(
      String userId, String period, bool forceRefresh) async {
    return await _apiService.post('/budget/transactions', {
      'user_id': userId,
      'period': period,
      'force_refresh': forceRefresh,
    });
  }

  Future<dynamic> getDailyTotal(String userId, bool forceRefresh) async {
    return await _apiService.post('/budget/daily-total', {
      'user_id': userId,
      'force_refresh': forceRefresh,
    });
  }

  Future<dynamic> getTransactionAnalysis(
      String userId, Map<String, dynamic> queryParams) async {
    return await _apiService.post(
      '/budget/budget-analysis',
      queryParams,
    );
  }

  Future<dynamic> getTransactionHistory(
      String userId, String period, String? date, bool forceRefresh) async {
    final payload = {
      'user_id': userId,
      'period': period,
      'force_refresh': forceRefresh,
    };

    if (date != null && date.isNotEmpty) {
      payload['date'] = date;
    }

    return await _apiService.post('/budget/transactions', payload);
  }
}