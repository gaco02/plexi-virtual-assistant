import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/transactions/transaction_repository_new.dart';
import '../../data/models/transaction.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';
import 'dart:async';
import 'package:plexi_virtual_assistant/utils/daily_refresh_mixin.dart';
import 'package:plexi_virtual_assistant/blocs/transaction_analysis/transaction_analysis_bloc.dart';
import 'package:plexi_virtual_assistant/blocs/transaction_analysis/transaction_analysis_event.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState>
    with DailyRefreshMixin {
  final TransactionRepository _repository;
  final TransactionAnalysisBloc? _analysisBloc;
  Timer? _refreshTimer;

  TransactionBloc({
    required TransactionRepository repository,
    TransactionAnalysisBloc? analysisBloc,
  })  : _repository = repository,
        _analysisBloc = analysisBloc,
        super(TransactionInitial()) {
    // Check for refresh every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (shouldRefresh()) {
        add(const LoadDailyTransactions());
      }
    });

    on<LoadDailyTransactions>(_onLoadDaily);
    on<LoadMonthlyTransactions>(_onLoadMonthly);
    on<AddTransaction>(_onAddTransaction);
    on<UpdateDailyTotal>(_onUpdateDailyTotal);
    on<UpdateTransactionsFromChat>(_onUpdateFromChat);
    on<LoadTransactionsByPeriod>(_onLoadByPeriod);
    on<EditTransaction>(_onEditTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadDaily(
    LoadDailyTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // If forceRefresh is true, invalidate caches first
      if (event.forceRefresh) {
        _repository.invalidateTransactionCaches();
      }

      final todayTotal = await _repository.getDailyTotal();

      // Only emit DailySummaryLoaded if this was triggered by the widget
      if (event.isForWidget == true) {
        emit(DailySummaryLoaded(todayTotal));
      } else {
        final transactions = await _repository.getDailyTransactions();
        final monthlyTransactions =
            await _repository.getTransactionsByPeriod('Month');
        final monthlyTotal =
            monthlyTransactions.fold(0.0, (sum, tx) => sum + tx.amount);

        emit(TransactionsLoaded(
          transactions,
          todayAmount: todayTotal,
          monthlyAmount: monthlyTotal,
          period: 'Today',
        ));
      }
    } catch (e) {
      emit(const TransactionsLoaded(
        [],
        todayAmount: 0.0,
        monthlyAmount: 0.0,
      ));
    }
  }

  Future<void> _onLoadMonthly(
    LoadMonthlyTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      emit(TransactionLoading());

      // If forceRefresh is true, invalidate caches first
      if (event.forceRefresh) {
        _repository.invalidateTransactionCaches();
      }

      final transactions = await _repository.getMonthlyTransactions();
      final monthlyTotal = transactions.fold<double>(
          0, (sum, transaction) => sum + transaction.amount);

      // Only emit MonthlySummaryLoaded if this was triggered by the widget
      if (event.isForWidget == true) {
        emit(MonthlySummaryLoaded(monthlyTotal));
      } else {
        final todayTotal = await _repository.getDailyTotal();

        emit(TransactionsLoaded(
          transactions,
          todayAmount: todayTotal,
          monthlyAmount: monthlyTotal,
          period: 'Month',
        ));
      }
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onAddTransaction(
    AddTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Show loading state
      emit(TransactionLoading());

      // Log the transaction
      await _repository.logTransaction(
        event.transactionData['amount'] as double,
        event.transactionData['category'] as String,
        event.transactionData['description'] as String,
      );

      // Notify the analysis bloc to refresh its data
      _analysisBloc?.add(const LoadTransactionAnalysis());

      // Always load monthly transactions after adding a new transaction
      // This ensures the spending by category widget always has monthly data
      final monthlyTransactions = await _repository.getMonthlyTransactions();
      final monthlyTotal = monthlyTransactions.fold<double>(
          0, (sum, transaction) => sum + transaction.amount);

      // Get daily total for today's summary
      final todayTotal = await _repository.getDailyTotal(forceRefresh: true);

      // Emit TransactionsLoaded with both daily and monthly data
      emit(TransactionsLoaded(
        monthlyTransactions,
        todayAmount: todayTotal,
        monthlyAmount: monthlyTotal,
        period: 'Month', // Set period to Month to ensure monthly view
      ));
    } catch (e) {
      emit(const TransactionError('Failed to add transaction'));
    }
  }

  Future<void> _onUpdateDailyTotal(
    UpdateDailyTotal event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final transactions = await _repository.getDailyTransactions();
      final todayTotal = await _repository.getDailyTotal();
      final monthlyTransactions =
          await _repository.getTransactionsByPeriod('Month');
      final monthlyTotal =
          monthlyTransactions.fold(0.0, (sum, tx) => sum + tx.amount);

      emit(TransactionsLoaded(
        transactions,
        todayAmount: todayTotal,
        monthlyAmount: monthlyTotal,
      ));
    } catch (e) {
      // Don't emit error state if we fail to update
      if (state is TransactionsLoaded) {
        // Keep existing state
        emit(state);
      } else {
        emit(const TransactionsLoaded(
          [],
          todayAmount: 0.0,
          monthlyAmount: 0.0,
        ));
      }
    }
  }

  Future<void> _onUpdateFromChat(
    UpdateTransactionsFromChat event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      print(
          'TransactionBloc: Processing update from chat with ${event.transactions.length} transactions, totalAmount: ${event.totalAmount}');

      // Always reset any caches first
      _repository.invalidateTransactionCaches();

      // Check if this is just a summary (no actual transactions to save)
      bool isSummaryOnly = event.transactions.isEmpty ||
          event.transactions.any((t) =>
              t['description'] != null &&
              t['description'].toString().contains('Transaction from summary'));

      if (isSummaryOnly) {
        print('TransactionBloc: Processing summary-only update');

        // Get the monthly total with a forced refresh to ensure latest data
        final monthlyTransactions = await _repository
            .getTransactionsByPeriod('Month', forceRefresh: true);
        final monthlyTotal =
            monthlyTransactions.fold(0.0, (sum, tx) => sum + tx.amount);

        print('TransactionBloc: Monthly total after refresh: $monthlyTotal');

        // Calculate category totals from monthly transactions
        final categoryTotals = <TransactionCategory, double>{};
        for (var tx in monthlyTransactions) {
          categoryTotals[tx.category] =
              (categoryTotals[tx.category] ?? 0) + tx.amount;
        }
        print(
            'TransactionBloc: Updated category totals: ${categoryTotals.keys.length} categories');

        // Update the UI with the summary data
        emit(TransactionsLoaded(
          monthlyTransactions,
          todayAmount: event.totalAmount.toDouble(),
          monthlyAmount: monthlyTotal,
          period: 'Month',
        ));

        // Emit the daily summary update for widgets
        emit(DailySummaryLoaded(event.totalAmount.toDouble()));

        // Also emit MonthlySummaryLoaded to update spending by category
        emit(MonthlySummaryLoaded(monthlyTotal));

        return; // Exit early - don't save any transactions
      }

      // Process actual new transactions (not summaries)
      final transactions = event.transactions
          .map((t) {
            try {
              // Safely extract amount with null checking
              final amount = t['amount'];
              if (amount == null) {
                return null;
              }

              // Skip transactions that are summaries
              if (t['description'] != null &&
                  t['description']
                      .toString()
                      .contains('Transaction from summary')) {
                return null;
              }

              return Transaction(
                id: DateTime.now().toString(),
                userId: '',
                amount: (amount as num).toDouble(),
                category: TransactionCategoryExtension.fromString(
                    (t['category'] as String?) ?? 'other'),
                description: (t['description'] as String?) ?? '',
                timestamp: DateTime.tryParse(t['timestamp'] as String) ??
                    DateTime.now(),
              );
            } catch (e) {
              return null;
            }
          })
          .where((t) => t != null)
          .cast<Transaction>()
          .toList();

      print(
          'TransactionBloc: Processing ${transactions.length} real transactions');

      // Save each transaction to the repository
      for (var transaction in transactions) {
        try {
          await _repository.addTransaction({
            'amount': transaction.amount,
            'category': transaction.category.toString().split('.').last,
            'description': transaction.description,
            'timestamp': transaction.timestamp.toIso8601String(),
          });
        } catch (e) {
          print('TransactionBloc: Error saving transaction: $e');
        }
      }

      // Get all the data with force refresh
      final todayTotal = await _repository.getDailyTotal(forceRefresh: true);

      final monthlyTransactions =
          await _repository.getMonthlyTransactions(forceRefresh: true);
      final monthlyTotal =
          monthlyTransactions.fold(0.0, (sum, tx) => sum + tx.amount);

      // Calculate category totals from monthly transactions
      final categoryTotals = <TransactionCategory, double>{};
      for (var tx in monthlyTransactions) {
        categoryTotals[tx.category] =
            (categoryTotals[tx.category] ?? 0) + tx.amount;
      }

      print(
          'TransactionBloc: Updated totals - Today: $todayTotal, Monthly: $monthlyTotal');
      print(
          'TransactionBloc: Categories: ${categoryTotals.length} with totals: ${categoryTotals.values.fold(0.0, (sum, amount) => sum + amount)}');

      // First emit the transaction loaded state with monthly transactions
      emit(TransactionsLoaded(
        monthlyTransactions,
        todayAmount: todayTotal,
        monthlyAmount: monthlyTotal,
        period: 'Month',
      ));

      // Then emit the daily summary update for widgets
      emit(DailySummaryLoaded(todayTotal));

      // Also emit MonthlySummaryLoaded to update spending by category
      emit(MonthlySummaryLoaded(monthlyTotal));

      // Also refresh the transaction analysis
      _refreshAnalysisBloc();
    } catch (e) {
      print('TransactionBloc: Error in _onUpdateFromChat: $e');
      // Keep the current state if there's an error
      if (state is TransactionsLoaded) {
        emit(state);
      } else if (state is DailySummaryLoaded) {
        emit(state);
      }
    }
  }

  Future<void> _onLoadByPeriod(
    LoadTransactionsByPeriod event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    try {
      final transactions = await _repository.getTransactionsByPeriod(
          event.period,
          forceRefresh: event.forceRefresh);

      // Get today's total
      final todayTotal = await _repository.getDailyTotal();

      // Calculate weekly total if needed
      double weeklyTotal = 0.0;
      if (event.period == 'Week') {
        weeklyTotal = transactions.fold(0.0, (sum, tx) => sum + tx.amount);
      } else {
        // Get weekly transactions separately
        final weeklyTransactions =
            await _repository.getTransactionsByPeriod('Week');
        weeklyTotal =
            weeklyTransactions.fold(0.0, (sum, tx) => sum + tx.amount);
      }

      // Calculate monthly total based on the period
      double monthlyTotal;
      if (event.period == 'Month') {
        // If we're viewing monthly data, use the transactions we just loaded
        monthlyTotal = transactions.fold(0.0, (sum, tx) => sum + tx.amount);
      } else {
        // Otherwise, get the monthly transactions separately
        final monthlyTransactions =
            await _repository.getTransactionsByPeriod('Month');
        monthlyTotal =
            monthlyTransactions.fold(0.0, (sum, tx) => sum + tx.amount);
      }

      emit(TransactionsLoaded(
        transactions,
        todayAmount: todayTotal,
        weeklyAmount: weeklyTotal,
        monthlyAmount: monthlyTotal,
        period: event.period,
      ));
    } catch (e) {
      // Emit with default values instead of an error
      emit(TransactionsLoaded(
        [],
        period: event.period,
      ));
    }
  }

  Future<void> _onEditTransaction(
    EditTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Update the transaction
      await _repository.updateTransaction(
        event.transactionId,
        event.amount,
        event.category,
        event.description,
      );

      // Force refresh of all data
      add(const LoadDailyTransactions(forceRefresh: true, isForWidget: true));
      add(const LoadMonthlyTransactions());

      // Emit success state
      emit(TransactionsLoaded(
        await _repository.getDailyTransactions(),
        todayAmount: await _repository.getDailyTotal(),
        monthlyAmount: (await _repository.getMonthlyTransactions())
            .fold(0.0, (sum, tx) => sum + tx.amount),
      ));
    } catch (e) {
      emit(const TransactionError('Failed to update transaction'));
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Delete the transaction
      await _repository.deleteTransaction(event.transactionId);

      // Force refresh of all data
      add(const LoadDailyTransactions(forceRefresh: true, isForWidget: true));
      add(const LoadMonthlyTransactions());

      // Emit success state
      emit(TransactionsLoaded(
        await _repository.getDailyTransactions(),
        todayAmount: await _repository.getDailyTotal(),
        monthlyAmount: (await _repository.getMonthlyTransactions())
            .fold(0.0, (sum, tx) => sum + tx.amount),
      ));
    } catch (e) {
      emit(const TransactionError('Failed to delete transaction'));
    }
  }

  // Helper method to refresh the analysis bloc
  void _refreshAnalysisBloc() {
    if (_analysisBloc != null) {
      _analysisBloc!.add(const RefreshTransactionHistory());
    }
  }
}
