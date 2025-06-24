import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/transaction_analysis.dart';
import '../../../utils/formatting_utils.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_state.dart';

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
  String _cacheKey = '';

  // Optimistic update state
  TransactionAllocation? _optimisticActual;
  DateTime? _lastOptimisticUpdate;

  @override
  void initState() {
    super.initState();
    _generateCacheKey();

    // Wait for first frame to be rendered before requesting data
    // This prevents UI jank during initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only trigger initial refresh if we don't have data
      if (_isDataEmpty()) {
        _refreshDataIfNeeded();
      }
    });
  }

  // Check if we have empty data
  bool _isDataEmpty() {
    final actualToCheck = _getDisplayActual();
    return actualToCheck.needs <= 0 &&
        actualToCheck.wants <= 0 &&
        actualToCheck.savings <= 0;
  }

  // Get the allocation to display (optimistic update or actual)
  TransactionAllocation _getDisplayActual() {
    // Use optimistic update if it's recent (within 10 seconds)
    if (_optimisticActual != null && _lastOptimisticUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastOptimisticUpdate!);
      if (timeSinceUpdate.inSeconds < 10) {
        return _optimisticActual!;
      } else {
        // Clear old optimistic update
        _optimisticActual = null;
        _lastOptimisticUpdate = null;
      }
    }
    return widget.actual;
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

      // Update cache key
      _cacheKey = '';
      _generateCacheKey();

      // Clear any optimistic updates since we have real data
      _optimisticActual = null;
      _lastOptimisticUpdate = null;

      // Request lightweight refresh (prefer local data)
      _refreshDataOptimized();
    } else if (idealChanged) {
      print('BudgetGraphWidget: Budget targets changed, updating display');
      _cacheKey = '';
      _generateCacheKey();
    }
  }

  // Generate a cache key based on current values
  String _generateCacheKey() {
    final displayActual = _getDisplayActual();
    _cacheKey =
        '${displayActual.needs}_${displayActual.wants}_${displayActual.savings}_${widget.ideal.needs}_${widget.ideal.wants}_${widget.ideal.savings}';
    return _cacheKey;
  }

  // Optimized refresh that prefers local data and avoids network calls
  void _refreshDataOptimized() {
    print(
        'BudgetGraphWidget: Requesting optimized data refresh (local preferred)');

    // Use a post-frame callback to avoid build/setState conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Request data but prefer local/cached data
      // Only go to network if local data is stale
      context
          .read<TransactionAnalysisBloc>()
          .add(const LoadTransactionAnalysis(forceRefresh: false));
    });
  }

  // Check if data refresh is needed and request it (legacy method for initial load)
  void _refreshDataIfNeeded() {
    print('BudgetGraphWidget: Requesting latest transaction data');

    // Use a post-frame callback to avoid build/setState conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // For initial load, also prefer local data
      context
          .read<TransactionAnalysisBloc>()
          .add(const LoadTransactionAnalysis(forceRefresh: false));
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

    final displayActual = _getDisplayActual();

    return BlocListener<TransactionAnalysisBloc, TransactionAnalysisState>(
      listener: (context, state) {
        // If we receive updated analysis data, clear optimistic updates
        if (state is TransactionAnalysisLoaded) {
          if (_optimisticActual != null) {
            setState(() {
              _optimisticActual = null;
              _lastOptimisticUpdate = null;
            });
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBudgetBar(
            'Needs (50%)',
            displayActual.needs,
            widget.ideal.needs,
            Colors.blue,
            context,
          ),
          _buildBudgetBar(
            'Wants (30%)',
            displayActual.wants,
            widget.ideal.wants,
            Colors.orange,
            context,
          ),
          _buildBudgetBar(
            'Savings (20%)',
            displayActual.savings,
            widget.ideal.savings,
            Colors.green,
            context,
          ),
        ],
      ),
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
