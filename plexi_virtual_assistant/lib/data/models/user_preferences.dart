enum WeightGoal { lose, maintain, gain }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive
}

enum Sex { male, female, other }

class UserPreferences {
  final String? preferredName;
  final double? monthlySalary;
  final double? currentWeight;
  final double? height;
  final int? age;
  final int? dailyCalorieTarget;
  final WeightGoal? weightGoal;
  final ActivityLevel? activityLevel;
  final double? targetWeight;
  final Sex? sex;

  UserPreferences({
    this.preferredName,
    this.monthlySalary,
    this.currentWeight,
    this.height,
    this.age,
    this.dailyCalorieTarget,
    this.weightGoal,
    this.activityLevel,
    this.targetWeight,
    this.sex,
  });

  UserPreferences copyWith({
    String? preferredName,
    double? monthlySalary,
    double? currentWeight,
    double? height,
    int? age,
    int? dailyCalorieTarget,
    WeightGoal? weightGoal,
    ActivityLevel? activityLevel,
    double? targetWeight,
    Sex? sex,
  }) {
    return UserPreferences(
      preferredName: preferredName ?? this.preferredName,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      currentWeight: currentWeight ?? this.currentWeight,
      height: height ?? this.height,
      age: age ?? this.age,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      weightGoal: weightGoal ?? this.weightGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      targetWeight: targetWeight ?? this.targetWeight,
      sex: sex ?? this.sex,
    );
  }

  Map<String, dynamic> toJson() {
    final sexValue = sex?.toString().split('.').last.toLowerCase();

    return {
      'preferred_name': preferredName,
      'monthly_salary': monthlySalary,
      'current_weight': currentWeight,
      'height': height,
      'age': age,
      'daily_calorie_target': dailyCalorieTarget,
      'weight_goal': weightGoal?.toString().split('.').last,
      'activity_level': activityLevel?.toString().split('.').last,
      'target_weight': targetWeight,
      'sex': sexValue,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final sexString = json['sex'] as String?;
    Sex? sexValue;

    if (sexString != null) {
      try {
        sexValue = Sex.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toLowerCase() ==
              sexString.toLowerCase(),
        );
      } catch (e) {
        sexValue = sexString.toLowerCase() == 'other' ? Sex.other : null;
      }
    }

    return UserPreferences(
      preferredName: json['preferred_name'] as String?,
      monthlySalary: json['monthly_salary']?.toDouble(),
      currentWeight: json['current_weight']?.toDouble(),
      height: json['height']?.toDouble(),
      age: json['age'] as int?,
      dailyCalorieTarget: json['daily_calorie_target'] as int?,
      weightGoal: json['weight_goal'] != null
          ? WeightGoal.values.firstWhere(
              (e) => e.toString().split('.').last == json['weight_goal'],
              orElse: () => WeightGoal.maintain)
          : null,
      activityLevel: json['activity_level'] != null
          ? ActivityLevel.values.firstWhere(
              (e) => e.toString().split('.').last == json['activity_level'],
              orElse: () => ActivityLevel.moderatelyActive)
          : null,
      targetWeight: json['target_weight']?.toDouble(),
      sex: sexValue,
    );
  }
}
