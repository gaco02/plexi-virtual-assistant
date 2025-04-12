import 'package:equatable/equatable.dart';
import '../../data/models/budget_analysis.dart';

abstract class BudgetState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {}

class BudgetLoading extends BudgetState {}

class BudgetError extends BudgetState {
  final String message;
  BudgetError(this.message);
  @override
  List<Object?> get props => [message];
}

class BudgetAnalysisLoaded extends BudgetState {
  final BudgetAnalysis analysis;
  BudgetAnalysisLoaded(this.analysis);
  @override
  List<Object?> get props => [analysis];
}

class TodaysBudgetLoaded extends BudgetState {
  final BudgetAnalysis analysis;
  TodaysBudgetLoaded(this.analysis);
  @override
  List<Object?> get props => [analysis];
}

class BudgetRecommendationsLoaded extends BudgetState {
  final List<BudgetRecommendation> recommendations;
  BudgetRecommendationsLoaded(this.recommendations);
  @override
  List<Object?> get props => [recommendations];
}
