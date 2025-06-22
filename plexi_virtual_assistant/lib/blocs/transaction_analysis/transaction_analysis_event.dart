import 'package:equatable/equatable.dart';
import '../../data/models/transaction_analysis.dart';

abstract class TransactionAnalysisEvent extends Equatable {
  const TransactionAnalysisEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactionAnalysis extends TransactionAnalysisEvent {
  final String? month;
  final bool forceRefresh;
  final bool preferLocal; // New flag to prefer local data

  const LoadTransactionAnalysis({
    this.month,
    this.forceRefresh = false,
    this.preferLocal = true, // Default to preferring local data
  });

  @override
  List<Object?> get props => [month, forceRefresh, preferLocal];
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
  final bool forceRefresh;

  const RefreshTransactionHistory({this.forceRefresh = false});

  @override
  List<Object> get props => [forceRefresh];
}

class ManualRefreshAnalysis extends TransactionAnalysisEvent {
  final String? month;
  final bool forceRefresh;

  const ManualRefreshAnalysis({this.month, this.forceRefresh = false});

  @override
  List<Object?> get props => [month, forceRefresh];
}

// Add a new event for quick budget updates from chat
class QuickBudgetUpdate extends TransactionAnalysisEvent {
  final TransactionAllocation newActual;
  final bool fromChat;

  const QuickBudgetUpdate({
    required this.newActual,
    this.fromChat = false,
  });

  @override
  List<Object?> get props => [newActual, fromChat];
}
