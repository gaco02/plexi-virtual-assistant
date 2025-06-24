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
import '../../../data/local/network_connectivity_service.dart';
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
  static bool transactionsInitialized = false;
  static bool analysisInitialized = false;
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
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;

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

    // Set up connectivity status listener
    _setupConnectivityListener();

    // Load initial data after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // Set up connectivity listener
  void _setupConnectivityListener() {
    // Get the initial connectivity status
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final connectivityService = context.read<NetworkConnectivityService>();
      _isOnline = await connectivityService.checkConnectivity();
      setState(() {});

      // Listen for connectivity changes
      _connectivitySubscription =
          connectivityService.connectionStatus.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isOnline = isConnected;
          });

          // If we just came back online, try to sync data
          if (isConnected && !_isLoading) {
            _syncDataIfOnline();
          }
        }
      });
    });
  }

  // Sync data when coming back online
  void _syncDataIfOnline() {
    if (_isOnline) {
      // Load fresh data based on current tab
      _loadDataForCurrentTab(forceRefresh: true, useCache: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only force a refresh if this is the first time loading the screen
    // or if the cache is not initialized
    if (_isFirstLoad ||
        !TransactionDetailsCache.transactionsInitialized ||
        !TransactionDetailsCache.analysisInitialized) {
      _loadDataForCurrentTab(forceRefresh: false);
      _isFirstLoad = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Optimistically update cache and UI when a transaction is added
  void _optimisticAddTransaction(Transaction transaction) {
    setState(() {
      TransactionDetailsCache.transactions.add(transaction);
      TransactionDetailsCache.categoryTotals[transaction.category] =
          (TransactionDetailsCache.categoryTotals[transaction.category] ?? 0) +
              transaction.amount;
      TransactionDetailsCache.monthlyTotal += transaction.amount;
      TransactionDetailsCache.transactionsInitialized = true;
    });
  }

  /// Debounce helper for expensive loads
  void _debounceLoad(Function loadFn,
      {Duration duration = const Duration(milliseconds: 400)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () => loadFn());
  }

  /// Load initial data, using cache when available
  void _loadInitialData() {
    // If cache is already initialized, use it
    if (TransactionDetailsCache.transactionsInitialized &&
        TransactionDetailsCache.analysisInitialized) {
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
    if (useCache &&
        TransactionDetailsCache.transactionsInitialized &&
        TransactionDetailsCache.transactions.isNotEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    _debounceLoad(() {
      context.read<TransactionAnalysisBloc>().add(
            LoadTransactionHistory(
              period: analysisPeriod,
              date: todayStr, // Pass today's date
            ),
          );
    });
  }

  void _loadAnalysisData({bool useCache = false}) {
    final analysisBloc = context.read<TransactionAnalysisBloc>();

    // Use cached analysis data if available and requested
    if (useCache &&
        (analysisBloc.cachedAnalysis != null ||
            TransactionDetailsCache.analysisInitialized)) {
      // If we have cached analysis in the bloc, use it
      if (analysisBloc.cachedAnalysis != null) {
        TransactionDetailsCache.analysis = analysisBloc.cachedAnalysis;
      }

      setState(() => _isLoading = false);
      return;
    }

    // Otherwise, load fresh data
    _debounceLoad(() {
      analysisBloc.add(const LoadTransactionAnalysis());
    });
  }

  /// Load data based on the current tab
  void _loadDataForCurrentTab(
      {bool forceRefresh = false, bool useCache = true}) {
    // Don't reload if we're already loading
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    final transactionBloc = context.read<TransactionBloc>();
    final analysisBloc = context.read<TransactionAnalysisBloc>();

    // First check if we can use cached data
    if (useCache) {
      // For transaction data
      if (TransactionDetailsCache.transactionsInitialized) {
        // For analysis data
        if (TransactionDetailsCache.analysisInitialized ||
            analysisBloc.cachedAnalysis != null) {
          // Use the cached analysis data if available
          if (analysisBloc.cachedAnalysis != null) {
            TransactionDetailsCache.analysis = analysisBloc.cachedAnalysis;
          }

          // If we have all cached data and don't need to force refresh, just update UI
          if (!forceRefresh) {
            setState(() => _isLoading = false);
            return;
          }
        }
      }
    }

    // Only load analysis data when on the analysis tab or when we force a refresh
    if (_tabController.index == 0 || forceRefresh) {
      // Only load new analysis if we don't already have it cached or need to force refresh
      if (analysisBloc.cachedAnalysis == null ||
          !TransactionDetailsCache.analysisInitialized ||
          forceRefresh) {
        analysisBloc.add(const LoadTransactionAnalysis());
      } else {
        // Use the cached analysis data
        TransactionDetailsCache.analysis = analysisBloc.cachedAnalysis;
      }
    }

    // Load data based on the current tab - but don't reload if we have recent data
    if (_tabController.index == 0) {
      // Summary tab - load monthly data only if needed
      transactionBloc.add(LoadMonthlyTransactions(
          forceRefresh: forceRefresh,
          isForWidget: true // This helps bloc know we only need summary data
          ));
    } else {
      // History tab - load transaction history if needed
      if (!TransactionDetailsCache.transactionsInitialized || forceRefresh) {
        context.read<TransactionAnalysisBloc>().add(
              LoadTransactionHistory(
                period: analysisPeriod,
                date: todayStr,
              ),
            );
      }
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
        title: Row(
          children: [
            const Text(
              'Transactions',
              style: TextStyle(color: Colors.white),
            ),
            const Spacer(),
            // Add offline indicator
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
          ],
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

              // Offline message banner when working with local data
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You\'re currently offline. Viewing locally stored data.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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

  // Show dialog to add a new transaction
  void _showAddTransactionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                _isOnline
                    ? 'Your transaction will be saved online'
                    : 'You\'re offline. Your transaction will be saved locally and synced when you\'re back online.',
                style: TextStyle(
                  fontSize: 14,
                  color: _isOnline ? Colors.black54 : Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 16),
              // Add your transaction form here
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // You would add your transaction here
                  // Then refresh data
                  _loadDataForCurrentTab(forceRefresh: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text('Add Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "Summary" tab content
  Widget _buildSummaryTab(BuildContext context) {
    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        // Update cache when new data is loaded
        if (state is TransactionsLoaded) {
          print(
              'TransactionDetailsScreen: Updating cache with new TransactionsLoaded state');
          print(
              'TransactionDetailsScreen: Found ${state.transactions.length} transactions, monthly total: ${state.monthlyAmount}');

          TransactionDetailsCache.transactions = state.transactions;
          TransactionDetailsCache.monthlyTotal = state.monthlyAmount;
          TransactionDetailsCache.categoryTotals =
              _calculateCategoryTotals(state.transactions);
          TransactionDetailsCache.transactionsInitialized = true;

          // Force a UI update
          setState(() => _isLoading = false);
        }
        // Special handling for MonthlySummaryLoaded state - immediately update the monthly total
        else if (state is MonthlySummaryLoaded) {
          print(
              'TransactionDetailsScreen: Received MonthlySummaryLoaded with total: ${state.totalAmount}');

          // If the total has changed, force a data refresh
          if (TransactionDetailsCache.monthlyTotal != state.totalAmount) {
            print(
                'TransactionDetailsScreen: Monthly total changed from ${TransactionDetailsCache.monthlyTotal} to ${state.totalAmount}');
            TransactionDetailsCache.monthlyTotal = state.totalAmount;

            // Immediately request fresh transaction data to get updated categories
            WidgetsBinding.instance.addPostFrameCallback((_) {
              print(
                  'TransactionDetailsScreen: Forcing refresh of transaction data');
              context
                  .read<TransactionBloc>()
                  .add(const LoadMonthlyTransactions(forceRefresh: true));
            });
          }
        } else {
          print('TransactionDetailsScreen: Received non-loaded state: $state');
        }
      },
      child: BlocListener<TransactionAnalysisBloc, TransactionAnalysisState>(
        listener: (context, state) {
          // Update cache when new analysis data is loaded
          if (state is TransactionAnalysisLoaded) {
            TransactionDetailsCache.analysis = state.analysis;
            TransactionDetailsCache.analysisInitialized = true;
            setState(() => _isLoading = false);
          }
        },
        child: BlocBuilder<TransactionBloc, TransactionState>(
          buildWhen: (previous, current) {
            // Debug print to track state transitions
            print(
                'SpendingByCategory buildWhen: previous=$previous, current=$current');

            // Only rebuild when we get meaningful data changes
            if (previous is TransactionsLoaded &&
                current is TransactionsLoaded) {
              return previous.transactions != current.transactions ||
                  previous.monthlyAmount != current.monthlyAmount;
            }
            return previous.runtimeType != current.runtimeType;
          },
          builder: (context, state) {
            // Show loading indicator if we're still loading and have no cached data
            if ((state is TransactionLoading || state is TransactionInitial) &&
                !TransactionDetailsCache.transactionsInitialized) {
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
                              // Debug print to track state transitions
                              print(
                                  'SpendingByCategory buildWhen: previous=$previous, current=$current');

                              // For monthly summary loaded updates, we always want to rebuild
                              if (current is MonthlySummaryLoaded) {
                                print(
                                    'SpendingByCategory buildWhen: Monthly summary loaded with total: ${current.totalAmount}');
                                return true;
                              }

                              // For TransactionsLoaded updates with Monthly period, we always want to rebuild
                              if (current is TransactionsLoaded &&
                                  current.period == 'Month') {
                                print(
                                    'SpendingByCategory buildWhen: Transactions loaded with monthly data: ${current.monthlyAmount}');
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
                              // If we have cached data, use it
                              if (TransactionDetailsCache
                                      .transactionsInitialized &&
                                  TransactionDetailsCache
                                      .categoryTotals.isNotEmpty) {
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
