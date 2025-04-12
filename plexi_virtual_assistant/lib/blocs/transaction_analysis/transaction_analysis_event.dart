import 'package:equatable/equatable.dart';

abstract class TransactionAnalysisEvent extends Equatable {
  const TransactionAnalysisEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactionAnalysis extends TransactionAnalysisEvent {
  final String? month;
  final bool forceRefresh;

  const LoadTransactionAnalysis({this.month, this.forceRefresh = false});

  @override
  List<Object?> get props => [month, forceRefresh];
}

class LoadTransactionHistory extends TransactionAnalysisEvent {
  final String? period;
  final String? date;
  final bool forceRefresh;

  const LoadTransactionHistory({
    this.period, 
    this.date, 
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [period, date, forceRefresh];
}

class EditTransactionEvent extends TransactionAnalysisEvent {
  final String transactionId;
  final double amount;
  final String category;
  final String description;

  const EditTransactionEvent({
    required this.transactionId,
    required this.amount,
    required this.category,
    required this.description,
  });

  @override
  List<Object> get props => [transactionId, amount, category, description];
}

class DeleteTransactionEvent extends TransactionAnalysisEvent {
  final String transactionId;

  const DeleteTransactionEvent({
    required this.transactionId,
  });

  @override
  List<Object> get props => [transactionId];
}

class RefreshTransactionHistory extends TransactionAnalysisEvent {
  const RefreshTransactionHistory();

  @override
  List<Object> get props => [];
}

class ManualRefreshAnalysis extends TransactionAnalysisEvent {
  final String? month;
  final bool forceRefresh;
  
  const ManualRefreshAnalysis({this.month, this.forceRefresh = false});
  
  @override
  List<Object?> get props => [month, forceRefresh];
}
