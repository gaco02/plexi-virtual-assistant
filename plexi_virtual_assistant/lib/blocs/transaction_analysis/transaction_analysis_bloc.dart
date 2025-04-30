import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../data/repositories/transactions/transaction_repository_new.dart';
import '../../data/models/transaction_analysis.dart';
import '../../data/models/transaction.dart';
import 'transaction_analysis_event.dart';
import 'transaction_analysis_state.dart';

class TransactionAnalysisBloc
    extends Bloc<TransactionAnalysisEvent, TransactionAnalysisState> {
  final TransactionRepository _repository;

  // Cache for analysis and history data
  TransactionAnalysis? _cachedAnalysis;
  Map<String, List<Transaction>>? _cachedHistory;
  // Cache keys to track what data we have
  String? _cachedHistoryPeriod;
  String? _cachedHistoryDate;

  // Track if we're using the combined state
  bool _usingCombinedState = false;

  // Timer for scheduled refresh
  Timer? _scheduledRefreshTimer;

  // Track when the last analysis request was made to prevent redundant requests
  DateTime? _lastAnalysisRequestTime;

  // Debounce timer for analysis requests (not currently used but kept for future implementation)
  Timer? _analysisDebounceTimer;

  // Track when the last network refresh was made (for periodic background syncs)
  DateTime? _lastNetworkSyncTime;

  TransactionAnalysisBloc({required TransactionRepository repository})
      : _repository = repository,
        super(TransactionAnalysisInitial()) {
    on<LoadTransactionAnalysis>(_onLoadAnalysis);
    on<LoadTransactionHistory>(_onLoadHistory);
    on<EditTransactionEvent>(_onEditTransaction);
    on<DeleteTransactionEvent>(_onDeleteTransaction);
    on<RefreshTransactionHistory>(_onRefreshHistory);
    on<ManualRefreshAnalysis>(_onManualRefreshAnalysis);

    // Set up the scheduled refresh timer
    _setupScheduledRefresh();
  }

  @override
  Future<void> close() {
    // Cancel the timers when the bloc is closed
    _scheduledRefreshTimer?.cancel();
    _analysisDebounceTimer?.cancel();
    return super.close();
  }

  // Set up a timer to refresh the analysis at midnight
  void _setupScheduledRefresh() {
    // Cancel any existing timer
    _scheduledRefreshTimer?.cancel();

    // Calculate time until next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);

    // Schedule the first refresh at midnight
    _scheduledRefreshTimer = Timer(timeUntilMidnight, () {
      // Perform the refresh

      add(const ManualRefreshAnalysis());

      // Set up a daily timer for subsequent refreshes
      _scheduledRefreshTimer = Timer.periodic(const Duration(days: 1), (_) {
        add(const ManualRefreshAnalysis());
      });
    });
  }

  // Check if we should process an analysis request or if it's too soon after the last one
  bool _shouldProcessAnalysisRequest(bool forceRefresh) {
    // Always process if it's a force refresh
    if (forceRefresh) return true;

    // If this is the first request, always process it
    if (_lastAnalysisRequestTime == null) return true;

    // Check if enough time has passed since the last request
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastAnalysisRequestTime!);

    // If less than 1 second has passed, don't process unless it's a force refresh
    if (timeSinceLastRequest.inMilliseconds < 1000) {
      return false;
    }

    return true;
  }

  Future<void> _onLoadAnalysis(
    LoadTransactionAnalysis event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    // Cancel any pending debounce timer
    _analysisDebounceTimer?.cancel();

    // Check if we should process this request
    if (!_shouldProcessAnalysisRequest(event.forceRefresh)) {
      return;
    }

    // Update the last request time
    _lastAnalysisRequestTime = DateTime.now();

    // For forced refreshes or if we're using a debounce, load directly
    // This avoids the unawaited future issue
    await _loadAnalysisData(event, emit);
  }

  // Actual implementation of loading analysis data
  Future<void> _loadAnalysisData(
    LoadTransactionAnalysis event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      // If forceRefresh is true, invalidate cache
      if (event.forceRefresh) {
        _cachedAnalysis = null;
        // Also tell the repository to invalidate its caches
        _repository.invalidateTransactionCaches();
      }

      // Only show loading if we don't have cached data and not using combined state
      if (_cachedAnalysis == null && !_usingCombinedState) {
        emit(TransactionAnalysisLoading());
      } else {}

      final analysis = await _repository.getTransactionAnalysis(event.month);

      // Cache the analysis data
      _cachedAnalysis = analysis;

      // If we're using the combined state, update it with the new analysis data
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;

          emit(combinedState.copyWith(analysis: analysis));
        } else {
          emit(TransactionCombinedState(
            analysis: analysis,
            transactionsByDate: _cachedHistory,
          ));
          _usingCombinedState = true;
        }
      } else {
        emit(TransactionAnalysisLoaded(analysis));
      }
    } catch (e) {
      emit(TransactionAnalysisError('Failed to load analysis: $e'));
    }
  }

  Future<void> _onLoadHistory(
    LoadTransactionHistory event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    // Check if we already have data for this period and date and not forcing refresh
    if (!event.forceRefresh &&
        _cachedHistory != null &&
        _cachedHistoryPeriod == event.period &&
        _cachedHistoryDate == event.date) {
      // If we're using the combined state, make sure it has the history data
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;
          if (combinedState.transactionsByDate != _cachedHistory) {
            emit(combinedState.copyWith(transactionsByDate: _cachedHistory));
          }
        } else {
          emit(TransactionCombinedState(
            analysis: _cachedAnalysis,
            transactionsByDate: _cachedHistory,
          ));
          _usingCombinedState = true;
        }
      } else {
        emit(TransactionHistoryLoaded(_cachedHistory!));
      }
      return;
    }

    try {
      // Only show loading if we don't have cached data and not using combined state
      if (_cachedHistory == null && !_usingCombinedState) {
        emit(TransactionHistoryLoading());
      } else {}

      final transactionsByDate = await _repository.getTransactionHistory(
          event.period, event.date, event.forceRefresh);

      // Create a map to store the transactions
      Map<String, List<Transaction>> sortedTransactions;

      if (transactionsByDate.isEmpty) {
        // IMPORTANT: Don't overwrite the cached history with empty data
        // Instead, create an empty map just for this request
        sortedTransactions = {};

        // If we're using the combined state, update it with empty history data for this request
        // but don't update the cache
        if (_usingCombinedState) {
          if (state is TransactionCombinedState) {
            final combinedState = state as TransactionCombinedState;
            emit(
                combinedState.copyWith(transactionsByDate: sortedTransactions));
          } else {
            emit(TransactionCombinedState(
              analysis: _cachedAnalysis,
              transactionsByDate: sortedTransactions,
            ));
            _usingCombinedState = true;
          }
        } else {
          emit(TransactionHistoryLoaded(sortedTransactions));
        }
        return;
      }

      // Sort dates in descending order (newest first)
      final sortedDates = transactionsByDate.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      // Create a new map with sorted dates
      sortedTransactions = <String, List<Transaction>>{};
      for (var date in sortedDates) {
        sortedTransactions[date] = transactionsByDate[date]!;
      }

      // Cache the history data
      _cachedHistory = sortedTransactions;
      _cachedHistoryPeriod = event.period;
      _cachedHistoryDate = event.date;

      // If we're using the combined state, update it with the new history data
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;

          emit(combinedState.copyWith(transactionsByDate: sortedTransactions));
        } else {
          emit(TransactionCombinedState(
            analysis: _cachedAnalysis,
            transactionsByDate: sortedTransactions,
          ));
          _usingCombinedState = true;
        }
      } else {
        emit(TransactionHistoryLoaded(sortedTransactions));
      }
    } catch (e) {
      emit(TransactionHistoryError('Failed to load history: $e'));
    }
  }

  Future<void> _onEditTransaction(
    EditTransactionEvent event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      // Use the repository directly to update the transaction
      final success = await _repository.updateTransaction(
        event.transactionId,
        event.amount,
        event.category,
        event.description,
      );

      if (success) {
        // Force refresh the analysis data after updating a transaction
        add(const ManualRefreshAnalysis(forceRefresh: true));
      } else {}

      // Refresh the transaction history
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    } catch (e) {
      // If there's an error, we'll just refresh the data to show the current state
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransactionEvent event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      // Use the repository directly to delete the transaction
      final success = await _repository.deleteTransaction(event.transactionId);

      if (success) {
        // Force refresh the analysis data after deleting a transaction
        add(const ManualRefreshAnalysis(forceRefresh: true));
      } else {}

      // Refresh the transaction history
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    } catch (e) {
      // If there's an error, we'll just refresh the data to show the current state
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    }
  }

  // Check if we should do a network sync based on time elapsed
  bool _shouldPerformNetworkSync() {
    // Always sync if we've never synced before
    if (_lastNetworkSyncTime == null) return true;

    // Check if it's been at least 1 hour since last sync
    final now = DateTime.now();
    final timeSinceLastSync = now.difference(_lastNetworkSyncTime!);
    return timeSinceLastSync.inMinutes >= 60; // Sync once per hour at most
  }

  Future<void> _onRefreshHistory(
    RefreshTransactionHistory event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      // If we're using combined state, emit a loading indicator
      if (_usingCombinedState && state is TransactionCombinedState) {
        final combinedState = state as TransactionCombinedState;
        emit(combinedState.copyWith(isRefreshing: true));
      }

      // Force refresh from network if:
      // 1. User explicitly requested it via forceRefresh
      // 2. We haven't synced in over an hour
      // 3. We don't have any cached data yet
      final shouldUseNetwork = event.forceRefresh ||
          _shouldPerformNetworkSync() ||
          _cachedAnalysis == null;

      if (shouldUseNetwork) {
        print('TransactionAnalysisBloc: Performing network sync');
        _lastNetworkSyncTime = DateTime.now(); // Update sync timestamp
        _repository.invalidateTransactionCaches();
      } else {
        print(
            'TransactionAnalysisBloc: Using local storage data (network sync not needed)');
      }

      // Get the current month in YYYY-MM format
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Get transaction analysis data (from network or local cache)
      final analysis = shouldUseNetwork
          ? await _repository.forceRefreshAnalysis(currentMonth)
          : await _repository.getTransactionAnalysis(currentMonth);

      // Store in cache
      _cachedAnalysis = analysis;

      // Get transaction history (from network or local cache)
      final history = await _repository.getTransactionHistory(
          _cachedHistoryPeriod ?? 'month',
          _cachedHistoryDate,
          shouldUseNetwork);

      // Store in cache
      _cachedHistory = history;

      // Update the UI with the data
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;
          emit(combinedState.copyWith(
              analysis: analysis,
              transactionsByDate: history,
              isRefreshing: false));
        }
      } else {
        emit(TransactionAnalysisLoaded(analysis));
        emit(TransactionHistoryLoaded(history));
      }

      // Update the last analysis request time
      _lastAnalysisRequestTime = DateTime.now();

      print(
          'TransactionAnalysisBloc: Refresh complete using ${shouldUseNetwork ? "network" : "local"} data. Analysis total - Needs: ${analysis.actual.needs}, Wants: ${analysis.actual.wants}, Savings: ${analysis.actual.savings}');
    } catch (e) {
      print('TransactionAnalysisBloc: Error refreshing history: $e');
      // If there's an error, try to use cached data
      if (_cachedHistoryPeriod != null) {
        add(LoadTransactionHistory(
          period: _cachedHistoryPeriod,
          date: _cachedHistoryDate,
          forceRefresh: false,
        ));
      }

      add(LoadTransactionAnalysis(forceRefresh: false));
    }
  }

  // Handle manual refresh of transaction analysis
  Future<void> _onManualRefreshAnalysis(
    ManualRefreshAnalysis event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      // Emit loading state if we're not using combined state
      if (!_usingCombinedState) {
        emit(TransactionAnalysisLoading());
      } else if (state is TransactionCombinedState) {
        // If using combined state, emit a loading indicator in the combined state
        final combinedState = state as TransactionCombinedState;
        emit(combinedState.copyWith(isRefreshing: true));
      }

      // Get the current month in YYYY-MM format
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // If forceRefresh is true, invalidate caches first
      if (event.forceRefresh) {
        _cachedAnalysis = null;
        _repository.invalidateTransactionCaches();
      }

      // Force refresh the analysis using the repository's forceRefreshAnalysis method
      final analysis = await _repository.forceRefreshAnalysis(currentMonth);

      // Cache the analysis data
      _cachedAnalysis = analysis;

      // Update the state with the new analysis
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;
          emit(combinedState.copyWith(analysis: analysis, isRefreshing: false));
        } else {
          emit(TransactionCombinedState(
            analysis: analysis,
            transactionsByDate: _cachedHistory,
          ));
        }
      } else {
        emit(TransactionAnalysisLoaded(analysis));
      }

      // Also refresh the history data if available
      if (_cachedHistoryPeriod != null && _cachedHistoryDate != null) {
        add(LoadTransactionHistory(
          period: _cachedHistoryPeriod,
          date: _cachedHistoryDate,
          forceRefresh: true,
        ));
      }
    } catch (e) {
      // Handle errors
      if (_usingCombinedState && state is TransactionCombinedState) {
        final combinedState = state as TransactionCombinedState;
        emit(combinedState.copyWith(
            isRefreshing: false,
            errorMessage: 'Failed to refresh: ${e.toString()}'));
      } else {
        emit(TransactionAnalysisError(
            'Failed to refresh analysis: ${e.toString()}'));
      }
    }
  }

  // Method to get the current cached analysis data
  TransactionAnalysis? get cachedAnalysis => _cachedAnalysis;

  // Method to get the current cached history data
  Map<String, List<Transaction>>? get cachedHistory => _cachedHistory;

  // Method to enable the combined state mode
  void enableCombinedState() {
    if (!_usingCombinedState) {
      _usingCombinedState = true;

      // Instead of directly emitting a state, trigger events to refresh the data
      // This avoids the lint error about using emit outside of an event handler
      if (_cachedAnalysis != null) {
        add(const LoadTransactionAnalysis());
      }

      if (_cachedHistory != null &&
          _cachedHistoryPeriod != null &&
          _cachedHistoryDate != null) {
        add(LoadTransactionHistory(
          period: _cachedHistoryPeriod!,
          date: _cachedHistoryDate!,
        ));
      }
    }
  }
}
