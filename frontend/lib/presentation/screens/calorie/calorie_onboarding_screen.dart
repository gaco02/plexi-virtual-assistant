import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plexi_virtual_assistant/presentation/screens/calorie/onboarding/activity_level_page.dart';
import 'package:plexi_virtual_assistant/presentation/screens/calorie/onboarding/sex_selection_page.dart';
import 'package:plexi_virtual_assistant/presentation/screens/calorie/onboarding/weight_goal_page.dart';
import '../../widgets/common/app_background.dart';
import '../../widgets/common/custom_button.dart';

import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../data/models/user_preferences.dart';
import '../../../utils/nutrition_calculator.dart';
import 'calorie_details_screen.dart';
import 'onboarding/weight_input.dart';
import 'onboarding/height_input.dart';
import 'onboarding/age_input.dart';
import 'onboarding/sex_selection_page.dart';

class CalorieOnboardingScreen extends StatefulWidget {
  const CalorieOnboardingScreen({super.key});

  @override
  State<CalorieOnboardingScreen> createState() =>
      _CalorieOnboardingScreenState();
}

class _CalorieOnboardingScreenState extends State<CalorieOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double? _weight;
  double? _height;
  int? _age;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  WeightGoal _weightGoal = WeightGoal.maintain;
  Sex? _sex;
  late List<Widget> _pages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load preferences when dependencies are ready
    context.read<PreferencesBloc>().add(LoadPreferences());
  }

  @override
  void initState() {
    super.initState();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      _WelcomePage(onNext: _nextPage),
      WeightInputPage(
        key: GlobalKey<WeightInputPageState>(),
        onWeightSubmitted: (weight) {
          setState(() {
            _weight = weight;
          });
        },
      ),
      HeightInputPage(
        key: GlobalKey<HeightInputPageState>(),
        onHeightSubmitted: (height) {
          setState(() {
            _height = height;
          });
        },
      ),
      AgeInputPage(
        key: GlobalKey<AgeInputPageState>(),
        onAgeSubmitted: (age) {
          setState(() {
            _age = age;
          });
        },
      ),
      SexSelectionPage(
        key: GlobalKey<SexSelectionPageState>(),
        onSexSelected: (sex) {
          setState(() {
            _sex = sex;
          });
        },
      ),
      ActivityLevelPage(
        key: GlobalKey<ActivityLevelPageState>(),
        onActivityLevelSelected: (activityLevel) {
          setState(() {
            _activityLevel = activityLevel;
          });
        },
      ),
      WeightGoalPage(
        key: GlobalKey<WeightGoalPageState>(),
        onWeightGoalSelected: (weightGoal) {
          setState(() {
            _weightGoal = weightGoal;
          });
          // Calculate and save calorie target when all data is available
          if (_weight != null &&
              _height != null &&
              _age != null &&
              _sex != null) {
            final calorieTarget = _calculateDailyCalorieTarget();
            if (calorieTarget != null) {
              final currentState = context.read<PreferencesBloc>().state;
              if (currentState is PreferencesLoaded) {
                final updatedPrefs = currentState.preferences.copyWith(
                  currentWeight: _weight,
                  height: _height,
                  age: _age,
                  sex: _sex,
                  activityLevel: _activityLevel,
                  weightGoal: weightGoal,
                  dailyCalorieTarget: calorieTarget.round(),
                );
                context
                    .read<PreferencesBloc>()
                    .add(SavePreferences(updatedPrefs));
              }
            }
          }
        },
      ),
      _CalorieTargetPage(
        weight: _weight,
        height: _height,
        age: _age,
        sex: _sex,
        activityLevel: _activityLevel,
        weightGoal: _weightGoal,
        dailyTarget: _calculateDailyCalorieTarget(),
      ),
    ];

    // Listen for page changes
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double? _calculateDailyCalorieTarget() {
    if (_weight == null || _height == null || _age == null || _sex == null) {
      return null;
    }

    // Use the NutritionCalculator to calculate BMR
    final bmr = NutritionCalculator.calculateBMR(
      weight: _weight!,
      height: _height!,
      age: _age!,
      sex: _sex!,
    );

    // Calculate TDEE based on activity level
    final tdee = NutritionCalculator.calculateTDEE(bmr, _activityLevel);

    // Calculate calorie target based on weight goal
    final calorieTarget =
        NutritionCalculator.calculateCalorieTarget(tdee, _weightGoal);

    return calorieTarget;
  }

  void _nextPage() {
    // Dismiss keyboard when moving to next page
    FocusScope.of(context).unfocus();

    // Get current state of the form if it's a form page
    if (_pages[_currentPage] is WeightInputPage) {
      final weightInputPage = _pages[_currentPage] as WeightInputPage;
      final state =
          (weightInputPage.key as GlobalKey<WeightInputPageState>).currentState;
      if (state != null) {
        state.submitForm();
        if (state.isNextButtonEnabled) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
      return;
    } else if (_pages[_currentPage] is HeightInputPage) {
      final heightInputPage = _pages[_currentPage] as HeightInputPage;
      final state =
          (heightInputPage.key as GlobalKey<HeightInputPageState>).currentState;
      if (state != null) {
        state.submitForm();
        // Only navigate if the height input is valid
        if (state.isNextButtonEnabled) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
      return;
    } else if (_pages[_currentPage] is AgeInputPage) {
      final ageInputPage = _pages[_currentPage] as AgeInputPage;
      final state =
          (ageInputPage.key as GlobalKey<AgeInputPageState>).currentState;
      if (state != null) {
        state.submitForm();
        // Only navigate if the age input is valid
        if (state.isNextButtonEnabled) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
      return;
    } else if (_pages[_currentPage] is SexSelectionPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<SexSelectionPageState>)
              .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is ActivityLevelPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<ActivityLevelPageState>)
              .currentState;
      if (state != null) {
        state.submitActivityLevel();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is WeightGoalPage) {
      final state = (_pages[_currentPage].key as GlobalKey<WeightGoalPageState>)
          .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    // For pages without form, just move to next page
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update the final page with the latest values before building
    _pages[7] = _CalorieTargetPage(
      weight: _weight,
      height: _height,
      age: _age,
      sex: _sex,
      activityLevel: _activityLevel,
      weightGoal: _weightGoal,
      dailyTarget: _calculateDailyCalorieTarget(),
    );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _pages.length,
                  backgroundColor: Colors.white.withAlpha(77),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFfd7835)),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: _pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    else
                      const SizedBox(width: 80), // Placeholder for alignment
                    const Spacer(),
                    if (_currentPage < _pages.length - 1 && _currentPage != 0)
                      CustomButton(
                        text: 'Next',
                        onPressed: _nextPage,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/calories/plexi_calories_texting.png',
            height: 220,
          ),
          const SizedBox(height: 32),
          Text(
            'Smart meal tracking for real results — one bite at a time 🍽️',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 48),
          CustomButton(
            text: 'Next',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _CalorieTargetPage extends StatelessWidget {
  final double? weight;
  final double? height;
  final int? age;
  final Sex? sex;
  final ActivityLevel? activityLevel;
  final WeightGoal? weightGoal;
  final double? dailyTarget;

  const _CalorieTargetPage({
    Key? key,
    required this.weight,
    required this.height,
    required this.age,
    required this.sex,
    required this.activityLevel,
    required this.weightGoal,
    required this.dailyTarget,
  }) : super(key: key);

  String _formatCalories() {
    if (dailyTarget == null) return '0';
    return dailyTarget!.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate macronutrients in grams
    final double proteinGrams = dailyTarget != null
        ? (dailyTarget! * 0.25) / 4
        : 0; // 25% of calories, 4 calories per gram
    final double carbsGrams = dailyTarget != null
        ? (dailyTarget! * 0.50) / 4
        : 0; // 50% of calories, 4 calories per gram
    final double fatGrams = dailyTarget != null
        ? (dailyTarget! * 0.25) / 9
        : 0; // 25% of calories, 9 calories per gram

    return BlocConsumer<PreferencesBloc, PreferencesState>(
      listener: (context, state) {
        if (state is PreferencesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save preferences')),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Here\'s your daily nutritional goal',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Based on your profile here's what I recommend:",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Calorie target display
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 12,
                            backgroundColor: Colors.white.withAlpha(77),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.green),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              _formatCalories(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'calories/day',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Example macronutrient breakdown with emoticons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMacronutrientCircle(
                            'Protein',
                            '🥩',
                            proteinGrams.round().toString() + 'g',
                            Colors.red.withAlpha(150)),
                        _buildMacronutrientCircle(
                            'Carbs',
                            '🍞',
                            carbsGrams.round().toString() + 'g',
                            Colors.amber.withAlpha(150)),
                        _buildMacronutrientCircle(
                            'Fat',
                            '🥑',
                            fatGrams.round().toString() + 'g',
                            Colors.green.withAlpha(150)),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 1,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (weight != null &&
                      height != null &&
                      age != null &&
                      sex != null &&
                      activityLevel != null &&
                      weightGoal != null) {
                    final currentState = context.read<PreferencesBloc>().state;
                    if (currentState is PreferencesLoaded) {
                      final updatedPrefs = currentState.preferences.copyWith(
                        currentWeight: weight,
                        height: height,
                        age: age,
                        sex: sex,
                        activityLevel: activityLevel,
                        weightGoal: weightGoal,
                        dailyCalorieTarget: dailyTarget?.round(),
                      );
                      context
                          .read<PreferencesBloc>()
                          .add(SavePreferences(updatedPrefs));

                      // Navigate only when user clicks Start
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CalorieDetailsScreen(),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please complete all steps before continuing'),
                      ),
                    );
                  }
                },
                label: const Text('Start'),
                backgroundColor: Color(0xFFfd7835),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMacronutrientCircle(
      String label, String emoji, String grams, Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          grams,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
