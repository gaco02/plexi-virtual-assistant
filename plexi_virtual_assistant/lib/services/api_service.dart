import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  final String baseUrl;
  final _client = http.Client();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Token caching
  String? _cachedToken;
  DateTime? _tokenExpiry;

  // Request throttling
  DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(milliseconds: 300);

  // Request counter for debugging
  int _requestCount = 0;

  // Getter for request count (for debugging)
  int get requestCount => _requestCount;

  ApiService({required this.baseUrl});

  /// Get the current user ID from Firebase Auth
  String? getCurrentUserId() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🔍 ApiService: No current user found');
        return null;
      }
      print('✅ ApiService: Current user ID: ${user.uid}');
      return user.uid;
    } catch (e) {
      print('❌ ApiService: Error getting current user: $e');
      return null;
    }
  }

  /// Get a valid token, using cached token when possible
  Future<String> _getValidToken() async {
    final now = DateTime.now();
    print('🔍 ApiService: Getting valid token');

    // If we have a valid cached token that's not expired, use it
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!)) {
      print(
          '🔍 ApiService: Using cached token (expires in ${_tokenExpiry!.difference(now).inMinutes} minutes)');
      return _cachedToken!;
    }

    try {
      final user = _auth.currentUser;
      print('🔍 ApiService: Checking current user for token');

      if (user == null) {
        print('❌ ApiService: User not authenticated for token request');
        throw Exception('User not authenticated');
      }
      print(
          '🔍 ApiService: User authenticated: ${user.email ?? 'No email'} (${user.uid})');

      // Get a fresh token with forceRefresh=false to reduce Firebase calls
      // Only force refresh if we don't have a token or it's expired
      final forceRefresh = _cachedToken == null ||
          (_tokenExpiry != null && now.isAfter(_tokenExpiry!));
      final token = await user.getIdToken(forceRefresh);

      if (token == null) {
        throw Exception('Failed to get token');
      }

      // Cache the token with an expiry time (1 hour is typical for Firebase tokens)
      _cachedToken = token;
      _tokenExpiry = now.add(const Duration(
          minutes: 55)); // Set expiry slightly before actual expiry

      print(
          '✅ ApiService: Successfully obtained new token, expires in 55 minutes');
      return token;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    print('🔍 ApiService: GET request to $endpoint');
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      if (queryParameters != null) {
        uri = uri.replace(
            queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        ));
      }

      final headers = await _getHeaders();

      // Apply request throttling
      await _throttleRequest();

      final response = await _client.get(
        uri,
        headers: headers,
      );

      if (response.statusCode == 401) {
        // Try one more time with a fresh token
        _cachedToken = null; // Force token refresh
        final newHeaders = await _getHeaders();

        // Apply throttling again
        await _throttleRequest();

        final retryResponse = await _client.get(
          uri,
          headers: newHeaders,
        );

        if (retryResponse.statusCode == 200) {
          return _decodeResponse(retryResponse.bodyBytes);
        } else {
          throw Exception(
              'API request failed after retry with status: ${retryResponse.statusCode}');
        }
      }

      if (response.statusCode == 200) {
        return _decodeResponse(response.bodyBytes);
      } else {
        // For 500 errors, try to decode and log the response body to get more details
        String errorDetails = 'No details';
        try {
          if (response.body.isNotEmpty) {
            errorDetails = response.body;
          }
        } catch (decodeError) {
          errorDetails = 'Could not access response body';
        }

        print(
            '❌ ApiService: Server error ${response.statusCode} details: $errorDetails');
        throw Exception(
            'API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool useFormData = false,
  }) async {
    print('🔍 ApiService: POST request to $endpoint');
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl$endpoint');

      // Apply request throttling
      await _throttleRequest();

      final response = await http.post(
        url,
        headers: headers,
        body: useFormData ? data : json.encode(data),
      );

      if (response.statusCode == 401) {
        // Try one more time with a fresh token
        _cachedToken = null; // Force token refresh
        final newHeaders = await _getHeaders();

        // Apply throttling again
        await _throttleRequest();

        final retryResponse = await http.post(
          url,
          headers: newHeaders,
          body: useFormData ? data : json.encode(data),
        );

        if (retryResponse.statusCode == 200 ||
            retryResponse.statusCode == 201) {
          return _decodeResponse(retryResponse.bodyBytes);
        } else {
          throw Exception(
              'API request failed after retry with status: ${retryResponse.statusCode}');
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeResponse(response.bodyBytes);
      } else if (response.statusCode == 404 || response.statusCode == 405) {
        // Try fallback to GET if POST fails with 404 or 405
        if (endpoint.contains('/summary') ||
            endpoint.contains('/transactions') ||
            endpoint.contains('/daily-total')) {
          return get(endpoint, queryParameters: data);
        }

        throw Exception(
            'API request failed with status: ${response.statusCode}');
      } else {
        // For 500 errors, try to decode and log the response body to get more details
        String errorDetails = 'No details';
        try {
          if (response.body.isNotEmpty) {
            errorDetails = response.body;
          }
        } catch (decodeError) {
          errorDetails = 'Could not access response body';
        }

        print(
            '❌ ApiService: Server error ${response.statusCode} details: $errorDetails');
        throw Exception(
            'API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> postWithErrorHandling(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await post(endpoint, data);
      return response;
    } catch (e) {
      // For certain endpoints like calories/entries/add, we know they might return 500
      // even though the operation succeeded
      if (endpoint.contains('calories/entries/add')) {
        print('📡 [ApiService] Handled expected error in $endpoint: $e');
        // Return a synthetic success response
        return {
          'success': true,
          'message': 'Entry likely added but response had errors'
        };
      }
      rethrow;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    try {
      final token = await _getValidToken();

      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Throttle requests to avoid hitting rate limits
  Future<void> _throttleRequest() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
    _requestCount++;
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    print('🔍 ApiService: PUT request to $endpoint');
    try {
      await _throttleRequest();

      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl$endpoint');

      final response = await _client.put(
        url,
        headers: headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return _decodeResponse(response.bodyBytes);
      } else {
        throw Exception('Failed to update data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      await _throttleRequest();

      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl$endpoint');

      final response = await _client.delete(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return _decodeResponse(response.bodyBytes);
      } else {
        throw Exception('Failed to delete data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to properly decode response with UTF-8 encoding
  dynamic _decodeResponse(List<int> bodyBytes) {
    // Use utf8.decode to properly handle UTF-8 characters
    String decodedBody = utf8.decode(bodyBytes);

    return json.decode(decodedBody);
  }
}
