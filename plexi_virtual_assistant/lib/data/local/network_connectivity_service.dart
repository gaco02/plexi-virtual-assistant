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
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    // Consider connected if any connection type is available
    _isConnected = result.isNotEmpty &&
        !result.every((element) => element == ConnectivityResult.none);
    _connectionStatusController.add(_isConnected);
  }

  /// Check current connectivity state
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result.isNotEmpty &&
        !result.every((element) => element == ConnectivityResult.none);
  }

  /// Clean up resources
  void dispose() {
    _connectionStatusController.close();
  }
}
