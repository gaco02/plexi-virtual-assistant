import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A service to monitor and provide network connectivity information
class NetworkConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  /// Stream for listening to connectivity changes
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  /// Current connectivity state
  bool _isConnected = true;

  /// Returns whether the device is currently connected to the internet
  bool get isConnected => _isConnected;

  NetworkConnectivityService() {
    // Initialize connectivity monitoring
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  /// Initialize connectivity service and get initial connection status
  Future<void> _initConnectivity() async {
    List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      // Default to connected if we can't determine status
      _isConnected = true;
      _connectionStatusController.add(_isConnected);
    }
  }

  /// Update connection status based on connectivity result
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Consider connected if any connection type is available (not none)
    _isConnected = results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);
    _connectionStatusController.add(_isConnected);
  }

  /// Check current connectivity state
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    // Consider connected if any connection type is available
    return results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);
  }

  /// Clean up resources
  void dispose() {
    _connectionStatusController.close();
  }
}
