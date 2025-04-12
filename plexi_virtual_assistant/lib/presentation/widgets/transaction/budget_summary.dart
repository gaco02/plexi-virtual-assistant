import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../blocs/budget/budget_bloc.dart';
import '../../../blocs/budget/budget_state.dart';
import '../../../blocs/budget/budget_event.dart';
import '../../../utils/formatting_utils.dart';

class BudgetSummary extends StatefulWidget {
  // Add a key to help Flutter preserve widget identity
  const BudgetSummary({super.key = const ValueKey('budget_summary')});

  @override
  State<BudgetSummary> createState() => _BudgetSummaryState();
}

class _BudgetSummaryState extends State<BudgetSummary> {
  bool _isFirstLoad = true;
  // Track if we've already loaded data
  bool _dataLoaded = false;
  // Debounce timer
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Load budget only once with debouncing
    if (_isFirstLoad && !_dataLoaded) {
      _isFirstLoad = false;
      _dataLoaded = true;
      _debouncedLoadBudget();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Debounced method to load budget data
  void _debouncedLoadBudget({bool forceRefresh = false}) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      context
          .read<BudgetBloc>()
          .add(LoadTodaysBudget(forceRefresh: forceRefresh));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BudgetBloc, BudgetState>(
      buildWhen: (previous, current) {
        // Prevent rebuilds for the same data
        if (previous is TodaysBudgetLoaded && current is TodaysBudgetLoaded) {
          final shouldRebuild = previous.analysis != current.analysis;
          return shouldRebuild;
        }
        return true;
      },
      builder: (context, state) {
        if (state is BudgetLoading) {
          return const Card(
            color: Colors.black26,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 8.0,
                  ),
                ),
              ),
            ),
          );
        }

        if (state is BudgetError) {
          return Card(
            color: Colors.red.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        if (state is TodaysBudgetLoaded) {
          final analysis = state.analysis;

          return Card(
            margin: const EdgeInsets.all(0),
            color: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Budget Overview',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: Colors.white70, size: 20),
                        onPressed: () async {
                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refreshing budget data...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Reload data with debouncing and force refresh
                          _debouncedLoadBudget(forceRefresh: true);

                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Budget data refreshed'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        tooltip: 'Refresh budget data',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Today's spending section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today\'s Spending',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        FormattingUtils.formatCurrency(analysis.todaySpending),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildBudgetBar(
                    'Needs (50%)',
                    analysis.actual.needs,
                    analysis.ideal.needs,
                    Colors.blue,
                    context,
                  ),
                  _buildBudgetBar(
                    'Wants (30%)',
                    analysis.actual.wants,
                    analysis.ideal.wants,
                    Colors.green,
                    context,
                  ),
                  _buildBudgetBar(
                    'Savings (20%)',
                    analysis.actual.savings,
                    analysis.ideal.savings,
                    Colors.purple,
                    context,
                  ),
                ],
              ),
            ),
          );
        }

        // Trigger loading if we're in the initial state
        if (state is BudgetInitial) {
          _debouncedLoadBudget();
        }

        return Card(
          color: Colors.black26,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No budget data available',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _debouncedLoadBudget(forceRefresh: true);
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
