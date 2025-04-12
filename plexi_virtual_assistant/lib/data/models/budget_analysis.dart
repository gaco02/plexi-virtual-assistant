class BudgetAnalysis {
  final double monthlySalary;
  final BudgetAllocation ideal; // Changed from "budget" to "ideal"
  final BudgetAllocation actual;
  final double todaySpending; // Added today's spending field

  BudgetAnalysis({
    required this.monthlySalary,
    required this.ideal,
    required this.actual,
    this.todaySpending = 0.0, // Default to 0.0
  });

  factory BudgetAnalysis.fromJson(Map<String, dynamic> json) {
    return BudgetAnalysis(
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0.0,
      ideal: BudgetAllocation.fromJson(json['ideal'] as Map<String, dynamic>),
      actual: BudgetAllocation.fromJson(json['actual'] as Map<String, dynamic>),
      todaySpending: (json['today_spending'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BudgetAllocation {
  final double needs;
  final double wants;
  final double savings;

  BudgetAllocation({
    required this.needs,
    required this.wants,
    required this.savings,
  });

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    return BudgetAllocation(
      needs: (json['needs'] as num?)?.toDouble() ?? 0.0,
      wants: (json['wants'] as num?)?.toDouble() ?? 0.0,
      savings: (json['savings'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BudgetRecommendation {
  final String category;
  final String type;
  final String message;
  final String suggestedAction;
  final double potentialSavings;

  BudgetRecommendation({
    required this.category,
    required this.type,
    required this.message,
    required this.suggestedAction,
    required this.potentialSavings,
  });

  factory BudgetRecommendation.fromJson(Map<String, dynamic> json) {
    return BudgetRecommendation(
      category: json['category'],
      type: json['type'],
      message: json['message'],
      suggestedAction: json['suggested_action'],
      potentialSavings: (json['potential_savings'] as num).toDouble(),
    );
  }
}

class BudgetSummary {
  final double totalSpent;
  final double remainingBudget;
  final double savingsRate;

  BudgetSummary({
    required this.totalSpent,
    required this.remainingBudget,
    required this.savingsRate,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      totalSpent: (json['total_spent'] as num).toDouble(),
      remainingBudget: (json['remaining_budget'] as num).toDouble(),
      savingsRate: (json['savings_rate'] as num).toDouble(),
    );
  }
}
