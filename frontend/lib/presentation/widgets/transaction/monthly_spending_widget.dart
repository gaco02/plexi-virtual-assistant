import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/transaction/transaction_bloc.dart';
import '../../../blocs/transaction/transaction_state.dart';
import '../../../blocs/transaction/transaction_event.dart';
import '../../screens/transaction/transaction_details_screen.dart';
import '../../screens/transaction/transaction_onboarding_screen.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../transaction/budget_pie_chart.dart';

class MonthlySpendingWidget extends StatefulWidget {
  const MonthlySpendingWidget({super.key});

  @override
  State<MonthlySpendingWidget> createState() => _MonthlySpendingWidgetState();
}

class _MonthlySpendingWidgetState extends State<MonthlySpendingWidget> {
  @override
  void initState() {
    super.initState();
    // Load monthly transactions when the widget is initialized
    _loadMonthlyTransactions();
  }

  void _loadMonthlyTransactions() {
    context.read<TransactionBloc>().add(
          const LoadMonthlyTransactions(isForWidget: true),
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
                // Reload monthly transactions when returning from details screen
                _loadMonthlyTransactions();

                // IMPORTANT: Also reload daily transactions to fix the bug
                // where today's spending shows 0 when returning from monthly spending screen
                context.read<TransactionBloc>().add(
                      const LoadDailyTransactions(isForWidget: true),
                    );
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and amount in one row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Spent',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    BlocBuilder<TransactionBloc, TransactionState>(
                      buildWhen: (previous, current) {
                        return current is TransactionsLoaded ||
                            current is MonthlySummaryLoaded;
                      },
                      builder: (context, state) {
                        // Get the total amount from the appropriate state
                        double monthlySpent = 0.0;
                        if (state is MonthlySummaryLoaded) {
                          monthlySpent = state.totalAmount;
                        } else if (state is TransactionsLoaded) {
                          monthlySpent = state.monthlyAmount;
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '\$',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              monthlySpent.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Monthly spending progress chart
                Expanded(
                  child: BlocBuilder<TransactionBloc, TransactionState>(
                    buildWhen: (previous, current) {
                      // Only rebuild for monthly transaction state changes
                      return current is TransactionsLoaded ||
                          current is MonthlySummaryLoaded;
                    },
                    builder: (context, state) {
                      if (state is TransactionLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Get the total amount from the appropriate state
                      double monthlySpent = 0.0;
                      if (state is MonthlySummaryLoaded) {
                        monthlySpent = state.totalAmount;
                      } else if (state is TransactionsLoaded) {
                        monthlySpent = state.monthlyAmount;
                      }

                      // Get monthly budget from preferences
                      double monthlyBudget = 0.0;
                      if (prefsState is PreferencesLoaded) {
                        monthlyBudget =
                            prefsState.preferences.monthlySalary ?? 0.0;
                      }

                      return Center(
                        child: BudgetPieChart(
                          spentAmount: monthlySpent,
                          totalBudget: monthlyBudget,
                          chartSize: 120.0,
                          centerFontSize: 18.0,
                          labelFontSize: 10.0,
                          spentColor: Colors.amber,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
