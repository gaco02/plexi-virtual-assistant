import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/transaction/transaction_bloc.dart';
import '../../../blocs/transaction/transaction_state.dart';
import '../../../blocs/transaction/transaction_event.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_state.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../data/models/transaction_analysis.dart';
import '../../screens/transaction/transaction_details_screen.dart';
import '../../screens/transaction/transaction_onboarding_screen.dart';
import '../common/transparent_card.dart';
import '../../../utils/formatting_utils.dart';
import './budget_pie_chart.dart';
import '../skeleton/skeleton_calorie_summary.dart';

// Global cache for monthly spending amount to persist across widget instances
double _cachedMonthlyAmount = 0.0;
double _cachedTodayAmount = 0.0;
TransactionAnalysis? _cachedAnalysis;

class SpendingSummary extends StatefulWidget {
  final bool isInTransactionDetailsScreen;

  // Remove const constructor to allow state to be maintained
  SpendingSummary({
    super.key,
    this.isInTransactionDetailsScreen = false,
  });

  @override
  State<SpendingSummary> createState() => _SpendingSummaryState();
}

class _SpendingSummaryState extends State<SpendingSummary>
    with AutomaticKeepAliveClientMixin {
  late TransactionBloc _transactionBloc;
  late TransactionAnalysisBloc _analysisBloc;
  bool _mounted = true;
  bool _isLoadingStarted = false;
  bool _showSkeleton = true; // Flag specifically for UI state

  // Override wantKeepAlive to true to maintain state when widget is not visible
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _mounted = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _transactionBloc = context.read<TransactionBloc>();
    _analysisBloc = context.read<TransactionAnalysisBloc>();

    // Load transaction data if not already loaded
    _loadData();

    // Ensure we transition from skeleton after a reasonable timeout
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showSkeleton) {
        setState(() {
          _showSkeleton = false;
        });
      }
    });
  }

  // We don't need didPopNext since we're not using RouteObserver

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mounted) return;

      // Use a flag to track if we've already started loading
      if (_isLoadingStarted) {
        // Even if we're already loading, check if we can transition from skeleton
        // This handles the case where we navigate back to this screen
        if (_showSkeleton && _cachedMonthlyAmount > 0) {
          setState(() {
            _showSkeleton = false;
          });
        }
        return;
      }

      // Set flag to indicate we've started loading
      _isLoadingStarted = true;

      // Use a small delay to prevent multiple requests firing simultaneously
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_mounted) return;

        // Load daily transactions first
        _transactionBloc.add(const LoadDailyTransactions(isForWidget: true));

        // Then load monthly transactions after a small delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_mounted) return;
          _transactionBloc
              .add(const LoadMonthlyTransactions(isForWidget: true));

          // Finally load transaction analysis after another small delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!_mounted) return;
            if (_analysisBloc.cachedAnalysis == null &&
                _cachedAnalysis == null) {
              _analysisBloc.add(const LoadTransactionAnalysis());
            } else {
              // If we already have cached analysis data, we can show the UI
              if (_showSkeleton) {
                setState(() {
                  _showSkeleton = false;
                });
              }
            }
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Show skeleton immediately on first build
    if (_showSkeleton) {
      // Return skeleton UI immediately for better perceived performance
      return MultiBlocListener(
        listeners: [
          BlocListener<TransactionBloc, TransactionState>(
            listener: (context, state) {
              // When transaction data is loaded, check if we can transition
              if (state is TransactionsLoaded) {
                // Cache the monthly amount for future use
                _cachedMonthlyAmount = state.monthlyAmount;
                _cachedTodayAmount = state.todayAmount;
                _checkAndTransitionFromSkeleton();
              } else if (state is MonthlySummaryLoaded) {
                // Cache the monthly amount for future use
                _cachedMonthlyAmount = state.totalAmount;
                _checkAndTransitionFromSkeleton();
              } else if (state is DailySummaryLoaded) {
                // Cache the daily amount for future use
                _cachedTodayAmount = state.totalAmount;
                _checkAndTransitionFromSkeleton();
              }
            },
          ),
          BlocListener<TransactionAnalysisBloc, TransactionAnalysisState>(
            listener: (context, state) {
              // When analysis data is loaded, check if we can transition
              if (state is TransactionAnalysisLoaded) {
                // Cache the analysis for future use
                _cachedAnalysis = state.analysis;
                _checkAndTransitionFromSkeleton();
              }
            },
          ),
          BlocListener<PreferencesBloc, PreferencesState>(
            listener: (context, state) {
              if (state is PreferencesLoaded) {
                // Check for preferences even without transaction data
                _checkAndTransitionFromSkeleton();
              }
            },
          ),
        ],
        child: const SkeletonCalorieSummary(),
      );
    }

    // After we're no longer showing the skeleton, check preferences first
    final preferencesState = context.watch<PreferencesBloc>().state;
    if (preferencesState is PreferencesLoaded &&
        (preferencesState.preferences.monthlySalary == null ||
            preferencesState.preferences.monthlySalary == 0)) {
      return _buildOnboardingPrompt(context);
    }

    return BlocBuilder<TransactionBloc, TransactionState>(
      buildWhen: (previous, current) {
        // Only rebuild if there's a meaningful change in the data
        if (previous is TransactionsLoaded && current is TransactionsLoaded) {
          // Check if any relevant data has actually changed
          return previous.transactions != current.transactions ||
              previous.monthlyAmount != current.monthlyAmount;
        }

        // Always rebuild when state type changes
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, state) {
        return BlocBuilder<TransactionAnalysisBloc, TransactionAnalysisState>(
          buildWhen: (previous, current) {
            // Only rebuild if there's a meaningful change in the analysis data
            if (previous is TransactionAnalysisLoaded &&
                current is TransactionAnalysisLoaded) {
              return previous.analysis != current.analysis;
            }

            // Always rebuild when state type changes (except for Loading -> Loaded)
            if (previous is TransactionAnalysisLoading &&
                current is TransactionAnalysisLoaded) {
              return true;
            }

            return previous.runtimeType != current.runtimeType;
          },
          builder: (context, analysisState) {
            // If we're still in the initial loading state, show the skeleton UI
            if ((state is TransactionInitial || state is TransactionLoading) &&
                (analysisState is TransactionAnalysisInitial ||
                    analysisState is TransactionAnalysisLoading) &&
                _analysisBloc.cachedAnalysis == null &&
                _cachedAnalysis == null) {
              return const SkeletonCalorieSummary();
            }

            // Get monthly budget from preferences
            final preferencesState = context.watch<PreferencesBloc>().state;
            final monthlyBudget = preferencesState is PreferencesLoaded
                ? preferencesState.preferences.monthlySalary ?? 0.0
                : 0.0;

            // Get monthly spent from transaction state
            double monthlySpent =
                _cachedMonthlyAmount; // Use cached value by default
            if (state is TransactionsLoaded) {
              monthlySpent = state.monthlyAmount;
              // Update cached values
              _cachedMonthlyAmount = monthlySpent;
              _cachedTodayAmount = state.todayAmount;
            } else if (state is MonthlySummaryLoaded) {
              monthlySpent = state.totalAmount;
              // Update cached value
              _cachedMonthlyAmount = monthlySpent;
            }

            // Get transaction analysis data
            TransactionAnalysis? analysis;
            if (analysisState is TransactionAnalysisLoaded) {
              analysis = analysisState.analysis;
              _cachedAnalysis = analysis; // Update cached analysis
            } else if (_analysisBloc.cachedAnalysis != null) {
              // Use cached analysis if available
              analysis = _analysisBloc.cachedAnalysis;
              _cachedAnalysis = analysis; // Update cached analysis
            } else if (_cachedAnalysis != null) {
              // Use our own cached analysis if available
              analysis = _cachedAnalysis;
            }

            // If we have preferences but no budget, show onboarding
            if (preferencesState is PreferencesLoaded &&
                (preferencesState.preferences.monthlySalary == null ||
                    preferencesState.preferences.monthlySalary == 0)) {
              return _buildOnboardingPrompt(context);
            }

            // Build the spending card with the data we have
            return _buildSpendingCard(
                context, monthlySpent, monthlyBudget, analysis);
          },
        );
      },
    );
  }

  // Helper method to check if we can transition from skeleton to actual UI
  void _checkAndTransitionFromSkeleton() {
    if (!_mounted || !_showSkeleton) return;

    // Check if both transaction and analysis data are loaded
    final transactionState = _transactionBloc.state;
    final analysisState = _analysisBloc.state;
    final preferencesState = context.read<PreferencesBloc>().state;

    // Transition if we have either:
    // 1. Both transaction and analysis data loaded
    // 2. Cached monthly amount and either analysis data or cached analysis
    bool hasTransactionData = transactionState is TransactionsLoaded ||
        transactionState is MonthlySummaryLoaded ||
        _cachedMonthlyAmount > 0;

    bool hasAnalysisData = analysisState is TransactionAnalysisLoaded ||
        _analysisBloc.cachedAnalysis != null ||
        _cachedAnalysis != null;

    bool hasPreferences = preferencesState is PreferencesLoaded;
    bool hasBudget = hasPreferences &&
        (preferencesState as PreferencesLoaded).preferences.monthlySalary !=
            null &&
        (preferencesState as PreferencesLoaded).preferences.monthlySalary! > 0;

    // If we have a timeout or we have loaded enough data, transition from skeleton
    if ((hasTransactionData && hasAnalysisData) ||
        (!hasTransactionData && hasPreferences)) {
      setState(() {
        _showSkeleton = false;
      });
    }
  }

  Widget _buildSpendingCard(BuildContext context, double monthlySpent,
      double monthlyBudget, TransactionAnalysis? analysis) {
    // Default values for budget categories
    double needsActual = 0.0;
    double wantsActual = 0.0;
    double savingsActual = 0.0;
    double needsTarget = monthlyBudget * 0.5;
    double wantsTarget = monthlyBudget * 0.3;
    double savingsTarget = monthlyBudget * 0.2;

    // Use actual analysis data if available
    if (analysis != null) {
      needsActual = analysis.actual.needs;
      wantsActual = analysis.actual.wants;
      savingsActual = analysis.actual.savings;
      needsTarget = analysis.ideal.needs;
      wantsTarget = analysis.ideal.wants;
      savingsTarget = analysis.ideal.savings;
    } else {}

    return TransparentCard(
      onTap: widget.isInTransactionDetailsScreen
          ? null
          : () {
              // Check if user has necessary preferences before navigating
              final prefsState = context.read<PreferencesBloc>().state;
              if (prefsState is PreferencesLoaded &&
                  prefsState.preferences.monthlySalary != null) {
                // User has necessary preferences, navigate to details screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailsScreen(),
                  ),
                ).then((_) {
                  // Check if widget is still mounted before accessing context
                  if (!_mounted) return;

                  // Reload data when returning from details screen
                  // Always load daily transactions to ensure today's spending is up to date
                  _transactionBloc
                      .add(const LoadDailyTransactions(isForWidget: true));

                  // Also load monthly transactions
                  _transactionBloc
                      .add(const LoadMonthlyTransactions(isForWidget: true));

                  // Only reload analysis data if it's not already cached
                  if (_analysisBloc.cachedAnalysis == null) {
                    _analysisBloc.add(const LoadTransactionAnalysis());
                  } else {}
                });
              } else {
                // User is missing necessary preferences, navigate to onboarding
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionOnboardingScreen(),
                  ),
                );
              }
            },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Spending',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Add spending summary below the header
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Layout with pie chart on left and budget bars on right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left side: Budget Pie Chart
                      Expanded(
                        flex: 5,
                        child: BudgetPieChart(
                          spentAmount: monthlySpent,
                          totalBudget: monthlyBudget,
                          chartSize: 150.0, // Reduced size to prevent overflow
                          centerFontSize: 20.0, // Slightly smaller font
                          labelFontSize: 30.0, // Slightly smaller font
                          spentColor: Colors.amber,
                        ),
                      ),
                      // Right side: Budget Category Bars
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 12.0), // Reduced padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBudgetBar(
                                'Needs',
                                needsActual,
                                needsTarget,
                                Colors.lightBlueAccent,
                              ),
                              _buildBudgetBar(
                                'Wants',
                                wantsActual,
                                wantsTarget,
                                Colors.orange,
                              ),
                              _buildBudgetBar(
                                'Savings',
                                savingsActual,
                                savingsTarget,
                                Colors.lightGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Add Today's Spending in a separate row below
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Today Spent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        BlocBuilder<TransactionBloc, TransactionState>(
                          buildWhen: (previous, current) {
                            return current is TransactionsLoaded ||
                                current is DailySummaryLoaded;
                          },
                          builder: (context, state) {
                            // Use cached value by default
                            double todayAmount = _cachedTodayAmount;
                            if (state is DailySummaryLoaded) {
                              todayAmount = state.totalAmount;
                              _cachedTodayAmount = todayAmount;
                            } else if (state is TransactionsLoaded) {
                              todayAmount = state.todayAmount;
                              _cachedTodayAmount = todayAmount;
                            }

                            return Text(
                              FormattingUtils.formatCurrency(todayAmount),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(8), // Rounded corners
          child: LinearProgressIndicator(
            value: percentage > 1.0 ? 1.0 : percentage,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverBudget ? Colors.red : color,
            ),
            minHeight: 10.0, // Reduced height
          ),
        ),
        const SizedBox(height: 10), // Reduced spacing
      ],
    );
  }

  Widget _buildOnboardingPrompt(BuildContext context) {
    return TransparentCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up your budget to track your spending',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please set your monthly budget to enable spending tracking.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionOnboardingScreen(),
                  ),
                );
              },
              child: const Text('Set up budget'),
            ),
          ],
        ),
      ),
    );
  }
}
