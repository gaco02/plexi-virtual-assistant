class TransactionAnalysis {
  final double monthlySalary;
  final TransactionAllocation ideal;
  final TransactionAllocation actual;
  final List<TransactionRecommendation> recommendations;

  TransactionAnalysis({
    required this.monthlySalary,
    required this.ideal,
    required this.actual,
    this.recommendations = const [],
  });

  factory TransactionAnalysis.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both camelCase and snake_case keys for monthly salary
      final monthlySalary = _parseDouble(json['monthly_salary']) ??
          _parseDouble(json['monthlySalary']) ??
          0.0;

      // Handle different formats for ideal allocation
      TransactionAllocation ideal;
      if (json['ideal'] is Map<String, dynamic>) {
        ideal = TransactionAllocation.fromJson(
            json['ideal'] as Map<String, dynamic>);
      } else if (json['IDEAL'] is Map<String, dynamic>) {
        ideal = TransactionAllocation.fromJson(
            json['IDEAL'] as Map<String, dynamic>);
      } else if (json['ideal'] is Map) {
        // Handle non-string keys
        ideal = TransactionAllocation.fromJson(
            Map<String, dynamic>.from(json['ideal']));
      } else {
        // Check if the allocation values are directly in the root JSON
        final needsIdeal = _parseDouble(json['needs_ideal']) ??
            _parseDouble(json['needsIdeal']) ??
            0.0;
        final wantsIdeal = _parseDouble(json['wants_ideal']) ??
            _parseDouble(json['wantsIdeal']) ??
            0.0;
        final savingsIdeal = _parseDouble(json['savings_ideal']) ??
            _parseDouble(json['savingsIdeal']) ??
            0.0;

        if (needsIdeal > 0 || wantsIdeal > 0 || savingsIdeal > 0) {
          ideal = TransactionAllocation(
              needs: needsIdeal, wants: wantsIdeal, savings: savingsIdeal);
        } else {
          ideal = TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0);
        }
      }

      // Handle different formats for actual allocation
      TransactionAllocation actual;
      if (json['actual'] is Map<String, dynamic>) {
        actual = TransactionAllocation.fromJson(
            json['actual'] as Map<String, dynamic>);
      } else if (json['ACTUAL'] is Map<String, dynamic>) {
        actual = TransactionAllocation.fromJson(
            json['ACTUAL'] as Map<String, dynamic>);
      } else if (json['actual'] is Map) {
        // Handle non-string keys
        actual = TransactionAllocation.fromJson(
            Map<String, dynamic>.from(json['actual']));
      } else {
        // Check if the allocation values are directly in the root JSON
        final needsActual = _parseDouble(json['needs_actual']) ??
            _parseDouble(json['needsActual']) ??
            _parseDouble(json['needs']) ??
            0.0;
        final wantsActual = _parseDouble(json['wants_actual']) ??
            _parseDouble(json['wantsActual']) ??
            _parseDouble(json['wants']) ??
            0.0;
        final savingsActual = _parseDouble(json['savings_actual']) ??
            _parseDouble(json['savingsActual']) ??
            _parseDouble(json['savings']) ??
            0.0;

        if (needsActual > 0 || wantsActual > 0 || savingsActual > 0) {
          actual = TransactionAllocation(
              needs: needsActual, wants: wantsActual, savings: savingsActual);
        } else {
          actual = TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0);
        }
      }

      // Handle recommendations
      final recommendations = <TransactionRecommendation>[];
      if (json['recommendations'] != null && json['recommendations'] is List) {
        for (final rec in json['recommendations']) {
          if (rec is Map<String, dynamic>) {
            recommendations.add(TransactionRecommendation.fromJson(rec));
          } else if (rec is Map) {
            recommendations.add(TransactionRecommendation.fromJson(
                Map<String, dynamic>.from(rec)));
          }
        }
      }

      return TransactionAnalysis(
        monthlySalary: monthlySalary,
        ideal: ideal,
        actual: actual,
        recommendations: recommendations,
      );
    } catch (e) {
      // Return a default object on error
      return TransactionAnalysis(
        monthlySalary: 0.0,
        ideal: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
        actual: TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'monthly_salary': monthlySalary,
      'ideal': ideal.toJson(),
      'actual': actual.toJson(),
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
    };
  }
}

