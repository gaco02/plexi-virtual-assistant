import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/transaction.dart';
import '../../../blocs/transaction/transaction_bloc.dart';
import '../../../blocs/transaction/transaction_event.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../utils/formatting_utils.dart';
import '../common/transparent_card.dart';

class SpendingByCategory extends StatefulWidget {
  final Map<TransactionCategory, double> categoryTotals;
  final double totalAmount;
  final double? monthlyBudget;
  final VoidCallback? onViewAll;

  const SpendingByCategory({
    Key? key,
    required this.categoryTotals,
    required this.totalAmount,
    this.monthlyBudget,
    this.onViewAll,
  }) : super(key: key);

  @override
  State<SpendingByCategory> createState() => _SpendingByCategoryState();
}

class _SpendingByCategoryState extends State<SpendingByCategory> {
  // Cache for memoization
  List<Widget>? _cachedBreakdown;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();

    // Listen for transaction changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force refresh of transaction data when this widget is first built
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(SpendingByCategory oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear cache if the data has changed
    if (oldWidget.categoryTotals != widget.categoryTotals ||
        oldWidget.totalAmount != widget.totalAmount) {
      print('SpendingByCategory: didUpdateWidget detected data change');
      print(
          'SpendingByCategory: Old total: ${oldWidget.totalAmount}, New total: ${widget.totalAmount}');
      print(
          'SpendingByCategory: Old categories: ${oldWidget.categoryTotals.length}, New categories: ${widget.categoryTotals.length}');

      // Always invalidate the cache when the total amount changes, even if the categories appear the same
      // This ensures we rebuild for new transactions of existing categories
      _cachedBreakdown = null;
      _cacheKey = null;

      // Force rebuild when total amount changes
      if (oldWidget.totalAmount != widget.totalAmount) {
        // Request a refresh to make sure we have the latest data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context
              .read<TransactionBloc>()
              .add(const LoadMonthlyTransactions(forceRefresh: true));
        });
      }
    }
  }

  // Refresh transaction data
  void _refreshData() {
    print('SpendingByCategory: _refreshData called');

    // Only refresh if we have no data
    if (widget.categoryTotals.isEmpty || widget.totalAmount == 0) {
      print(
          'SpendingByCategory: Refreshing transaction data because data is empty');
      // Request monthly transactions
      context
          .read<TransactionBloc>()
          .add(const LoadMonthlyTransactions(forceRefresh: true));

      // Also refresh the transaction analysis
      context
          .read<TransactionAnalysisBloc>()
          .add(const LoadTransactionAnalysis());
    } else {
      print(
          'SpendingByCategory: Not refreshing as we already have data: ${widget.categoryTotals.length} categories, total: ${widget.totalAmount}');
    }
  }

  // Generate a cache key based on the current data
  String _generateCacheKey() {
    return '${widget.totalAmount}_${widget.categoryTotals.length}_${widget.categoryTotals.values.fold(0.0, (sum, value) => sum + value)}';
  }

  // Build the category breakdown with memoization
  List<Widget> buildCategoryBreakdownMemoized(
      Map<TransactionCategory, double> categoryTotals, double totalAmount) {
    // Generate a cache key
    final newCacheKey = _generateCacheKey();

    // If we have a cached result and the key matches, return it
    if (_cachedBreakdown != null && _cacheKey == newCacheKey) {
      return _cachedBreakdown!;
    }

    // Sort categories by amount (descending)
    final sortedCategories = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    final result = <Widget>[];

    // Calculate the maximum value for the progress bar (50% of budget or total if no budget)
    final maxProgressValue =
        widget.monthlyBudget != null && widget.monthlyBudget! > 0
            ? widget.monthlyBudget! * 0.5 // Use 50% of monthly budget as max
            : totalAmount;

    // Add each category
    for (final category in sortedCategories) {
      final amount = categoryTotals[category]!;
      final percentage = totalAmount > 0 ? (amount / totalAmount * 100) : 0;

      // Calculate progress value relative to the max progress value
      final progressValue = maxProgressValue > 0
          ? (amount / maxProgressValue)
          : 0.0; // Cap the progress value at 1.0 (100%)
      final cappedProgressValue = progressValue > 1.0 ? 1.0 : progressValue;

      result.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    FormattingUtils.getCategoryEmoji(category),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${FormattingUtils.formatCurrency(amount)} (${percentage.toStringAsFixed(0)}%)",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: cappedProgressValue,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FormattingUtils.getCategoryColor(category),
                ),
                borderRadius: BorderRadius.circular(12),
                minHeight: 12,
              ),
              // Show warning if over 50% of budget
              if (progressValue > 1.0)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    "Over 50% of budget",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Cache the result
    _cachedBreakdown = result;
    _cacheKey = newCacheKey;

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Force clear the cache with each build cycle when totals change
    // This ensures we always rebuild with fresh data
    if (_cacheKey != _generateCacheKey()) {
      print(
          'SpendingByCategory: build detected cache key change, clearing cache');
      _cachedBreakdown = null;
      _cacheKey = null;
    }

    // If there are no categories, show a message
    if (widget.categoryTotals.isEmpty) {
      return const TransparentCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No spending data available for this period',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return TransparentCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spending by Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...buildCategoryBreakdownMemoized(
                widget.categoryTotals, widget.totalAmount),
            if (widget.monthlyBudget != null && widget.monthlyBudget! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Monthly Budget: ${FormattingUtils.formatCurrency(widget.monthlyBudget!)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
