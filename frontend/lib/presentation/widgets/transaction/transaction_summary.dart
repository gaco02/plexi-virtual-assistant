import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/transaction/transaction_bloc.dart';
import '../../../blocs/transaction/transaction_state.dart';
import '../../screens/transaction/transaction_details_screen.dart';
import '../../screens/transaction/transaction_onboarding_screen.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../blocs/transaction/transaction_event.dart';
import '../../../utils/formatting_utils.dart';

class TransactionSummary extends StatefulWidget {
  const TransactionSummary({super.key});

  @override
  State<TransactionSummary> createState() => _TransactionSummaryState();
}

class _TransactionSummaryState extends State<TransactionSummary> {
  @override
  void initState() {
    super.initState();
    // Load today's transactions when the widget is initialized
    _loadTodaysTransactions();
  }

  void _loadTodaysTransactions() {
    context.read<TransactionBloc>().add(
          const LoadDailyTransactions(isForWidget: true),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PreferencesBloc, PreferencesState>(
      builder: (context, prefsState) {
        return GestureDetector(
          onTap: () {
            if (prefsState is PreferencesLoaded &&
                prefsState.preferences.monthlySalary != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailsScreen(),
                ),
              ).then((_) {
                // Reload today's transactions when returning from details screen
                _loadTodaysTransactions();
              });
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionOnboardingScreen(),
                ),
              );
            }
          },
          child: BlocBuilder<TransactionBloc, TransactionState>(
            buildWhen: (previous, current) {
              // Rebuild for any transaction state change
              return true;
            },
            builder: (context, state) {
              if (state is TransactionLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // Get the total amount from the appropriate state
              double amount = 0.0;
              if (state is DailySummaryLoaded) {
                amount = state.totalAmount;
              } else if (state is TransactionsLoaded) {
                // Always use today's amount, not monthly amount
                amount = state.todayAmount;
              }

              return Card(
                margin: const EdgeInsets.all(8), // Reduced margin
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.transparent,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and amount in one row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Monthly Categories',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16, // Reduced font size
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '\$',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16, // Reduced font size
                                ),
                              ),
                              Text(
                                amount.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18, // Reduced font size
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8), // Reduced spacing

                      // Budget category breakdown
                      Expanded(
                        child:
                            _buildBudgetCategoryBreakdown(amount, prefsState),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Helper method to build the budget category breakdown
  Widget _buildBudgetCategoryBreakdown(
      double todayAmount, PreferencesState prefsState) {
    // Default values
    double monthlyBudget = 0.0;

    // Get monthly budget from preferences
    if (prefsState is PreferencesLoaded) {
      monthlyBudget = prefsState.preferences.monthlySalary ?? 0.0;
    }

    // Get monthly spending from the TransactionBloc
    double monthlySpent = 0.0;
    final transactionState = context.read<TransactionBloc>().state;
    if (transactionState is TransactionsLoaded) {
      monthlySpent = transactionState.monthlyAmount;
    } else if (transactionState is MonthlySummaryLoaded) {
      monthlySpent = transactionState.totalAmount;
    }

    // Calculate targets based on 50/30/20 rule
    // 50% for needs, 30% for wants, 20% for savings
    final double needsTarget = monthlyBudget * 0.5;
    final double wantsTarget = monthlyBudget * 0.3;
    final double savingsTarget = monthlyBudget * 0.2;

    // For this example, we'll distribute monthly spending
    // Normally you would get this from your transaction data with proper categorization
    final double needs = monthlySpent * 0.6; // 60% of monthly spending on needs
    final double wants = monthlySpent * 0.3; // 30% of monthly spending on wants
    final double savings =
        monthlySpent * 0.1; // 10% of monthly spending on savings

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBudgetBar(
          'Needs (50%)',
          needs,
          needsTarget,
          Colors.blue,
        ),
        _buildBudgetBar(
          'Wants (30%)',
          wants,
          wantsTarget,
          Colors.green,
        ),
        _buildBudgetBar(
          'Savings (20%)',
          savings,
          savingsTarget,
          Colors.purple,
        ),
      ],
    );
  }

  // Adapted from TransactionAnalysisWidget._buildBudgetBar but simplified
  Widget _buildBudgetBar(
      String label, double actual, double target, Color color) {
    final percentage = target > 0 ? (actual / target).clamp(0.0, 2.0) : 0.0;
    final isOverBudget = percentage > 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(
              FormattingUtils.formatCurrency(actual),
              style: TextStyle(
                color: isOverBudget ? Colors.red : Colors.white70,
                fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        LinearProgressIndicator(
          value: percentage > 1.0 ? 1.0 : percentage, // Cap at 100% for visual
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOverBudget ? Colors.red : color,
          ),
          minHeight: 5, // Even smaller for compact display
        ),
        const SizedBox(height: 4), // Reduced spacing
      ],
    );
  }
}
