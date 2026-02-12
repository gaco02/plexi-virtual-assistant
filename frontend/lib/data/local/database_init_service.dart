import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'transaction_sync_service.dart';
import '../repositories/transactions/transaction_command_repository.dart';

/// Service to initialize all database-related components
class DatabaseInitService {
  static Future<void> initialize({
    TransactionCommandRepository? commandRepository,
  }) async {
    try {
      // Initialize database - this will create tables if needed
      final db = DatabaseHelper();
      await db.database; // This triggers database initialization

      debugPrint('SQLite database initialized successfully');

      // Initialize sync service if command repository is provided
      if (commandRepository != null) {
        final syncService = TransactionSyncService(
          commandRepository: commandRepository,
        );
        syncService.initialize();
        debugPrint('Transaction sync service initialized');
      }
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }
}
