import '../../data/models/transaction.dart';

abstract class TransactionState {
  const TransactionState();
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);
}

// For the summary widget (always daily)
class DailySummaryLoaded extends TransactionState {
  final double totalAmount;
  const DailySummaryLoaded(this.totalAmount);
}

// For the monthly spending widget
class MonthlySummaryLoaded extends TransactionState {
  final double totalAmount;
  const MonthlySummaryLoaded(this.totalAmount);
}

// For the transaction detail screen (can be daily/weekly/monthly/yearly)
class TransactionsLoaded extends TransactionState {
  final List<Transaction> transactions;
  final double todayAmount;
  final double weeklyAmount;
  final double monthlyAmount;
  final String period;

  const TransactionsLoaded(
    this.transactions, {
    this.todayAmount = 0.0,
    this.weeklyAmount = 0.0,
    this.monthlyAmount = 0.0,
    this.period = 'Today',
  });
}
