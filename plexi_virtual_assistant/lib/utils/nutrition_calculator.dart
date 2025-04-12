import '../data/models/user_preferences.dart';

class NutritionCalculator {
  /// Calculate Basal Metabolic Rate (BMR) using the Mifflin-St Jeor Equation
  /// BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) + 5 (for men)
  /// BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) - 161 (for women)
  /// We're using the male formula as default since we don't collect gender info
  static double calculateBMR({
    required double weight,
    required double height,
    required int age,
    Sex sex = Sex.other,
  }) {
    double bmr;
    if (sex == Sex.male) {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else if (sex == Sex.female) {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    } else {
      double maleBmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      double femaleBmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      bmr = (maleBmr + femaleBmr) / 2;
    }
    return bmr;
  }

  /// Calculate Total Daily Energy Expenditure (TDEE) based on activity level
  /// Activity levels:
  /// - Sedentary (little or no exercise): BMR × 1.2
  /// - Lightly active (light exercise/sports 1-3 days/week): BMR × 1.375
  /// - Moderately active (moderate exercise/sports 3-5 days/week): BMR × 1.55
  /// - Very active (hard exercise/sports 6-7 days/week): BMR × 1.725
  /// - Extra active (very hard exercise & physical job): BMR × 1.9
  static double calculateTDEE(double bmr, ActivityLevel activityLevel) {
    double activityMultiplier;

    switch (activityLevel) {
      case ActivityLevel.sedentary:
        activityMultiplier = 1.2;
        break;
      case ActivityLevel.lightlyActive:
        activityMultiplier = 1.375;
        break;
      case ActivityLevel.moderatelyActive:
        activityMultiplier = 1.55;
        break;
      case ActivityLevel.veryActive:
        activityMultiplier = 1.725;
        break;
      case ActivityLevel.extraActive:
        activityMultiplier = 1.9;
        break;
    }

    return bmr * activityMultiplier;
  }

  /// Calculate daily calorie target based on weight goal
  /// - Lose weight: TDEE - 500 (creates a deficit for ~1lb/week loss)
  /// - Maintain weight: TDEE
  /// - Gain weight: TDEE + 500 (creates a surplus for ~1lb/week gain)
  static double calculateCalorieTarget(double tdee, WeightGoal weightGoal) {
    return switch (weightGoal) {
      WeightGoal.lose => tdee * 0.8,
      WeightGoal.maintain => tdee,
      WeightGoal.gain => tdee * 1.15,
    };
  }

  /// Calculate daily protein requirement in grams
  /// - For weight loss: 1.6-2.2g per kg of body weight
  /// - For maintenance: 1.2-1.6g per kg of body weight
  /// - For muscle gain: 1.6-2.2g per kg of body weight
  static double calculateProteinRequirement(
      double weight, WeightGoal weightGoal) {
    final multiplier = switch (weightGoal) {
      WeightGoal.lose => 2.0,
      WeightGoal.maintain => 1.6,
      WeightGoal.gain => 1.8,
    };

    return weight * multiplier;
  }

  /// Calculate daily carbohydrate requirement in grams
  /// Typically 45-65% of total calories
  /// We'll use 50% as default
  /// 1g of carbs = 4 calories
  static double calculateCarbRequirement(double calorieTarget,
      {double percentage = 0.5}) {
    return (calorieTarget * percentage) / 4;
  }

  /// Calculate daily fat requirement in grams
  /// Typically 20-35% of total calories
  /// We'll use 30% as default
  /// 1g of fat = 9 calories
  static double calculateFatRequirement(double calorieTarget,
      {double percentage = 0.3}) {
    return (calorieTarget * percentage) / 9;
  }

  /// Generate a complete nutrition plan based on user preferences
  static NutritionPlan generateNutritionPlan(UserPreferences preferences,
      {ActivityLevel? activityLevel, WeightGoal? weightGoal}) {
    if (preferences.currentWeight == null ||
        preferences.height == null ||
        preferences.age == null) {
      throw Exception('Missing required user metrics');
    }

    final userActivityLevel = activityLevel ??
        preferences.activityLevel ??
        ActivityLevel.moderatelyActive;

    final userWeightGoal =
        weightGoal ?? preferences.weightGoal ?? WeightGoal.maintain;

    final bmr = calculateBMR(
      weight: preferences.currentWeight!,
      height: preferences.height!,
      age: preferences.age!,
      sex: preferences.sex ?? Sex.other,
    );

    final tdee = calculateTDEE(bmr, userActivityLevel);

    final calorieTarget = calculateCalorieTarget(tdee, userWeightGoal);

    final proteinTarget =
        calculateProteinRequirement(preferences.currentWeight!, userWeightGoal);
    final carbTarget = calculateCarbRequirement(calorieTarget);
    final fatTarget = calculateFatRequirement(calorieTarget);

    return NutritionPlan(
      bmr: bmr,
      tdee: tdee,
      calorieTarget: calorieTarget,
      proteinTarget: proteinTarget,
      carbTarget: carbTarget,
      fatTarget: fatTarget,
      activityLevel: userActivityLevel,
      weightGoal: userWeightGoal,
    );
  }

  /// Analyze user's actual intake compared to their targets
  static NutritionAnalysis analyzeNutrition(
    NutritionPlan plan, {
    required int actualCalories,
    required double actualProtein,
    required double actualCarbs,
    required double actualFat,
  }) {
    final caloriePercentage = (actualCalories / plan.calorieTarget) * 100;
    final proteinPercentage = (actualProtein / plan.proteinTarget) * 100;
    final carbPercentage = (actualCarbs / plan.carbTarget) * 100;
    final fatPercentage = (actualFat / plan.fatTarget) * 100;

    // Determine if macros are within acceptable ranges (±10%)
    final isCalorieOnTarget =
        caloriePercentage >= 90 && caloriePercentage <= 110;
    final isProteinOnTarget = proteinPercentage >= 90;
    final isCarbOnTarget = carbPercentage >= 90 && carbPercentage <= 110;
    final isFatOnTarget = fatPercentage >= 90 && fatPercentage <= 110;

    // Generate recommendations based on analysis
    final recommendations = <String>[];

    if (!isCalorieOnTarget) {
      if (caloriePercentage < 90) {
        recommendations.add(
            'Consider increasing your calorie intake by ${(plan.calorieTarget - actualCalories).round()} calories to meet your ${plan.weightGoal.name} goal.');
      } else {
        recommendations.add(
            'Consider reducing your calorie intake by ${(actualCalories - plan.calorieTarget).round()} calories to meet your ${plan.weightGoal.name} goal.');
      }
    }

    if (!isProteinOnTarget) {
      recommendations.add(
          'Try to increase your protein intake by ${(plan.proteinTarget - actualProtein).round()}g to support your ${plan.weightGoal.name} goal.');
    }

    if (!isCarbOnTarget) {
      if (carbPercentage < 90) {
        recommendations.add(
            'Consider increasing your carbohydrate intake by ${(plan.carbTarget - actualCarbs).round()}g for optimal energy levels.');
      } else {
        recommendations.add(
            'Consider reducing your carbohydrate intake by ${(actualCarbs - plan.carbTarget).round()}g for better balance.');
      }
    }

    if (!isFatOnTarget) {
      if (fatPercentage < 90) {
        recommendations.add(
            'Consider increasing your fat intake by ${(plan.fatTarget - actualFat).round()}g for hormone health.');
      } else {
        recommendations.add(
            'Consider reducing your fat intake by ${(actualFat - plan.fatTarget).round()}g for better balance.');
      }
    }

    // If all targets are met, add a positive recommendation
    if (isCalorieOnTarget &&
        isProteinOnTarget &&
        isCarbOnTarget &&
        isFatOnTarget) {
      recommendations.add(
          'Great job! Your nutrition intake is well-balanced and aligned with your goals.');
    }

    return NutritionAnalysis(
      caloriePercentage: caloriePercentage,
      proteinPercentage: proteinPercentage,
      carbPercentage: carbPercentage,
      fatPercentage: fatPercentage,
      isCalorieOnTarget: isCalorieOnTarget,
      isProteinOnTarget: isProteinOnTarget,
      isCarbOnTarget: isCarbOnTarget,
      isFatOnTarget: isFatOnTarget,
      recommendations: recommendations,
    );
  }
}

/// Class to hold a complete nutrition plan
class NutritionPlan {
  final double bmr;
  final double tdee;
  final double calorieTarget;
  final double proteinTarget;
  final double carbTarget;
  final double fatTarget;
  final ActivityLevel activityLevel;
  final WeightGoal weightGoal;