class TransactionAllocation {
  final double needs;
  final double wants;
  final double savings;

  TransactionAllocation({
    required this.needs,
    required this.wants,
    required this.savings,
  });

  factory TransactionAllocation.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both camelCase and snake_case keys
      final needs =
          _parseDouble(json['needs']) ?? _parseDouble(json['NEEDS']) ?? 0.0;

      final wants =
          _parseDouble(json['wants']) ?? _parseDouble(json['WANTS']) ?? 0.0;

      final savings =
          _parseDouble(json['savings']) ?? _parseDouble(json['SAVINGS']) ?? 0.0;

      return TransactionAllocation(
        needs: needs,
        wants: wants,
        savings: savings,
      );
    } catch (e) {
      // Return a default object on error
      return TransactionAllocation(needs: 0.0, wants: 0.0, savings: 0.0);
    }
  }

  double get total => needs + wants + savings;

  Map<String, double> toMap() => {
        'needs': needs,
        'wants': wants,
        'savings': savings,
      };

  Map<String, dynamic> toJson() {
    return {
      'needs': needs,
      'wants': wants,
      'savings': savings,
    };
  }
}

class TransactionRecommendation {
  final String category;
  final String type;
  final String message;
  final String suggestedAction;
  final double potentialSavings;

  TransactionRecommendation({
    required this.category,
    required this.type,
    required this.message,
    required this.suggestedAction,
    required this.potentialSavings,
  });

  factory TransactionRecommendation.fromJson(Map<String, dynamic> json) {
    try {
      // Handle potential_savings which might be a string like "$325.00"
      double savings = 0.0;
      var potentialSavingsValue = json['potential_savings'];
      if (potentialSavingsValue is num) {
        savings = potentialSavingsValue.toDouble();
      } else if (potentialSavingsValue is String) {
        // Remove dollar sign and any commas, then parse
        String cleanValue =
            potentialSavingsValue.replaceAll('\$', '').replaceAll(',', '');
        savings = double.tryParse(cleanValue) ?? 0.0;
      }

      return TransactionRecommendation(
        category: json['category'] as String? ?? 'Unknown',
        type: json['type'] as String? ?? 'Unknown',
        message: json['message'] as String? ?? '',
        suggestedAction: json['suggested_action'] as String? ?? '',
        potentialSavings: savings,
      );
    } catch (e) {
      return TransactionRecommendation(
        category: 'Unknown',
        type: 'Unknown',
        message: 'Error parsing recommendation',
        suggestedAction: '',
        potentialSavings: 0.0,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'type': type,
      'message': message,
      'suggested_action': suggestedAction,
      'potential_savings': potentialSavings,
    };
  }
}

class TransactionHistoryEntry {
  final String date;
  final double amount;
  final String category;
  final String description;
  final DateTime timestamp;

  TransactionHistoryEntry({
    required this.date,
    required this.amount,
    required this.category,
    required this.description,
    required this.timestamp,
  });

  factory TransactionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryEntry(
      date: json['date'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
      'category': category,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TransactionSummary {
  final double totalSpent;
  final double remainingBudget;
  final double savingsRate;
  final Map<String, double> categoryBreakdown;

  TransactionSummary({
    required this.totalSpent,
    required this.remainingBudget,
    required this.savingsRate,
    required this.categoryBreakdown,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    final categoryBreakdown = <String, double>{};
    if (json['category_breakdown'] != null) {
      (json['category_breakdown'] as Map<String, dynamic>)
          .forEach((key, value) {
        categoryBreakdown[key] = (value as num).toDouble();
      });
    }

    return TransactionSummary(
      totalSpent: (json['total_spent'] as num).toDouble(),
      remainingBudget: (json['remaining_budget'] as num).toDouble(),
      savingsRate: (json['savings_rate'] as num).toDouble(),
      categoryBreakdown: categoryBreakdown,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_spent': totalSpent,
      'remaining_budget': remainingBudget,
      'savings_rate': savingsRate,
      'category_breakdown': categoryBreakdown,
    };
  }
}

// Helper function to safely parse double values from various types
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      return 0.0;
    }
  }

  return 0.0;
}
