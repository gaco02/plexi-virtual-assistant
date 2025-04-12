import 'package:equatable/equatable.dart';
import '../../data/models/transaction_analysis.dart';
import '../../data/models/transaction.dart';

abstract class TransactionAnalysisState extends Equatable {
  const TransactionAnalysisState();

  @override
  List<Object?> get props => [];
}

class TransactionAnalysisInitial extends TransactionAnalysisState {}

class TransactionAnalysisLoading extends TransactionAnalysisState {}

class TransactionAnalysisLoaded extends TransactionAnalysisState {
  final TransactionAnalysis analysis;

  const TransactionAnalysisLoaded(this.analysis);

  @override
  List<Object?> get props => [analysis];
}

class TransactionAnalysisError extends TransactionAnalysisState {
  final String message;

  const TransactionAnalysisError(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionHistoryLoading extends TransactionAnalysisState {}

class TransactionHistoryLoaded extends TransactionAnalysisState {
  final Map<String, List<Transaction>> transactionsByDate;

  const TransactionHistoryLoaded(this.transactionsByDate);

  @override
  List<Object?> get props => [transactionsByDate];
}

class TransactionHistoryError extends TransactionAnalysisState {
  final String message;

  const TransactionHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Combined state that holds both analysis and history data
class TransactionCombinedState extends TransactionAnalysisState {
  final TransactionAnalysis? analysis;
  final Map<String, List<Transaction>>? transactionsByDate;
  final bool isRefreshing;
  final String? errorMessage;
  
  const TransactionCombinedState({
    this.analysis,
    this.transactionsByDate,
    this.isRefreshing = false,
    this.errorMessage,
  });
  
  @override
  List<Object?> get props => [analysis, transactionsByDate, isRefreshing, errorMessage];
  
  /// Create a copy of this state with optional new values
  TransactionCombinedState copyWith({
    TransactionAnalysis? analysis,
    Map<String, List<Transaction>>? transactionsByDate,
    bool? isRefreshing,
    String? errorMessage,
  }) {
    return TransactionCombinedState(
      analysis: analysis ?? this.analysis,
      transactionsByDate: transactionsByDate ?? this.transactionsByDate,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
