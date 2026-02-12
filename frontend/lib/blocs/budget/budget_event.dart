import 'package:equatable/equatable.dart';

abstract class BudgetEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadBudgetAnalysis extends BudgetEvent {
  final String? month;
  final String period;

  LoadBudgetAnalysis([this.month, this.period = 'monthly']);

  @override
  List<Object?> get props => [month, period];
}

class LoadTodaysBudget extends BudgetEvent {
  final bool forceRefresh;
  final String period;

  LoadTodaysBudget({this.forceRefresh = false, this.period = 'monthly'});

  @override
  List<Object?> get props => [forceRefresh, period];
}

class LoadBudgetRecommendations extends BudgetEvent {
  final String? month;
  LoadBudgetRecommendations([this.month]);
  @override
  List<Object?> get props => [month];
}

class UpdateBudgetFromExpenseInfo extends BudgetEvent {
  final Map<String, dynamic> expenseInfo;

  UpdateBudgetFromExpenseInfo(this.expenseInfo);

  @override
  List<Object?> get props => [expenseInfo];
}
