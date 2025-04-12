import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/transaction.dart';

/// Utility class for consistent formatting across the app
class FormattingUtils {
  /// Currency symbol used throughout the app
  static const String currencySymbol = '\$';

  /// Format a number as currency with proper thousands separators
  /// Example: 1234.56 -> $1,234.56
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Get emoji icon for a transaction category
  static String getCategoryEmoji(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.dining:
        return '🍔';
      case TransactionCategory.transport:
        return '🚗';
      case TransactionCategory.entertainment:
        return '🎬';
      case TransactionCategory.shopping:
        return '🛍️';
      case TransactionCategory.housing:
        return '🏠';
      case TransactionCategory.savingsAndInvestments:
        return '💰';
      case TransactionCategory.other:
        return '📦';
      case TransactionCategory.groceries:
        return '🛒';
    }
  }

  /// Get color for a transaction category
  static Color getCategoryColor(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.dining:
        return Colors.green;
      case TransactionCategory.transport:
        return Colors.blue;
      case TransactionCategory.entertainment:
        return Colors.purple;
      case TransactionCategory.shopping:
        return Colors.pink;
      case TransactionCategory.housing:
        return Colors.teal;
      case TransactionCategory.savingsAndInvestments:
        return Colors.amber;
      case TransactionCategory.groceries:
        return Colors.lightGreen;
      case TransactionCategory.other:
        return Colors.grey;
    }
  }
}
