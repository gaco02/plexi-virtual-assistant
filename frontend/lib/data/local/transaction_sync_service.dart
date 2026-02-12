import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/transactions/transaction_command_repository.dart';
import 'network_connectivity_service.dart';

/// Service responsible for synchronizing offline transactions when connectivity is restored
class TransactionSyncService {
  final TransactionCommandRepository _commandRepository;
  final NetworkConnectivityService _connectivityService;

  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  /// Singleton instance
  static TransactionSyncService? _instance;

  /// Factory constructor to return the singleton instance
  factory TransactionSyncService({
    TransactionCommandRepository? commandRepository,
    NetworkConnectivityService? connectivityService,
  }) {
    _instance ??= TransactionSyncService._internal(
      commandRepository: commandRepository,
      connectivityService: connectivityService,
    );
    return _instance!;
  }

  TransactionSyncService._internal({
    TransactionCommandRepository? commandRepository,
    NetworkConnectivityService? connectivityService,
  })  : _commandRepository = commandRepository!,
        _connectivityService =
            connectivityService ?? NetworkConnectivityService();

  /// Initialize the sync service and start listening for connectivity changes
  void initialize() {
    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivityService.connectionStatus.listen((isConnected) {
      if (isConnected) {
        // When connectivity is restored, attempt to sync
        syncTransactions();
      }
    });

    // Set up periodic sync attempts every 15 minutes when online
    _periodicSyncTimer =
        Timer.periodic(const Duration(minutes: 15), (timer) async {
      final isConnected = await _connectivityService.checkConnectivity();
      if (isConnected) {
        syncTransactions();
      }
    });
  }

  /// Manually trigger a sync attempt
  Future<void> syncTransactions() async {
    try {
      await _commandRepository.syncOfflineTransactions();
    } catch (e) {
      debugPrint('Error syncing transactions: $e');
    }
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }
}