  NutritionPlan({
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbTarget,
    required this.fatTarget,
    required this.activityLevel,
    required this.weightGoal,
  });

  Map<String, dynamic> toJson() => {
        'bmr': bmr,
        'tdee': tdee,
        'calorie_target': calorieTarget,
        'protein_target': proteinTarget,
        'carb_target': carbTarget,
        'fat_target': fatTarget,
        'activity_level': activityLevel.toString().split('.').last,
        'weight_goal': weightGoal.toString().split('.').last,
      };
}

/// Class to hold nutrition analysis results
class NutritionAnalysis {
  final double caloriePercentage;
  final double proteinPercentage;
  final double carbPercentage;
  final double fatPercentage;
  final bool isCalorieOnTarget;
  final bool isProteinOnTarget;
  final bool isCarbOnTarget;
  final bool isFatOnTarget;
  final List<String> recommendations;

  NutritionAnalysis({
    required this.caloriePercentage,
    required this.proteinPercentage,
    required this.carbPercentage,
    required this.fatPercentage,
    required this.isCalorieOnTarget,
    required this.isProteinOnTarget,
    required this.isCarbOnTarget,
    required this.isFatOnTarget,
    required this.recommendations,
  });

  bool get isOnTarget =>
      isCalorieOnTarget && isProteinOnTarget && isCarbOnTarget && isFatOnTarget;
}
