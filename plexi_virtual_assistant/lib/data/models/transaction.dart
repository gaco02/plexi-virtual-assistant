import 'package:equatable/equatable.dart';

/// Defines transaction categories used within the app.
enum TransactionCategory {
  groceries,
  dining,
  transport,
  entertainment,
  shopping,
  housing,
  savingsAndInvestments,
  other,
}

/// Adds helper methods to [TransactionCategory].
extension TransactionCategoryExtension on TransactionCategory {
  /// A human-readable label for the category.
  String get displayName {
    switch (this) {
      case TransactionCategory.groceries:
        return 'Groceries';
      case TransactionCategory.dining:
        return 'Dining Out';
      case TransactionCategory.transport:
        return 'Transport';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.housing:
        return 'Housing';
      case TransactionCategory.savingsAndInvestments:
        return 'Savings & Investments';
      case TransactionCategory.other:
        return 'Other';
    }
  }

  /// Converts a string to a [TransactionCategory], defaulting to `other` if unknown.
  static TransactionCategory fromString(String category) {
    // Handle case where the category includes the enum prefix
    if (category.startsWith('TransactionCategory.')) {
      final enumValue = category.substring('TransactionCategory.'.length);
      switch (enumValue.toLowerCase()) {
        case 'groceries':
          return TransactionCategory.groceries;
        case 'dining':
          return TransactionCategory.dining;
        case 'transport':
          return TransactionCategory.transport;
        case 'entertainment':
          return TransactionCategory.entertainment;
        case 'shopping':
          return TransactionCategory.shopping;
        case 'housing':
          return TransactionCategory.housing;
        case 'savingsandinvestments':
          return TransactionCategory.savingsAndInvestments;
        case 'other':
          return TransactionCategory.other;
      }
    }

    // Original logic for categories without the enum prefix
    switch (category.toLowerCase()) {
      case 'groceries':
        return TransactionCategory.groceries;
      case 'dining':
      case 'dining out':
        return TransactionCategory.dining;
      case 'transport':
      case 'transportation':
        return TransactionCategory.transport;
      case 'entertainment':
        return TransactionCategory.entertainment;
      case 'shopping':
        return TransactionCategory.shopping;
      case 'housing':
      case 'rent':
      case 'mortgage':
      case 'home':
      case 'insurance':
        return TransactionCategory.housing;
      case 'savings & investments':
      case 'savings_and_investments':
      case 'savingsandinvestments':
      case 'savings':
        return TransactionCategory.savingsAndInvestments;
      default:
        return TransactionCategory.other;
    }
  }

  /// Returns the spending type (needs, wants, or savings) for this category.
  String get spendingType {
    switch (this) {
      case TransactionCategory.groceries:
      case TransactionCategory.housing:
      case TransactionCategory.transport:
        return 'needs';
      case TransactionCategory.dining:
      case TransactionCategory.entertainment:
      case TransactionCategory.shopping:
      case TransactionCategory.other:
        return 'wants';
      case TransactionCategory.savingsAndInvestments:
        return 'savings';
    }
  }
}

/// Represents a financial transaction within the app.
class Transaction extends Equatable {
  final String id;
  final String userId;
  final double amount;
  final TransactionCategory category;
  final String description;
  final String? merchant;
  final DateTime timestamp;
  final String source;
  final Map<String, dynamic>? metadata;

  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.description,
    this.merchant,
    required this.timestamp,
    this.source = 'chat',
    this.metadata,
  });

  /// Constructs a [Transaction] from a JSON map.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Handle ID which can be either a string or an integer
    String id = json['id'] is int
        ? (json['id'] as int).toString()
        : json['id'] as String;

    // Handle user_id which might be missing in some responses
    String userId =
        json.containsKey('user_id') ? json['user_id'] as String : 'unknown';

    return Transaction(
      id: id,
      userId: userId,
      amount: (json['amount'] as num).toDouble(),
      category:
          TransactionCategoryExtension.fromString(json['category'] as String),
      description: json['description'] as String,
      merchant: json['merchant'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] != null ? json['source'] as String : 'chat',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Converts a [Transaction] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      // Use the enum's 'name' property or 'toString()' method.
      // 'name' (Dart 2.15+) returns only the identifier without "TransactionCategory."
      'category': category.name,
      'description': description,
      'merchant': merchant,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        amount,
        category,
        description,
        merchant,
        timestamp,
        source,
        metadata,
      ];
}
