import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/transaction.dart';
import '../models/transaction_analysis.dart';
import '../models/calorie_entry.dart';

/// DatabaseHelper class handles all SQLite database operations
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static sqflite.Database? _database;

  // Private constructor
  DatabaseHelper._internal();

  /// Get the database instance, initializing it if needed
  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database, creating tables if they don't exist
  Future<sqflite.Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'plexi_transactions.db');

    return await sqflite.openDatabase(
      path,
      version: 2, // Increment version to trigger migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(sqflite.Database db, int version) async {
    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        category INTEGER NOT NULL,
        description TEXT NOT NULL,
        merchant TEXT,
        timestamp INTEGER NOT NULL,
        source TEXT DEFAULT 'chat',
        metadata TEXT
      )
    ''');

    // Create transaction analysis table (for caching analysis results)
    await db.execute('''
      CREATE TABLE transaction_analysis (
        id TEXT PRIMARY KEY,
        period TEXT NOT NULL,
        date TEXT NOT NULL, 
        needs_amount REAL NOT NULL,
        wants_amount REAL NOT NULL,
        savings_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        needs_percent REAL NOT NULL,
        wants_percent REAL NOT NULL,
        savings_percent REAL NOT NULL,
        last_updated INTEGER NOT NULL,
        monthly_salary REAL NOT NULL
      )
    ''');

    // Create category totals table (for caching category summaries)
    await db.execute('''
      CREATE TABLE category_totals (
        period TEXT NOT NULL,
        category INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (period, category)
      )
    ''');

    // Create sync status table (to track what needs to be synced to server)
    await db.execute('''
      CREATE TABLE sync_status (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sync_attempts INTEGER DEFAULT 0,
        last_attempt INTEGER
      )
    ''');

    // Create calorie_entries table
    await db.execute('''
      CREATE TABLE calorie_entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        food_item TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein INTEGER,
        carbs INTEGER,
        fat INTEGER,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        server_id TEXT
      )
    ''');

    // Create calorie_daily_summary table for caching daily summaries
    await db.execute('''
      CREATE TABLE calorie_daily_summary (
        date TEXT PRIMARY KEY,
        total_calories INTEGER NOT NULL,
        total_carbs REAL NOT NULL,
        total_protein REAL NOT NULL,
        total_fat REAL NOT NULL,
        breakdown TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Create indexes for faster queries
    await db.execute(
        'CREATE INDEX transactions_timestamp_idx ON transactions (timestamp)');
    await db.execute(
        'CREATE INDEX transactions_category_idx ON transactions (category)');
    await db.execute(
        'CREATE INDEX transactions_user_id_idx ON transactions (user_id)');
    await db.execute(
        'CREATE INDEX calorie_entries_timestamp_idx ON calorie_entries (timestamp)');
    await db.execute(
        'CREATE INDEX calorie_entries_user_id_idx ON calorie_entries (user_id)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(
      sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add calorie_entries table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS calorie_entries (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          food_item TEXT NOT NULL,
          calories INTEGER NOT NULL,
          protein INTEGER,
          carbs INTEGER,
          fat INTEGER,
          quantity REAL NOT NULL,
          unit TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          synced INTEGER DEFAULT 0,
          server_id TEXT
        )
      ''');

      // Add calorie_daily_summary table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS calorie_daily_summary (
          date TEXT PRIMARY KEY,
          total_calories INTEGER NOT NULL,
          total_carbs REAL NOT NULL,
          total_protein REAL NOT NULL,
          total_fat REAL NOT NULL,
          breakdown TEXT NOT NULL,
          last_updated INTEGER NOT NULL
        )
      ''');

      // Create indexes for calorie tables
      await db.execute(
          'CREATE INDEX IF NOT EXISTS calorie_entries_timestamp_idx ON calorie_entries (timestamp)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS calorie_entries_user_id_idx ON calorie_entries (user_id)');
    }
  }

  // =========================
  // Transaction CRUD Operations
  // =========================

  /// Insert a single transaction
  Future<int> insertTransaction(Transaction transaction) async {
    sqflite.Database db = await database;
    return await db.insert(
      'transactions',
      _transactionToMap(transaction),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple transactions in a single transaction (batch operation)
  Future<void> insertTransactions(List<Transaction> transactions) async {
    sqflite.Database db = await database;

    // Execute all operations in a single database transaction for better performance
    await db.transaction((txn) async {
      sqflite.Batch batch = txn.batch();

      for (var transaction in transactions) {
        batch.insert(
          'transactions',
          _transactionToMap(transaction),
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
    });
  }

  /// Update an existing transaction
  Future<int> updateTransaction(Transaction transaction) async {
    sqflite.Database db = await database;

    return await db.update(
      'transactions',
      _transactionToMap(transaction),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Delete a transaction by id
  Future<int> deleteTransaction(String id) async {
    sqflite.Database db = await database;

    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get a transaction by id
  Future<Transaction?> getTransaction(String id) async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToTransaction(maps.first);
    }

    return null;
  }

  /// Get all transactions
  Future<List<Transaction>> getAllTransactions() async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToTransaction(maps[i]));
  }

  /// Get transactions by period (day, week, month, year)
  Future<List<Transaction>> getTransactionsByPeriod(String period) async {
    sqflite.Database db = await database;
    final now = DateTime.now();
    int startTimestamp;

    switch (period.toLowerCase()) {
      case 'day':
      case 'daily':
        startTimestamp =
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        break;
      case 'week':
      case 'weekly':
        startTimestamp = now
            .subtract(Duration(days: now.weekday - 1))
            .millisecondsSinceEpoch;
        break;
      case 'month':
      case 'monthly':
        startTimestamp =
            DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
        break;
      case 'year':
      case 'yearly':
        startTimestamp = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
        break;
      default:
        startTimestamp = DateTime(now.year, now.month, 1)
            .millisecondsSinceEpoch; // Default to month
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'timestamp >= ?',
      whereArgs: [startTimestamp],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToTransaction(maps[i]));
  }

  /// Get transactions by user ID
  Future<List<Transaction>> getTransactionsByUserId(String userId) async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToTransaction(maps[i]));
  }

  /// Get transactions by user ID and period
  Future<List<Transaction>> getTransactionsByUserIdAndPeriod(
      String userId, String period) async {
    sqflite.Database db = await database;
    final now = DateTime.now();
    int startTimestamp;

    switch (period.toLowerCase()) {
      case 'day':
      case 'daily':
        startTimestamp =
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        break;
      case 'week':
      case 'weekly':
        startTimestamp = now
            .subtract(Duration(days: now.weekday - 1))
            .millisecondsSinceEpoch;
        break;
      case 'month':
      case 'monthly':
        startTimestamp =
            DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
        break;
      case 'year':
      case 'yearly':
        startTimestamp = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
        break;
      default:
        startTimestamp = DateTime(now.year, now.month, 1)
            .millisecondsSinceEpoch; // Default to month
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'user_id = ? AND timestamp >= ?',
      whereArgs: [userId, startTimestamp],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToTransaction(maps[i]));
  }

  /// Get total amount by period
  Future<double> getTotalByPeriod(String period) async {
    final transactions = await getTransactionsByPeriod(period);
    double total = 0.0;

    for (var tx in transactions) {
      total += tx.amount;
    }

    return total;
  }

  /// Calculate category totals for a period
  Future<Map<TransactionCategory, double>> getCategoryTotals(
      String period) async {
    final transactions = await getTransactionsByPeriod(period);
    final Map<TransactionCategory, double> categoryTotals = {};

    for (final transaction in transactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    return categoryTotals;
  }

  /// Save category totals to cache
  Future<void> saveCategoryTotals(
      String period, Map<TransactionCategory, double> totals) async {
    sqflite.Database db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // Delete existing totals for this period
      await txn.delete(
        'category_totals',
        where: 'period = ?',
        whereArgs: [period],
      );

      // Insert new totals
      sqflite.Batch batch = txn.batch();

      totals.forEach((category, amount) {
        batch.insert('category_totals', {
          'period': period,
          'category': category.index,
          'total_amount': amount,
          'last_updated': now,
        });
      });

      await batch.commit();
    });
  }

  /// Get cached category totals if they exist
  Future<Map<TransactionCategory, double>?> getCachedCategoryTotals(
      String period) async {
    sqflite.Database db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'category_totals',
      where: 'period = ?',
      whereArgs: [period],
    );

    if (maps.isEmpty) {
      return null;
    }

    final Map<TransactionCategory, double> totals = {};
    for (final map in maps) {
      final category = TransactionCategory.values[map['category'] as int];
      final amount = map['total_amount'] as double;
      totals[category] = amount;
    }

    return totals;
  }

  // =========================
  // Transaction Analysis Operations
  // =========================

  /// Save transaction analysis to cache
  Future<void> saveTransactionAnalysis(
      TransactionAnalysis analysis, String period, String date) async {
    sqflite.Database db = await database;
    final now = DateTime.now();

    // Calculate total amount
    double totalAmount =
        analysis.actual.needs + analysis.actual.wants + analysis.actual.savings;

    await db.insert(
      'transaction_analysis',
      {
        'id': '${period}_${date}',
        'period': period,
        'date': date,
        'needs_amount': analysis.actual.needs,
        'wants_amount': analysis.actual.wants,
        'savings_amount': analysis.actual.savings,
        'total_amount': totalAmount,
        'needs_percent':
            analysis.actual.needs / (totalAmount > 0 ? totalAmount : 1) * 100,
        'wants_percent':
            analysis.actual.wants / (totalAmount > 0 ? totalAmount : 1) * 100,
        'savings_percent':
            analysis.actual.savings / (totalAmount > 0 ? totalAmount : 1) * 100,
        'last_updated': now.millisecondsSinceEpoch,
        'monthly_salary': analysis.monthlySalary,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Get cached transaction analysis if it exists
  Future<TransactionAnalysis?> getTransactionAnalysis(
      String period, String date) async {
    sqflite.Database db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_analysis',
      where: 'period = ? AND date = ?',
      whereArgs: [period, date],
    );

    if (maps.isEmpty) {
      return null;
    }

    final data = maps.first;
    final needsAmount = data['needs_amount'] as double;
    final wantsAmount = data['wants_amount'] as double;
    final savingsAmount = data['savings_amount'] as double;
    final monthlySalary = data['monthly_salary'] as double;

    // Create allocation objects
    final actual = TransactionAllocation(
      needs: needsAmount,
      wants: wantsAmount,
      savings: savingsAmount,
    );

    // Create an ideal allocation based on standard 50-30-20 rule
    final ideal = TransactionAllocation(
      needs: monthlySalary * 0.5,
      wants: monthlySalary * 0.3,
      savings: monthlySalary * 0.2,
    );

    return TransactionAnalysis(
      monthlySalary: monthlySalary,
      ideal: ideal,
      actual: actual,
    );
  }

  /// Check if transaction analysis cache is stale (older than specified time)
  Future<bool> isAnalysisCacheStale(
      String period, String date, Duration maxAge) async {
    sqflite.Database db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_analysis',
      columns: ['last_updated'],
      where: 'period = ? AND date = ?',
      whereArgs: [period, date],
    );

    if (maps.isEmpty) {
      return true;
    }

    final lastUpdated = maps.first['last_updated'] as int;
    final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdated);
    final now = DateTime.now();

    return now.difference(lastUpdateTime) > maxAge;
  }

  // =========================
  // Sync Queue Operations
  // =========================

  /// Add an entity to the sync queue
  Future<void> addToSyncQueue(String id, String entityType, String operation,
      Map<String, dynamic> data) async {
    sqflite.Database db = await database;

    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'sync_status',
      {
        'id': id,
        'entity_type': entityType,
        'operation': operation,
        'data': jsonEncode(data),
        'created_at': now,
        'sync_attempts': 0,
        'last_attempt': null,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Get entities that need to be synced
  Future<List<Map<String, dynamic>>> getSyncQueue({int maxAttempts = 3}) async {
    sqflite.Database db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'sync_status',
      where: 'sync_attempts < ?',
      whereArgs: [maxAttempts],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) {
      // Parse stored JSON data back to Map
      final data = jsonDecode(map['data'] as String);
      return {
        ...map,
        'data': data,
      };
    }).toList();
  }

  /// Update sync attempt status
  Future<void> updateSyncAttempt(String id, bool success) async {
    sqflite.Database db = await database;

    if (success) {
      // If sync was successful, remove from queue
      await db.delete(
        'sync_status',
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // If sync failed, increment attempt count and update last attempt time
      // First get current attempt count
      final List<Map<String, dynamic>> result = await db.query(
        'sync_status',
        columns: ['sync_attempts'],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isNotEmpty) {
        final int currentAttempts = result.first['sync_attempts'] as int;
        await db.update(
          'sync_status',
          {
            'sync_attempts': currentAttempts + 1,
            'last_attempt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  // =========================
  // Helper Methods
  // =========================

  /// Convert a Transaction object to a Map for database storage
  Map<String, dynamic> _transactionToMap(Transaction transaction) {
    return {
      'id': transaction.id,
      'user_id': transaction.userId,
      'amount': transaction.amount,
      'category': transaction.category.index,
      'description': transaction.description,
      'merchant': transaction.merchant,
      'timestamp': transaction.timestamp.millisecondsSinceEpoch,
      'source': transaction.source,
      'metadata': transaction.metadata != null
          ? jsonEncode(transaction.metadata!)
          : null,
    };
  }

  /// Convert a database Map to a Transaction object
  Transaction _mapToTransaction(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: map['amount'] as double,
      category: TransactionCategory.values[map['category'] as int],
      description: map['description'] as String,
      merchant: map['merchant'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      source: map['source'] as String? ?? 'chat',
      metadata: map['metadata'] != null
          ? jsonDecode(map['metadata'] as String)
          : null,
    );
  }

  /// Clear all data from the database (useful for testing)
  Future<void> clearAllData() async {
    sqflite.Database db = await database;

    await db.delete('transactions');
    await db.delete('transaction_analysis');
    await db.delete('category_totals');
    await db.delete('sync_status');
  }

  // =========================
  // Calorie Entry Operations
  // =========================

  /// Insert a single calorie entry
  Future<int> insertCalorieEntry(CalorieEntry entry, String userId) async {
    sqflite.Database db = await database;
    return await db.insert(
      'calorie_entries',
      _calorieEntryToMap(entry, userId),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple calorie entries
  Future<void> insertCalorieEntries(
      List<CalorieEntry> entries, String userId) async {
    sqflite.Database db = await database;

    await db.transaction((txn) async {
      sqflite.Batch batch = txn.batch();

      for (var entry in entries) {
        batch.insert(
          'calorie_entries',
          _calorieEntryToMap(entry, userId),
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
    });
  }

  /// Update an existing calorie entry
  Future<int> updateCalorieEntry(CalorieEntry entry, String userId) async {
    sqflite.Database db = await database;

    return await db.update(
      'calorie_entries',
      _calorieEntryToMap(entry, userId),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Delete a calorie entry by id
  Future<int> deleteCalorieEntry(String id) async {
    sqflite.Database db = await database;

    return await db.delete(
      'calorie_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get a calorie entry by id
  Future<CalorieEntry?> getCalorieEntry(String id) async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToCalorieEntry(maps.first);
    }

    return null;
  }

  /// Get all calorie entries for a user
  Future<List<CalorieEntry>> getAllCalorieEntries(String userId) async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_entries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToCalorieEntry(maps[i]));
  }

  /// Get calorie entries for a specific date
  Future<List<CalorieEntry>> getCalorieEntriesForDate(
      String userId, DateTime date) async {
    sqflite.Database db = await database;

    // Get start and end of the specified date
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final startTimestamp = startDate.millisecondsSinceEpoch;
    final endTimestamp = endDate.millisecondsSinceEpoch;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_entries',
      where: 'user_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [userId, startTimestamp, endTimestamp],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToCalorieEntry(maps[i]));
  }

  /// Get calorie entries for a date range
  Future<List<CalorieEntry>> getCalorieEntriesForDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    sqflite.Database db = await database;

    // Use the start of the start date and end of the end date
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final startTimestamp = start.millisecondsSinceEpoch;
    final endTimestamp = end.millisecondsSinceEpoch;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_entries',
      where: 'user_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [userId, startTimestamp, endTimestamp],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => _mapToCalorieEntry(maps[i]));
  }

  /// Save daily calorie summary
  Future<void> saveDailyCalorieSummary(
      String date, Map<String, dynamic> summary) async {
    sqflite.Database db = await database;

    // Convert breakdown list to JSON string
    final breakdownJson = jsonEncode(summary['breakdown'] ?? []);

    await db.insert(
      'calorie_daily_summary',
      {
        'date': date,
        'total_calories': summary['totalCalories'] ?? 0,
        'total_carbs': summary['totalCarbs'] ?? 0.0,
        'total_protein': summary['totalProtein'] ?? 0.0,
        'total_fat': summary['totalFat'] ?? 0.0,
        'breakdown': breakdownJson,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Get cached daily calorie summary
  Future<Map<String, dynamic>?> getDailyCalorieSummary(String date) async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_daily_summary',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isEmpty) {
      return null;
    }

    final data = maps.first;
    List<dynamic> breakdownList = [];

    try {
      breakdownList = jsonDecode(data['breakdown'] as String) ?? [];
    } catch (e) {
      // Handle JSON parsing error
    }

    return {
      'totalCalories': data['total_calories'] as int,
      'totalCarbs': data['total_carbs'] as double,
      'totalProtein': data['total_protein'] as double,
      'totalFat': data['total_fat'] as double,
      'breakdown': breakdownList,
      'lastUpdated': data['last_updated'] as int,
    };
  }

  /// Check if a daily calorie summary cache is stale
  Future<bool> isCalorieSummaryCacheStale(String date, Duration maxAge) async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_daily_summary',
      columns: ['last_updated'],
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isEmpty) {
      return true;
    }

    final lastUpdated = maps.first['last_updated'] as int;
    final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdated);
    final now = DateTime.now();

    return now.difference(lastUpdateTime) > maxAge;
  }

  /// Mark entries as synced with the server
  Future<void> markCalorieEntriesAsSynced(List<String> ids,
      [String? serverId]) async {
    sqflite.Database db = await database;

    await db.transaction((txn) async {
      for (var id in ids) {
        await txn.update(
          'calorie_entries',
          {
            'synced': 1,
            if (serverId != null) 'server_id': serverId,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Get unsynced calorie entries
  Future<List<CalorieEntry>> getUnsyncedCalorieEntries() async {
    sqflite.Database db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'calorie_entries',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) => _mapToCalorieEntry(maps[i]));
  }

  /// Save a single calorie entry (combines insert and update)
  Future<void> saveCalorieEntry(CalorieEntry entry, String userId) async {
    // Check if entry exists
    final existingEntry = await getCalorieEntry(entry.id);

    if (existingEntry == null) {
      // Insert new entry
      await insertCalorieEntry(entry, userId);
    } else {
      // Update existing entry
      await updateCalorieEntry(entry, userId);
    }
  }

  /// Save multiple calorie entries (combines insert and update)
  Future<void> saveCalorieEntries(
      List<CalorieEntry> entries, String userId) async {
    sqflite.Database db = await database;

    await db.transaction((txn) async {
      for (var entry in entries) {
        // Check if entry exists using a query within the transaction
        final existingEntries = await txn.query(
          'calorie_entries',
          where: 'id = ?',
          whereArgs: [entry.id],
        );

        if (existingEntries.isEmpty) {
          // Insert new entry
          await txn.insert(
            'calorie_entries',
            _calorieEntryToMap(entry, userId),
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        } else {
          // Update existing entry
          await txn.update(
            'calorie_entries',
            _calorieEntryToMap(entry, userId),
            where: 'id = ?',
            whereArgs: [entry.id],
          );
        }
      }
    });
  }

  /// Convert a CalorieEntry object to a Map for database storage
  Map<String, dynamic> _calorieEntryToMap(CalorieEntry entry, String userId) {
    return {
      'id': entry.id,
      'user_id': userId,
      'food_item': entry.foodItem,
      'calories': entry.calories,
      'protein': entry.protein,
      'carbs': entry.carbs,
      'fat': entry.fat,
      'quantity': entry.quantity,
      'unit': entry.unit,
      'timestamp': entry.timestamp.millisecondsSinceEpoch,
      'synced': 0, // Default to unsynced
      'server_id': entry.id, // Use local ID as server ID initially
    };
  }

  /// Convert a database Map to a CalorieEntry object
  CalorieEntry _mapToCalorieEntry(Map<String, dynamic> map) {
    return CalorieEntry(
      id: map['id'] as String,
      foodItem: map['food_item'] as String,
      calories: map['calories'] as int,
      protein: map['protein'] as int?,
      carbs: map['carbs'] as int?,
      fat: map['fat'] as int?,
      quantity: map['quantity'] as double,
      unit: map['unit'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
