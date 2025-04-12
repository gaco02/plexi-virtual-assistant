import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../../blocs/transaction/transaction_bloc.dart';
import '../../../blocs/transaction/transaction_state.dart';
import '../../../blocs/transaction/transaction_event.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_state.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/transaction_analysis.dart';
import '../../widgets/transaction/transaction_analysis.dart';
import '../../widgets/transaction/transaction_history.dart';
import '../../widgets/transaction/spending_summary.dart';
import '../../widgets/transaction/spending_by_category.dart';
import '../../widgets/common/app_background.dart';

// Global cache for transaction details screen
class TransactionDetailsCache {
  static List<Transaction> transactions = [];
  static Map<TransactionCategory, double> categoryTotals = {};
  static double monthlyTotal = 0.0;
  static TransactionAnalysis? analysis;
  static bool isInitialized = false;
}

class TransactionDetailsScreen extends StatefulWidget {
  const TransactionDetailsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  Timer? _debounceTimer;
  int _previousTabIndex = 0;
  bool _isFirstLoad = true;
  bool _isLoading = false;

  // We'll now always use 'Month' as our default period
  String _selectedTimeFrame = 'Month';
  DateTime todayDate = DateTime.now();
  String get todayStr => DateFormat('yyyy-MM-dd').format(todayDate);

  // Get the analysis period based on the selected time frame
  String get analysisPeriod => _getAnalysisPeriod();

