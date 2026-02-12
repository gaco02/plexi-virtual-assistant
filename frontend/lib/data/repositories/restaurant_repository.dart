import '../models/restaurant.dart';
import '../../services/api_service.dart';
import 'dart:developer';
import 'dart:convert';

class RestaurantRepository {
  final ApiService _apiService;
  // Cache for restaurants to use as fallback
  List<Restaurant> _cachedRestaurants = [];

  RestaurantRepository(this._apiService);

  // Generate a deterministic ID from restaurant name
  int _generateId(String name) {
    // Use a hash of the name to generate a unique ID
    // We'll use the first 8 characters of the SHA-256 hash as a number
    final bytes = utf8.encode(name);
    final hash = base64.encode(bytes);
    final id = hash.codeUnits.take(8).fold<int>(0, (a, b) => a + b);
    return id.abs(); // Ensure positive ID
  }

  Future<List<Restaurant>> getRestaurants() async {
    try {
      final response = await _apiService.get('/restaurants');
      log('Restaurant response: $response');

      // Handle different response formats
      List<dynamic> restaurantList;
      if (response is List) {
        restaurantList = response;
      } else if (response is Map<String, dynamic> &&
          response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          restaurantList = data;
        } else {
          restaurantList = [data];
        }
      } else {
        restaurantList = [response];
      }

      // Convert to Restaurant objects and add generated IDs
      _cachedRestaurants = restaurantList.map((json) {
        // Generate ID from name if not provided
        if (!json.containsKey('id') || json['id'] == null) {
          json['id'] = _generateId(json['name'] ?? '');
        }
        return Restaurant.fromJson(json);
      }).toList();

      return _cachedRestaurants;
    } catch (e) {
      log('Error loading restaurants: $e');
      throw Exception('Failed to load restaurants: $e');
    }
  }

  Future<List<Restaurant>> getDailyRecommendations({int count = 3}) async {
    try {
      final response = await _apiService.get('/restaurants/daily',
          queryParameters: {'count': count.toString()});
      log('Daily recommendations response: $response');

      // Handle different response formats
      List<dynamic> restaurantList;
      if (response is List) {
        restaurantList = response;
      } else if (response is Map<String, dynamic> &&
          response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          restaurantList = data;
        } else {
          restaurantList = [data];
        }
      } else {
        restaurantList = [response];
      }

      // Convert to Restaurant objects and add generated IDs
      final restaurants = restaurantList.map((json) {
        // Generate ID from name if not provided
        if (!json.containsKey('id') || json['id'] == null) {
          json['id'] = _generateId(json['name'] ?? '');
        }
        return Restaurant.fromJson(json);
      }).toList();

      if (_cachedRestaurants.isEmpty) {
        _cachedRestaurants = restaurants;
      }
      return restaurants;
    } catch (e) {
      log('Error loading daily recommendations: $e');

      // If we have cached restaurants, use them as fallback
      if (_cachedRestaurants.isNotEmpty) {
        log('Using cached restaurants as fallback');
        return _cachedRestaurants.take(count).toList();
      }

      // If no cached restaurants, try to fetch all restaurants as fallback
      try {
        log('Attempting to fetch all restaurants as fallback');
        final allRestaurants = await getRestaurants();
        // Randomly select 'count' restaurants
        allRestaurants.shuffle();
        return allRestaurants.take(count).toList();
      } catch (fallbackError) {
        log('Error loading fallback restaurants: $fallbackError');
        throw Exception(
            'Failed to load daily recommendations and fallback failed: $e\nFallback error: $fallbackError');
      }
    }
  }

  Future<List<Restaurant>> getRestaurantsByCuisine(String cuisineType) async {
    try {
      final response =
          await _apiService.get('/restaurants/cuisine/$cuisineType');
      log('Restaurants by cuisine response: $response');

      // Handle different response formats
      List<dynamic> restaurantList;
      if (response is List) {
        restaurantList = response;
      } else if (response is Map<String, dynamic> &&
          response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          restaurantList = data;
        } else {
          restaurantList = [data];
        }
      } else {
        restaurantList = [response];
      }

      // Convert to Restaurant objects and add generated IDs
      return restaurantList.map((json) {
        // Generate ID from name if not provided
        if (!json.containsKey('id') || json['id'] == null) {
          json['id'] = _generateId(json['name'] ?? '');
        }
        return Restaurant.fromJson(json);
      }).toList();
    } catch (e) {
      log('Error loading restaurants by cuisine: $e');
      throw Exception('Failed to load restaurants by cuisine: $e');
    }
  }

  Future<List<Restaurant>> searchRestaurants(String query) async {
    try {
      final response = await _apiService.get('/restaurants/search/$query');
      log('Search restaurants response: $response');

      // Handle different response formats
      List<dynamic> restaurantList;
      if (response is List) {
        restaurantList = response;
      } else if (response is Map<String, dynamic> &&
          response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          restaurantList = data;
        } else {
          restaurantList = [data];
        }
      } else {
        restaurantList = [response];
      }

      // Convert to Restaurant objects and add generated IDs
      return restaurantList.map((json) {
        // Generate ID from name if not provided
        if (!json.containsKey('id') || json['id'] == null) {
          json['id'] = _generateId(json['name'] ?? '');
        }
        return Restaurant.fromJson(json);
      }).toList();
    } catch (e) {
      log('Error searching restaurants: $e');
      throw Exception('Failed to search restaurants: $e');
    }
  }

  Future<Restaurant> getRestaurantDetails(String id) async {
    try {
      log('Fetching restaurant details for ID: $id');

      // Try to find the restaurant in the cache first
      if (_cachedRestaurants.isNotEmpty) {
        try {
          final cachedRestaurant = _cachedRestaurants.firstWhere(
            (r) => r.id.toString() == id,
          );
          log('Found restaurant in cache: ${cachedRestaurant.name}');
          return cachedRestaurant;
        } catch (_) {
          log('Restaurant not found in cache');
        }
      }

      // If not in cache, try to fetch from API
      try {
        final response = await _apiService.get('/restaurants/$id');
        log('Restaurant details response: $response');

        // Handle different response formats
        Map<String, dynamic> restaurantData;
        if (response is Map<String, dynamic>) {
          if (response.containsKey('data')) {
            final data = response['data'];
            if (data is Map<String, dynamic>) {
              restaurantData = data;
            } else {
              throw Exception('Invalid restaurant data format');
            }
          } else {
            restaurantData = response;
          }
        } else if (response is List && response.isNotEmpty) {
          // If we got a list but expected a single item, take the first one
          final firstItem = response.first;
          if (firstItem is Map<String, dynamic>) {
            restaurantData = firstItem;
          } else {
            throw Exception('Invalid restaurant data format in list');
          }
        } else {
          throw Exception('Unexpected response format for restaurant details');
        }

        // Generate ID from name if not provided
        if (!restaurantData.containsKey('id') || restaurantData['id'] == null) {
          restaurantData['id'] = _generateId(restaurantData['name'] ?? '');
        }

        final restaurant = Restaurant.fromJson(restaurantData);

        // Update cache if this restaurant exists in it
        final index =
            _cachedRestaurants.indexWhere((r) => r.id == restaurant.id);
        if (index != -1) {
          _cachedRestaurants[index] = restaurant;
        }

        return restaurant;
      } catch (e) {
        log('API call failed: $e');
        throw Exception('Failed to load restaurant details: $e');
      }
    } catch (e) {
      log('Error loading restaurant details: $e');
      throw Exception('Failed to load restaurant details: $e');
    }
  }
}
