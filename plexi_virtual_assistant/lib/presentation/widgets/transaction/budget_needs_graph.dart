import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/transaction_analysis.dart';
import '../../../utils/formatting_utils.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';

class BudgetGraphWidget extends StatefulWidget {
  final TransactionAllocation actual;
  final TransactionAllocation ideal;

  const BudgetGraphWidget({
    Key? key,
    required this.actual,
    required this.ideal,
  }) : super(key: key);

  @override
  State<BudgetGraphWidget> createState() => _BudgetGraphWidgetState();
}

class _BudgetGraphWidgetState extends State<BudgetGraphWidget> {
  // Keep track of previous values for comparison
  late TransactionAllocation _previousActual;
  String _cacheKey = '';
  bool _initialRefreshDone = false;
  bool _hasNewTransactions = false;

  @override
  void initState() {
    super.initState();
    _previousActual = widget.actual;
    _generateCacheKey();

    // Wait for first frame to be rendered before requesting data
    // This prevents UI jank during initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialRefreshDone = true;
      // Only trigger initial refresh if we don't have data
      if (_isDataEmpty()) {
        _refreshDataIfNeeded();
      }
    });
  }

  // Check if we have empty data
  bool _isDataEmpty() {
    return widget.actual.needs <= 0 &&
        widget.actual.wants <= 0 &&
        widget.actual.savings <= 0;
  }

  @override
  void didUpdateWidget(BudgetGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only detect significant changes in transaction data, not UI rebuilds
    final valueChanged = oldWidget.actual.needs != widget.actual.needs ||
        oldWidget.actual.wants != widget.actual.wants ||
        oldWidget.actual.savings != widget.actual.savings;

    final idealChanged = oldWidget.ideal != widget.ideal;

    if (valueChanged) {
      print('BudgetGraphWidget: Value changes detected, updating display');
      print(
          'Previous: needs=${oldWidget.actual.needs}, wants=${oldWidget.actual.wants}, savings=${oldWidget.actual.savings}');
      print(
          'Current: needs=${widget.actual.needs}, wants=${widget.actual.wants}, savings=${widget.actual.savings}');

      // Store the new actual values
      _previousActual = widget.actual;
      _cacheKey = '';
      _generateCacheKey();

      // Flag that we've received new transaction data
      _hasNewTransactions = true;
    } else if (idealChanged) {
      print('BudgetGraphWidget: Budget targets changed, updating display');
      _cacheKey = '';
      _generateCacheKey();
    }

    // If we have new transactions, refresh to get complete updated data
    if (_hasNewTransactions) {
      _hasNewTransactions = false; // Reset flag
      _refreshDataIfNeeded();
    }
  }

  // Generate a cache key based on current values
  String _generateCacheKey() {
    _cacheKey =
        '${widget.actual.needs}_${widget.actual.wants}_${widget.actual.savings}_${widget.ideal.needs}_${widget.ideal.wants}_${widget.ideal.savings}';
    return _cacheKey;
  }

  // Check if data refresh is needed and request it
  void _refreshDataIfNeeded() {
    print('BudgetGraphWidget: Requesting latest transaction data');

    // Use a post-frame callback to avoid build/setState conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Request latest data from local storage first
      // Only force refresh from server if local data is stale
      context
          .read<TransactionAnalysisBloc>()
          .add(const RefreshTransactionHistory(forceRefresh: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate a new cache key
    final newCacheKey = _generateCacheKey();

    // If the cache key changed since last build, log it for debugging
    if (_cacheKey != newCacheKey) {
      print('BudgetGraphWidget: Cache key changed: $_cacheKey -> $newCacheKey');
      _cacheKey = newCacheKey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBudgetBar(
          'Needs (50%)',
          widget.actual.needs,
          widget.ideal.needs,
          Colors.blue,
          context,
        ),
        _buildBudgetBar(
          'Wants (30%)',
          widget.actual.wants,
          widget.ideal.wants,
          Colors.orange,
          context,
        ),
        _buildBudgetBar(
          'Savings (20%)',
          widget.actual.savings,
          widget.ideal.savings,
          Colors.green,
          context,
        ),
      ],
    );
  }

  Widget _buildBudgetBar(String label, double actual, double target,
      Color color, BuildContext context) {
    final percentage = target > 0 ? (actual / target).clamp(0.0, 2.0) : 0.0;
    final isOverBudget = percentage > 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              '${FormattingUtils.formatCurrency(actual)} / ${FormattingUtils.formatCurrency(target)}',
              style: TextStyle(
                color: isOverBudget ? Colors.red : Colors.white70,
                fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage > 1.0 ? 1.0 : percentage, // Cap at 100% for visual
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOverBudget ? Colors.red : color,
          ),
          borderRadius: BorderRadius.circular(12),
          minHeight: 12,
        ),
        Text(
          isOverBudget
              ? '${(percentage * 100).toStringAsFixed(1)}% of budget (Over budget!)'
              : '${(percentage * 100).toStringAsFixed(1)}% of budget',
          style: TextStyle(
            color: isOverBudget ? Colors.red : Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