  // Override wantKeepAlive to true to maintain state when widget is not visible
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);

    // Add listener for tab changes
    _tabController.addListener(() {
      // Only process if this is a real tab change (not during animation)
      if (!_tabController.indexIsChanging) {
        _previousTabIndex = _tabController.index;

        // If switching to the history tab (index 1)
        if (_tabController.index == 1) {
          _loadHistoryData(useCache: true);
        } else if (_tabController.index == 0) {
          // If switching to the analysis tab (index 0)
          _loadAnalysisData(useCache: true);
        }
      }
    });

    // Load initial data after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only force a refresh if this is the first time loading the screen
    // or if the cache is not initialized
    if (_isFirstLoad || !TransactionDetailsCache.isInitialized) {
      _loadDataForCurrentTab(forceRefresh: false);
      _isFirstLoad = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Load initial data, using cache when available
  void _loadInitialData() {
    // If cache is already initialized, use it
    if (TransactionDetailsCache.isInitialized) {
      print('📋 [TransactionDetailsScreen] Using cached data for initial load');

      // Update the UI with cached data
      if (_tabController.index == 0) {
        // Analysis tab - use cached analysis data
        _loadAnalysisData(useCache: true);
      } else {
        // History tab - use cached history data
        _loadHistoryData(useCache: true);
      }
      return;
    }

    // Otherwise, load fresh data
    print(
        '🔄 [TransactionDetailsScreen] No cached data, performing initial load');
    setState(() => _isLoading = true);

    // Load transactions for the selected period (always Month now)
    context
        .read<TransactionBloc>()
        .add(LoadTransactionsByPeriod(_selectedTimeFrame));

    // Load analysis data
    _loadAnalysisData(useCache: false);

    // If the history tab is initially selected, load history data
    if (_tabController.index == 1) {
      _loadHistoryData(useCache: false);
    }

    // Mark cache as initialized
    TransactionDetailsCache.isInitialized = true;
  }

  /// Convert the selected time frame to an analysis period
  String _getAnalysisPeriod() {
    switch (_selectedTimeFrame) {
      case 'Today':
        return 'day';
      case 'Week':
        return 'week';
      case 'Month':
        return 'month';
      default:
        return 'day';
    }
  }

  /// Load transaction history data
  void _loadHistoryData({bool useCache = false}) {
    if (useCache && TransactionDetailsCache.transactions.isNotEmpty) {
      print('📋 [TransactionDetailsScreen] Using cached history data');
      setState(() => _isLoading = false);
      return;
    }

    print('🔄 [TransactionDetailsScreen] Loading fresh history data');
    context.read<TransactionAnalysisBloc>().add(
          LoadTransactionHistory(
            period: analysisPeriod,
            date: todayStr, // Pass today's date
          ),
        );
  }

  void _loadAnalysisData({bool useCache = false}) {
    final analysisBloc = context.read<TransactionAnalysisBloc>();

    // Use cached analysis data if available and requested
    if (useCache &&
        (analysisBloc.cachedAnalysis != null ||
            TransactionDetailsCache.analysis != null)) {
      print('📋 [TransactionDetailsScreen] Using cached analysis data');

      // If we have cached analysis in the bloc, use it
      if (analysisBloc.cachedAnalysis != null) {
        TransactionDetailsCache.analysis = analysisBloc.cachedAnalysis;
      }

      setState(() => _isLoading = false);
      return;
    }

    // Otherwise, load fresh data
    print('🔄 [TransactionDetailsScreen] Loading fresh analysis data');
    analysisBloc.add(const LoadTransactionAnalysis());
  }

  /// Load data based on the current tab
  void _loadDataForCurrentTab(
      {bool forceRefresh = false, bool useCache = true}) {
    if (_isLoading) {
      print(
          '⏳ [TransactionDetailsScreen] Already loading data, skipping redundant request');
      return;
    }

    setState(() => _isLoading = true);

    final transactionBloc = context.read<TransactionBloc>();
    final analysisBloc = context.read<TransactionAnalysisBloc>();

    // Use cached data if available and requested
    if (useCache && TransactionDetailsCache.isInitialized) {
      print('📋 [TransactionDetailsScreen] Using cached data for current tab');
      setState(() => _isLoading = false);
      return;
    }

    // Only load analysis data if it's not already cached
    if (analysisBloc.cachedAnalysis == null &&
        TransactionDetailsCache.analysis == null) {
      print(
          '🔄 [TransactionDetailsScreen] No cached analysis data, requesting initial load');
      analysisBloc.add(const LoadTransactionAnalysis());
    } else {
      print(
          '📋 [TransactionDetailsScreen] Using cached analysis data, skipping refresh');
    }

    // Load data based on the current tab
    if (_tabController.index == 0) {
      // Summary tab - load monthly data
      transactionBloc.add(LoadMonthlyTransactions(forceRefresh: forceRefresh));
    } else {
      // History tab - load transaction history
      context.read<TransactionAnalysisBloc>().add(
            LoadTransactionHistory(
              period: analysisPeriod,
              date: todayStr,
            ),
          );
    }
  }

  /// Calculate category totals from transactions
  Map<TransactionCategory, double> _calculateCategoryTotals(
      List<Transaction> transactions) {
    final categoryTotals = <TransactionCategory, double>{};

    for (final transaction in transactions) {
      final category = transaction.category;
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + transaction.amount;
    }

    return categoryTotals;
  }

  /// Filter transactions to get only those from the current month
  List<Transaction> _filterMonthlyTransactions(List<Transaction> transactions) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return transactions.where((tx) {
      return tx.timestamp.isAfter(firstDayOfMonth) ||
          (tx.timestamp.year == firstDayOfMonth.year &&
              tx.timestamp.month == firstDayOfMonth.month &&
              tx.timestamp.day == firstDayOfMonth.day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Transactions',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'History'),
          ],
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Wrap TabBarView in Expanded
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(context),
                    TransactionHistory(
                      period: analysisPeriod,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "Summary" tab content
  Widget _buildSummaryTab(BuildContext context) {
    print("Building summary tab");
    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        // Update cache when new data is loaded
        if (state is TransactionsLoaded) {
          print(
              "Updating transaction cache with ${state.transactions.length} transactions");
          TransactionDetailsCache.transactions = state.transactions;
          TransactionDetailsCache.monthlyTotal = state.monthlyAmount;
          TransactionDetailsCache.categoryTotals =
              _calculateCategoryTotals(state.transactions);
          TransactionDetailsCache.isInitialized = true;
          setState(() => _isLoading = false);
        }
      },
      child: BlocListener<TransactionAnalysisBloc, TransactionAnalysisState>(
        listener: (context, state) {
          // Update cache when new analysis data is loaded
          if (state is TransactionAnalysisLoaded) {
            print("Updating analysis cache");
            TransactionDetailsCache.analysis = state.analysis;
            TransactionDetailsCache.isInitialized = true;
            setState(() => _isLoading = false);
          }
        },
        child: BlocBuilder<TransactionBloc, TransactionState>(
          buildWhen: (previous, current) {
            // Only rebuild when we get meaningful data changes
            if (previous is TransactionsLoaded &&
                current is TransactionsLoaded) {
              return previous.transactions != current.transactions ||
                  previous.monthlyAmount != current.monthlyAmount;
            }
            return previous.runtimeType != current.runtimeType;
          },
          builder: (context, state) {
            print("TransactionBloc state: $state");

            // Show loading indicator if we're still loading and have no cached data
            if ((state is TransactionLoading || state is TransactionInitial) &&
                !TransactionDetailsCache.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            // We'll handle any loaded state (TransactionsLoaded, MonthlySummaryLoaded, DailySummaryLoaded)
            // by showing the SpendingSummary widget which can handle all these states
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Wrap the content in a scrollable container
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // The SpendingSummary widget handles all state types
                          SpendingSummary(isInTransactionDetailsScreen: true),

                          // Show category breakdown
                          BlocBuilder<TransactionBloc, TransactionState>(
                            key: const ValueKey('spending_by_category'),
                            buildWhen: (previous, current) {
                              // Always rebuild when we have a new TransactionsLoaded state
                              if (current is TransactionsLoaded) {
                                return true;
                              }

                              // Don't rebuild when transitioning between loading states
                              if (previous is TransactionLoading &&
                                  current is TransactionLoading) {
                                return false;
                              }

                              // Always rebuild when transitioning from a non-loaded to loaded state
                              if ((current is TransactionsLoaded ||
                                      current is MonthlySummaryLoaded) &&
                                  !(previous is TransactionsLoaded ||
                                      previous is MonthlySummaryLoaded)) {
                                return true;
                              }

                              return false;
                            },
                            builder: (context, state) {
                              print(
                                  "Building category breakdown with state: $state");

                              // If we have cached data, use it
                              if (TransactionDetailsCache.isInitialized &&
                                  TransactionDetailsCache
                                      .categoryTotals.isNotEmpty) {
                                print("Using cached category totals");
                                return SpendingByCategory(
                                  categoryTotals:
                                      TransactionDetailsCache.categoryTotals,
                                  totalAmount:
                                      TransactionDetailsCache.monthlyTotal,
                                  monthlyBudget: context
                                          .read<PreferencesBloc>()
                                          .state is PreferencesLoaded
                                      ? (context.read<PreferencesBloc>().state
                                              as PreferencesLoaded)
                                          .preferences
                                          .monthlySalary
                                      : null,
                                  onViewAll: () {
                                    // Force refresh of transactions when "View All" is tapped
                                    context.read<TransactionBloc>().add(
                                        const LoadMonthlyTransactions(
                                            forceRefresh: true));
                                  },
                                );
                              }

                              // For TransactionsLoaded state, always use monthly data
                              if (state is TransactionsLoaded) {
                                // Always filter to get monthly transactions
                                final monthlyTransactions =
                                    _filterMonthlyTransactions(
                                        state.transactions);
                                print(
                                    "Filtered ${state.transactions.length} transactions to ${monthlyTransactions.length} monthly transactions");

                                // Calculate category totals from monthly transactions
                                final categoryTotals = _calculateCategoryTotals(
                                    monthlyTransactions);

                                // Update the cache with monthly data
                                TransactionDetailsCache.categoryTotals =
                                    categoryTotals;
                                TransactionDetailsCache.monthlyTotal =
                                    state.monthlyAmount;

                                return SpendingByCategory(
                                  categoryTotals: categoryTotals,
                                  totalAmount: state.monthlyAmount,
                                  monthlyBudget: context
                                          .read<PreferencesBloc>()
                                          .state is PreferencesLoaded
                                      ? (context.read<PreferencesBloc>().state
                                              as PreferencesLoaded)
                                          .preferences
                                          .monthlySalary
                                      : null,
                                  onViewAll: () {
                                    // Force refresh of transactions when "View All" is tapped
                                    context.read<TransactionBloc>().add(
                                        const LoadMonthlyTransactions(
                                            forceRefresh: true));
                                  },
                                );
                              }

                              // If we don't have data yet, show a loading indicator
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                          ),

                          // Show transaction analysis widget
                          BlocBuilder<TransactionAnalysisBloc,
                              TransactionAnalysisState>(
                            buildWhen: (previous, current) {
                              // Only rebuild when we have meaningful data changes
                              if (previous is TransactionAnalysisLoaded &&
                                  current is TransactionAnalysisLoaded) {
                                return previous.analysis != current.analysis;
                              }
                              return previous.runtimeType !=
                                  current.runtimeType;
                            },
                            builder: (context, state) {
                              // Use cached analysis if available
                              if (TransactionDetailsCache.analysis != null) {
                                return TransactionAnalysisWidget(
                                  analysis: TransactionDetailsCache.analysis!,
                                );
                              }

                              if (state is TransactionAnalysisLoaded) {
                                // Update cache
                                TransactionDetailsCache.analysis =
                                    state.analysis;

                                return TransactionAnalysisWidget(
                                  analysis: state.analysis,
                                );
                              }

                              // Show loading indicator while waiting for analysis data
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
