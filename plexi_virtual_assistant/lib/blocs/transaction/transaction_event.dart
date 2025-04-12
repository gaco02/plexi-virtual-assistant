import 'package:equatable/equatable.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadDailyTransactions extends TransactionEvent {
  final bool isForWidget;
  final bool forceRefresh;
  
  const LoadDailyTransactions({this.isForWidget = false, this.forceRefresh = false});

  @override
  List<Object?> get props => [isForWidget, forceRefresh];
}

class LoadMonthlyTransactions extends TransactionEvent {
  final bool isForWidget;
  final bool forceRefresh;
  
  const LoadMonthlyTransactions({this.isForWidget = false, this.forceRefresh = false});

  @override
  List<Object?> get props => [isForWidget, forceRefresh];
}

class AddTransaction extends TransactionEvent {
  final Map<String, dynamic> transactionData;

  const AddTransaction(this.transactionData);

  @override
  List<Object?> get props => [transactionData];
}

class UpdateDailyTotal extends TransactionEvent {}

class UpdateTransactionsFromChat extends TransactionEvent {
  final List<Map<String, dynamic>> transactions;
  final num totalAmount;
  final bool isQuery;

  const UpdateTransactionsFromChat({
    required this.transactions,
    required this.totalAmount,
    this.isQuery = false,
  });

  @override
  List<Object?> get props => [transactions, totalAmount];
}

class LoadTransactionsByPeriod extends TransactionEvent {
  final String period; // 'Today', 'This Month', 'This Year'
  final bool forceRefresh;

  const LoadTransactionsByPeriod(this.period, {this.forceRefresh = false});

  @override
  List<Object> get props => [period, forceRefresh];
}

class EditTransaction extends TransactionEvent {
  final String transactionId;
  final double amount;
  final String category;
  final String description;

  const EditTransaction({
    required this.transactionId,
    required this.amount,
    required this.category,
    required this.description,
  });

  @override
  List<Object> get props => [transactionId, amount, category, description];
}

class DeleteTransaction extends TransactionEvent {
  final String transactionId;

  const DeleteTransaction({required this.transactionId});

  @override
  List<Object> get props => [transactionId];
}
