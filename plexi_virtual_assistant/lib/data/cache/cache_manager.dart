import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A cache manager that supports both in-memory caching and persistent storage
/// using SharedPreferences to ensure data availability even offline
class CacheManager {
  // Singleton pattern
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // In-memory cache data with timestamps
  final Map<String, _CacheEntry> _memoryCache = {};

  // In-flight requests to prevent duplicate calls
  final Map<String, Completer<dynamic>> _inFlightRequests = {};

  // SharedPreferences instance
  SharedPreferences? _prefs;
  bool _initialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Initialize the cache manager with SharedPreferences
  Future<void> init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      _initCompleter.complete();
    } catch (e) {
      _initCompleter.completeError(e);
    }
  }

  /// Ensure the cache manager is initialized before performing operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
      return _initCompleter.future;
    }
  }

  /// Get data from cache if it exists and is not expired
  /// Tries memory cache first, then falls back to persistent cache
  Future<T?> get<T>(String key, {Duration? maxAge}) async {
    await _ensureInitialized();

    // First check memory cache
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null) {
      // Check if memory cache is expired
      if (maxAge != null) {
        final age = DateTime.now().difference(memoryEntry.timestamp);
        if (age > maxAge) {
          // Memory cache expired, try persistent cache
          return _getFromPersistentCache<T>(key, maxAge);
        }
      }

      // Return the data without attempting to cast it
      // The caller will handle type conversion as needed
      return memoryEntry.data as dynamic;
    }

    // If not in memory, try persistent cache
    return _getFromPersistentCache<T>(key, maxAge);
  }

  /// Get data from persistent cache (SharedPreferences)
  Future<T?> _getFromPersistentCache<T>(String key, Duration? maxAge) async {
    if (_prefs == null) return null;

    // Check if we have the data and timestamp in persistent storage
    final jsonData = _prefs!.getString('cache_data_$key');
    final timestampMillis = _prefs!.getInt('cache_timestamp_$key');

    if (jsonData == null || timestampMillis == null) return null;

    // Check if cache is expired
    if (maxAge != null) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      final age = DateTime.now().difference(timestamp);
      if (age > maxAge) {
        return null;
      }
    }

    try {
      final data = json.decode(jsonData);

      // Also update memory cache
      _memoryCache[key] = _CacheEntry(
          data, DateTime.fromMillisecondsSinceEpoch(timestampMillis));

      // Return the data without attempting to cast it
      // The caller will handle type conversion as needed
      return data as dynamic;
    } catch (e) {
      return null;
    }
  }

  /// Set data in both memory cache and persistent storage
  Future<void> set<T>(String key, T data) async {
    await _ensureInitialized();

    // Update memory cache
    _memoryCache[key] = _CacheEntry(data, DateTime.now());

    // Update persistent cache if possible
    if (_prefs != null && data != null) {
      try {
        final jsonData = json.encode(data);
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        await _prefs!.setString('cache_data_$key', jsonData);
        await _prefs!.setInt('cache_timestamp_$key', timestamp);
      } catch (e) {}
    }
  }

  /// Clear specific cache entry from both memory and persistent storage
  Future<void> invalidate(String key) async {
    await _ensureInitialized();

    // Clear from memory
    _memoryCache.remove(key);

    // Clear from persistent storage
    if (_prefs != null) {
      await _prefs!.remove('cache_data_$key');
      await _prefs!.remove('cache_timestamp_$key');
    }
  }

  /// Clear all cache from both memory and persistent storage
  Future<void> invalidateAll() async {
    await _ensureInitialized();

    // Clear memory cache
    _memoryCache.clear();

    // Clear all cache entries from persistent storage
    if (_prefs != null) {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_data_') ||
            key.startsWith('cache_timestamp_')) {
          await _prefs!.remove(key);
        }
      }
    }
  }

  /// Check if a request with the same key is already in flight
  bool isRequestInFlight(String key) {
    return _inFlightRequests.containsKey(key);
  }

  /// Register an in-flight request
  void registerRequest<T>(String key, Completer<T> completer) {
    _inFlightRequests[key] = completer;
  }

  /// Complete and remove an in-flight request
  void completeRequest(String key) {
    _inFlightRequests.remove(key);
  }

  /// Complete an in-flight request with an error
  void completeRequestWithError(String key, dynamic error) {
    final completer = _inFlightRequests[key];
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _inFlightRequests.remove(key);
  }
}

/// Private class to store cache entries with timestamps
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);
}
