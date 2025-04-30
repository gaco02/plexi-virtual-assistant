import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/models/budget_analysis.dart';
import '../../data/models/transaction.dart';
import 'budget_event.dart';
import 'budget_state.dart';
import '../chat/chat_bloc.dart';
import '../chat/chat_state.dart';
import '../transaction/transaction_bloc.dart';
import '../transaction/transaction_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final BudgetRepository _repository;
  final ChatBloc _chatBloc;
  final TransactionBloc _transactionBloc;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _transactionSubscription;

  // Cache for today's budget analysis
  BudgetAnalysis? _todaysBudgetCache;

  // Track last fetch time to prevent too frequent API calls
  DateTime _lastBudgetFetch = DateTime.now().subtract(const Duration(days: 1));

  BudgetBloc(this._repository, this._chatBloc, this._transactionBloc)
      : super(BudgetInitial()) {
    _chatSubscription = _chatBloc.stream.listen(
      (state) {
        if (state is ChatMessageState) {
          // Check if the response contains expense_info, regardless of which tool was used
          final expenseInfo = state.responseData?['expense_info'];
          if (expenseInfo != null && expenseInfo is Map<String, dynamic>) {
            // Use the data we have by adding an event
            add(UpdateBudgetFromExpenseInfo(expenseInfo));
          } else {}
        }
      },
    );

    // Listen to the TransactionBloc state changes
    _transactionSubscription = _transactionBloc.stream.listen(
      (state) {
        // When daily summary is loaded with new data, update the budget
        // Only refresh if explicitly requested or when the data actually changes
        if (state is DailySummaryLoaded) {
          // Check if we have recent data before forcing a refresh
          final timeSinceLastFetch =
              DateTime.now().difference(_lastBudgetFetch);
          final shouldRefresh = timeSinceLastFetch.inMinutes >= 5;
          add(LoadTodaysBudget(forceRefresh: shouldRefresh));
        }

        // When transactions are loaded with new data, update the budget
        // Only refresh if the transactions might have changed
        if (state is TransactionsLoaded && state.isInitialLoad != false) {
          // Check if we have recent data before forcing a refresh
          final timeSinceLastFetch =
              DateTime.now().difference(_lastBudgetFetch);
          final shouldRefresh = timeSinceLastFetch.inMinutes >= 5;
          add(LoadTodaysBudget(forceRefresh: shouldRefresh));
        }
      },
    );

    // Immediately check the current state of ChatBloc, in case it was emitted before subscription.
    final currentState = _chatBloc.state;
    if (currentState is ChatMessageState) {
      // Check if the response contains expense_info, regardless of which tool was used
      final expenseInfo = currentState.responseData?['expense_info'];
      if (expenseInfo != null && expenseInfo is Map<String, dynamic>) {
        // Use the same method to update from expense_info
        add(UpdateBudgetFromExpenseInfo(expenseInfo));
      } else {}
    }

    on<LoadBudgetAnalysis>((event, emit) async {
      try {
        emit(BudgetLoading());
        final analysis =
            await _repository.getBudgetAnalysis(event.month, event.period);

        emit(BudgetAnalysisLoaded(analysis));
      } catch (e) {
        emit(BudgetError(e.toString()));
      }
    });

    on<LoadTodaysBudget>((event, emit) async {
      try {
        // Only emit loading state if we're forcing a refresh
        if (event.forceRefresh) {
          emit(BudgetLoading());
        }

        // Check if we should use cached data (less than 5 minutes old)
        final shouldUseCache = !event.forceRefresh &&
            _todaysBudgetCache != null &&
            DateTime.now().difference(_lastBudgetFetch).inMinutes < 5;

        if (shouldUseCache) {
          emit(TodaysBudgetLoaded(_todaysBudgetCache!));
          return;
        }

        // Get the current user ID for debugging
        final userId = _repository.apiService.getCurrentUserId();

        // Get the budget analysis directly from the API with the specified period
        final analysis =
            await _repository.getBudgetAnalysis('monthly', event.period);

        // Calculate actual spending from transactions and update the analysis
        final updatedAnalysis =
            await _calculateBudgetWithTransactions(analysis);

        // Cache the budget and update last fetch time
        _todaysBudgetCache = updatedAnalysis;
        _lastBudgetFetch = DateTime.now();

        emit(TodaysBudgetLoaded(updatedAnalysis));
      } catch (e) {
        // If we have cached data, use it instead of showing an error
        if (_todaysBudgetCache != null) {
          emit(TodaysBudgetLoaded(_todaysBudgetCache!));
        } else {
          emit(BudgetError(e.toString()));
        }
      }
    });

    on<UpdateBudgetFromExpenseInfo>((event, emit) async {
      try {
        // Extract data from expense_info for debugging
        final total = event.expenseInfo['total'] ?? 0;
        final categories =
            event.expenseInfo['categories'] as Map<String, dynamic>? ?? {};

        // Get the latest budget analysis from the API with period=monthly
        final analysis =
            await _repository.getBudgetAnalysis('monthly', 'monthly');

        // Calculate actual spending from transactions and update the analysis
        final updatedAnalysis =
            await _calculateBudgetWithTransactions(analysis);

        // Cache the budget and update last fetch time
        _todaysBudgetCache = updatedAnalysis;
        _lastBudgetFetch = DateTime.now();

        // Emit the updated state
        emit(TodaysBudgetLoaded(updatedAnalysis));
      } catch (e) {
        // If we have cached data, use it instead of showing an error
        if (_todaysBudgetCache != null) {
          emit(TodaysBudgetLoaded(_todaysBudgetCache!));
        } else {
          emit(BudgetError(e.toString()));
        }
      }
    });
  }

  /// Shared method to calculate actual budget spending from transactions
  /// This replaces the duplicate logic in LoadTodaysBudget and UpdateBudgetFromExpenseInfo
  Future<BudgetAnalysis> _calculateBudgetWithTransactions(
      BudgetAnalysis baseAnalysis) async {
    // Since the server is returning zeros for actual spending, we'll calculate it ourselves

    // Get both monthly and daily transactions to calculate actual spending
    final monthlyTransactions =
        await _repository.getTransactionsByPeriod('monthly');
    final dailyTransactions = await _repository.getDailyTransactions();

    // Calculate totals by category
    double needs = 0.0;
    double wants = 0.0;
    double savings = 0.0;

    // Calculate today's spending
    double todaySpending = 0.0;
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Process monthly transactions first
    for (var tx in monthlyTransactions) {
      final category = tx.category;
      final amount = tx.amount;
      final txDate = tx.timestamp;
      final txDateStr =
          "${txDate.year}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}";

      // Calculate today's spending
      if (txDateStr == todayStr) {
        todaySpending += amount;
      }

      // Use the spendingType from the TransactionCategory
      switch (category.spendingType) {
        case 'needs':
          needs += amount;

          break;
        case 'wants':
          wants += amount;

          break;
        case 'savings':
          savings += amount;

          break;
      }
    }

    // Process daily transactions
    for (var tx in dailyTransactions) {
      final category = tx.category;
      final amount = tx.amount;
      final txDate = tx.timestamp;
      final txDateStr =
          "${txDate.year}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}";

      // Calculate today's spending
      if (txDateStr == todayStr) {
        todaySpending += amount;
      }

      // Use the spendingType from the TransactionCategory
      switch (category.spendingType) {
        case 'needs':
          needs += amount;

          break;
        case 'wants':
          wants += amount;

          break;
        case 'savings':
          savings += amount;

          break;
      }
    }

    // Create updated analysis with calculated values
    final updatedAnalysis = BudgetAnalysis(
      monthlySalary: baseAnalysis.monthlySalary,
      ideal: baseAnalysis.ideal,
      actual: BudgetAllocation(
        needs: needs,
        wants: wants,
        savings: savings,
      ),
      todaySpending: todaySpending,
    );

    return updatedAnalysis;
  }

  @override
  Future<void> close() {
    _chatSubscription?.cancel();
    _transactionSubscription?.cancel();
    return super.close();
  }
}
