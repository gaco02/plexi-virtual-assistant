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

    print(
        '⏰ [TransactionAnalysisBloc] Scheduled refresh set for midnight (${nextMidnight.toString()})');
    print(
        '⏱️ [TransactionAnalysisBloc] Time until refresh: ${timeUntilMidnight.inHours}h ${timeUntilMidnight.inMinutes % 60}m');

    // Schedule the first refresh at midnight
    _scheduledRefreshTimer = Timer(timeUntilMidnight, () {
      // Perform the refresh
      print(
          '🔄 [TransactionAnalysisBloc] Executing scheduled midnight refresh');
      add(const ManualRefreshAnalysis());

      // Set up a daily timer for subsequent refreshes
      _scheduledRefreshTimer = Timer.periodic(const Duration(days: 1), (_) {
        print('🔄 [TransactionAnalysisBloc] Executing daily scheduled refresh');
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
      print(
          '⏱️ [TransactionAnalysisBloc] Ignoring redundant analysis request (${timeSinceLastRequest.inMilliseconds}ms since last request)');
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
      print('🛑 [TransactionAnalysisBloc] Skipping redundant analysis request');
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
      print(
          '🔍 [TransactionAnalysisBloc] Loading analysis with forceRefresh: ${event.forceRefresh}');

      // If forceRefresh is true, invalidate cache
      if (event.forceRefresh) {
        _cachedAnalysis = null;
        // Also tell the repository to invalidate its caches
        _repository.invalidateTransactionCaches();
        print(
            '🗑️ [TransactionAnalysisBloc] Invalidated analysis cache due to forceRefresh');
      }

      // Only show loading if we don't have cached data and not using combined state
      if (_cachedAnalysis == null && !_usingCombinedState) {
        emit(TransactionAnalysisLoading());
        print(
            '⏳ [TransactionAnalysisBloc] Emitted TransactionAnalysisLoading state');
      } else {
        print(
            '📋 [TransactionAnalysisBloc] Using cached analysis or combined state');
      }

      final analysis = await _repository.getTransactionAnalysis(event.month);
      print(
          '✅ [TransactionAnalysisBloc] Received analysis data from repository');

      // Cache the analysis data
      _cachedAnalysis = analysis;
      print('💾 [TransactionAnalysisBloc] Cached analysis data in memory');

      // If we're using the combined state, update it with the new analysis data
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;

          emit(combinedState.copyWith(analysis: analysis));
          print(
              '🔄 [TransactionAnalysisBloc] Updated combined state with new analysis');
        } else {
          emit(TransactionCombinedState(
            analysis: analysis,
            transactionsByDate: _cachedHistory,
          ));
          _usingCombinedState = true;
          print(
              '🔄 [TransactionAnalysisBloc] Created new combined state with analysis');
        }
      } else {
        emit(TransactionAnalysisLoaded(analysis));
        print(
            '✅ [TransactionAnalysisBloc] Emitted TransactionAnalysisLoaded state');
      }
    } catch (e) {
      print('❌ [TransactionAnalysisBloc] Error loading analysis: $e');
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
      print('🔄 [TransactionAnalysisBloc] Editing transaction: ${event.transactionId}, amount: ${event.amount}, category: ${event.category}');
      
      // Use the repository directly to update the transaction
      final success = await _repository.updateTransaction(
        event.transactionId,
        event.amount,
        event.category,
        event.description,
      );

      if (success) {
        print('✅ [TransactionAnalysisBloc] Transaction updated successfully, refreshing analysis');
        // Force refresh the analysis data after updating a transaction
        add(const ManualRefreshAnalysis(forceRefresh: true));
      } else {
        print('❌ [TransactionAnalysisBloc] Failed to update transaction');
      }

      // Refresh the transaction history
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    } catch (e) {
      print('❌ [TransactionAnalysisBloc] Error updating transaction: $e');
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
      print('🔄 [TransactionAnalysisBloc] Deleting transaction: ${event.transactionId}');
      
      // Use the repository directly to delete the transaction
      final success = await _repository.deleteTransaction(event.transactionId);

      if (success) {
        print('✅ [TransactionAnalysisBloc] Transaction deleted successfully, refreshing analysis');
        // Force refresh the analysis data after deleting a transaction
        add(const ManualRefreshAnalysis(forceRefresh: true));
      } else {
        print('❌ [TransactionAnalysisBloc] Failed to delete transaction');
      }

      // Refresh the transaction history
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    } catch (e) {
      print('❌ [TransactionAnalysisBloc] Error deleting transaction: $e');
      // If there's an error, we'll just refresh the data to show the current state
      add(LoadTransactionHistory(
        period: _cachedHistoryPeriod,
        date: _cachedHistoryDate,
        forceRefresh: true,
      ));
    }
  }

  Future<void> _onRefreshHistory(
    RefreshTransactionHistory event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      print(
          '🔄 [TransactionAnalysisBloc] Refreshing transaction history and analysis');

      // If we're using combined state, emit a loading indicator
      if (_usingCombinedState && state is TransactionCombinedState) {
        final combinedState = state as TransactionCombinedState;
        emit(combinedState.copyWith(isRefreshing: true));
        print(
            '⏳ [TransactionAnalysisBloc] Updated combined state with isRefreshing=true');
      }

      // Since the repository's logTransaction method already refreshed the data,
      // we just need to fetch the latest data from the repository's cache

      // Get the current month in YYYY-MM format
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      print(
          '📅 [TransactionAnalysisBloc] Fetching latest data for month: $currentMonth');

      // Get the latest analysis data (should be cached from the repository refresh)
      final analysis = await _repository.getTransactionAnalysis(currentMonth);
      print('✅ [TransactionAnalysisBloc] Received latest analysis data');

      // Cache the analysis data
      _cachedAnalysis = analysis;
      print(
          '💾 [TransactionAnalysisBloc] Updated cached analysis data in memory');

      // Get the latest transaction history (should be cached from the repository refresh)
      final history = await _repository.getTransactionHistory(
          _cachedHistoryPeriod ?? 'month',
          _cachedHistoryDate,
          false // Don't force refresh again since repository already did it
          );
      print(
          '✅ [TransactionAnalysisBloc] Received latest transaction history data');

      // Cache the history data
      _cachedHistory = history;
      print(
          '💾 [TransactionAnalysisBloc] Updated cached history data in memory');

      // Emit the appropriate state based on what we're using
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;
          emit(combinedState.copyWith(
              analysis: analysis,
              transactionsByDate: history,
              isRefreshing: false));
          print(
              '✅ [TransactionAnalysisBloc] Updated combined state with latest data');
        }
      } else {
        // Emit separate states for analysis and history
        emit(TransactionAnalysisLoaded(analysis));
        print(
            '✅ [TransactionAnalysisBloc] Emitted TransactionAnalysisLoaded state');

        emit(TransactionHistoryLoaded(history));
        print(
            '✅ [TransactionAnalysisBloc] Emitted TransactionHistoryLoaded state');
      }
    } catch (e) {
      print(
          '❌ [TransactionAnalysisBloc] Error refreshing history and analysis: $e');

      // If there's an error, try to refresh just the data we have cached
      if (_cachedHistoryPeriod != null) {
        add(LoadTransactionHistory(
          period: _cachedHistoryPeriod,
          date: _cachedHistoryDate,
          forceRefresh:
              false, // Don't force refresh to avoid potential infinite loops
        ));
      }

      add(LoadTransactionAnalysis(
          forceRefresh:
              false)); // Don't force refresh to avoid potential infinite loops
    }
  }

  // Handle manual refresh of transaction analysis
  Future<void> _onManualRefreshAnalysis(
    ManualRefreshAnalysis event,
    Emitter<TransactionAnalysisState> emit,
  ) async {
    try {
      print(
          '🔄 [TransactionAnalysisBloc] Manual refresh requested with forceRefresh: ${event.forceRefresh}');

      // Emit loading state if we're not using combined state
      if (!_usingCombinedState) {
        emit(TransactionAnalysisLoading());
        print(
            '⏳ [TransactionAnalysisBloc] Emitted TransactionAnalysisLoading state');
      } else if (state is TransactionCombinedState) {
        // If using combined state, emit a loading indicator in the combined state
        final combinedState = state as TransactionCombinedState;
        emit(combinedState.copyWith(isRefreshing: true));
        print(
            '⏳ [TransactionAnalysisBloc] Updated combined state with isRefreshing=true');
      }

      // Get the current month in YYYY-MM format
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      print('📅 [TransactionAnalysisBloc] Refreshing for month: $currentMonth');

      // If forceRefresh is true, invalidate caches first
      if (event.forceRefresh) {
        _cachedAnalysis = null;
        _repository.invalidateTransactionCaches();
        print(
            '🗑️ [TransactionAnalysisBloc] Invalidated caches due to forceRefresh');
      }

      // Force refresh the analysis using the repository's forceRefreshAnalysis method
      final analysis = await _repository.forceRefreshAnalysis(currentMonth);
      print(
          '✅ [TransactionAnalysisBloc] Received fresh analysis data from repository');

      // Cache the analysis data
      _cachedAnalysis = analysis;
      print(
          '💾 [TransactionAnalysisBloc] Cached fresh analysis data in memory');

      // Update the state with the new analysis
      if (_usingCombinedState) {
        if (state is TransactionCombinedState) {
          final combinedState = state as TransactionCombinedState;
          emit(combinedState.copyWith(analysis: analysis, isRefreshing: false));
          print(
              '✅ [TransactionAnalysisBloc] Updated combined state with fresh analysis');
        } else {
          emit(TransactionCombinedState(
            analysis: analysis,
            transactionsByDate: _cachedHistory,
          ));
          print(
              '✅ [TransactionAnalysisBloc] Created new combined state with fresh analysis');
        }
      } else {
        emit(TransactionAnalysisLoaded(analysis));
        print(
            '✅ [TransactionAnalysisBloc] Emitted TransactionAnalysisLoaded state with fresh data');
      }

      // Also refresh the history data if available
      if (_cachedHistoryPeriod != null && _cachedHistoryDate != null) {
        print(
            '🔄 [TransactionAnalysisBloc] Also refreshing transaction history');
        add(LoadTransactionHistory(
          period: _cachedHistoryPeriod,
          date: _cachedHistoryDate,
          forceRefresh: true,
        ));
      }
    } catch (e) {
      print('❌ [TransactionAnalysisBloc] Error during manual refresh: $e');
      // Handle errors
      if (_usingCombinedState && state is TransactionCombinedState) {
        final combinedState = state as TransactionCombinedState;
        emit(combinedState.copyWith(
            isRefreshing: false,
            errorMessage: 'Failed to refresh: ${e.toString()}'));
        print(
            '⚠️ [TransactionAnalysisBloc] Updated combined state with error message');
      } else {
        emit(TransactionAnalysisError(
            'Failed to refresh analysis: ${e.toString()}'));
        print(
            '⚠️ [TransactionAnalysisBloc] Emitted TransactionAnalysisError state');
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
