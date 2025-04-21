import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/calorie/calorie_bloc.dart';
import '../../../blocs/calorie/calorie_state.dart';
import '../../../blocs/calorie/calorie_event.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../screens/calorie/calorie_details_screen.dart';
import '../../screens/calorie/calorie_onboarding_screen.dart';
import '../common/transparent_card.dart';
import '../skeleton/skeleton_calorie_summary.dart';
import './calorie_pie_chart.dart';
import './macronutrient_bar_chart.dart';

class CalorieSummary extends StatefulWidget {
  final bool enableNavigation;

  const CalorieSummary({
    super.key,
    this.enableNavigation = true,
  });

  @override
  State<CalorieSummary> createState() => _CalorieSummaryState();
}

class _CalorieSummaryState extends State<CalorieSummary> {
  // Store references to bloc and repository to avoid context issues
  late CalorieBloc _calorieBloc;
  bool _isRefreshing = false;
  bool _showSkeleton = true;
  int _cachedTotalCalories = 0;
  int _cachedCalorieTarget = 0;
  bool _hasRequestedCalorieLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get references to bloc and repository
    _calorieBloc = context.read<CalorieBloc>();

    // Check if data is already loaded to avoid showing skeleton unnecessarily
    if (_calorieBloc.state.status == CalorieStatus.loaded) {
      _cachedTotalCalories = _calorieBloc.state.totalCalories;
      _showSkeleton = false;

      // Still refresh data in the background to ensure accuracy
      _calorieBloc.add(const LoadDailyCalories(forceRefresh: true));
    } else if (!_hasRequestedCalorieLoad) {
      _hasRequestedCalorieLoad = true;
      // Always force refresh when loading initially to ensure fresh data
      _calorieBloc.add(const LoadDailyCalories(forceRefresh: true));
    }

    // Ensure we transition from skeleton after a reasonable timeout
    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _showSkeleton) {
        setState(() {
          _showSkeleton = false;
        });
      }
    });
  }

  void _checkAndTransitionFromSkeleton() {
    // Only transition if we're still showing skeleton and have valid data
    if (_showSkeleton && mounted) {
      // Check if we have all the data we need to show the real UI
      final calorieState = _calorieBloc.state;

      bool hasCalorieData = calorieState.status == CalorieStatus.loaded;

      if (hasCalorieData) {
        setState(() {
          _showSkeleton = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show skeleton immediately on first build
    if (_showSkeleton) {
      // Return skeleton UI immediately for better perceived performance
      return MultiBlocListener(
        listeners: [
          BlocListener<CalorieBloc, CalorieState>(
            listener: (context, state) {
              // When calorie data is loaded, check if we can transition
              if (state.status == CalorieStatus.loaded) {
                // Cache the calorie data for future use
                _cachedTotalCalories = state.totalCalories;
                _checkAndTransitionFromSkeleton();
              }
            },
          ),
          BlocListener<PreferencesBloc, PreferencesState>(
            listener: (context, state) {
              if (state is PreferencesLoaded) {
                _cachedCalorieTarget =
                    state.preferences.dailyCalorieTarget ?? 0;
                _checkAndTransitionFromSkeleton();
              }
            },
          ),
        ],
        child: const SkeletonCalorieSummary(),
      );
    }

    return BlocBuilder<CalorieBloc, CalorieState>(
      buildWhen: (previous, current) {
        // Only rebuild if there's a meaningful change in the daily calorie data
        if (previous.status == current.status) {
          if (current.status == CalorieStatus.loaded) {
            // Only rebuild if daily calories changed
            return previous.totalCalories != current.totalCalories ||
                previous.totalProtein != current.totalProtein ||
                previous.totalCarbs != current.totalCarbs ||
                previous.totalFat != current.totalFat;
          }
          return false;
        }
        // Only rebuild on status changes if we're going to/from loaded state
        return previous.status == CalorieStatus.loaded ||
            current.status == CalorieStatus.loaded;
      },
      builder: (context, state) {
        // Get current cached values
        final currentCachedCalories = _cachedTotalCalories;

        // Update cache if we have new loaded data
        if (state.status == CalorieStatus.loaded) {
          _cachedTotalCalories = state.totalCalories;
        }

        // Handle initial state
        if (state.status == CalorieStatus.initial) {
          return _buildCalorieCard(
              context, currentCachedCalories, _cachedCalorieTarget);
        }

        // Handle loading state - use cached values to prevent flickering
        if (state.status == CalorieStatus.loading) {
          return _buildCalorieCard(
              context, currentCachedCalories, _cachedCalorieTarget);
        }

        // Handle error state
        if (state.status == CalorieStatus.error) {
          return Card(
            color: Colors.red.withAlpha(77),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Error: ${state.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        // Handle loaded state
        if (state.status == CalorieStatus.loaded) {
          return BlocBuilder<PreferencesBloc, PreferencesState>(
            buildWhen: (previous, current) {
              if (previous is PreferencesLoaded &&
                  current is PreferencesLoaded) {
                return previous.preferences.dailyCalorieTarget !=
                    current.preferences.dailyCalorieTarget;
              }
              return true;
            },
            builder: (context, prefsState) {
              int target = 0;
              if (prefsState is PreferencesLoaded) {
                target = prefsState.preferences.dailyCalorieTarget ?? 0;
              }
              return _buildCalorieCard(context, state.totalCalories, target);
            },
          );
        }

        // Fallback - use cached values
        return _buildCalorieCard(
            context, currentCachedCalories, _cachedCalorieTarget);
      },
    );
  }

  @override
  Widget _buildCalorieCard(BuildContext context, int calories, int target) {
    final calorieState = context.read<CalorieBloc>().state;

    final displayCalories = calories;
    final totalProtein = calorieState.totalProtein;
    final totalCarbs = calorieState.totalCarbs;
    final totalFat = calorieState.totalFat;

    final double protein = totalProtein.toDouble();
    final double carbs = totalCarbs.toDouble();
    final double fat = totalFat.toDouble();

    final nutritionPlan = calorieState.nutritionPlan;
    final double proteinTarget = nutritionPlan?.proteinTarget ?? 120;
    final double carbsTarget = nutritionPlan?.carbTarget ?? 354;
    final double fatTarget = nutritionPlan?.fatTarget ?? 94;

    // Check if user has necessary preferences
    final prefsState = context.read<PreferencesBloc>().state;
    bool hasEssentialMetrics = false;

    if (prefsState is PreferencesLoaded) {
      final preferences = prefsState.preferences;
      // Check if essential metrics are available
      hasEssentialMetrics = preferences.currentWeight != null &&
          preferences.height != null &&
          preferences.age != null &&
          preferences.dailyCalorieTarget != null &&
          preferences.dailyCalorieTarget! > 0;
    }

    // If user doesn't have essential metrics, show onboarding prompt
    if (!hasEssentialMetrics) {
      return _buildOnboardingPrompt(context);
    }

    return TransparentCard(
      onTap: widget.enableNavigation
          ? () {
              // Check if user has necessary preferences before navigating
              final prefsState = context.read<PreferencesBloc>().state;
              if (prefsState is PreferencesLoaded) {
                final preferences = prefsState.preferences;

                // Check if essential metrics are available
                final hasEssentialMetrics = preferences.currentWeight != null &&
                    preferences.height != null &&
                    preferences.age != null;

                if (hasEssentialMetrics) {
                  // User has necessary preferences, navigate to details screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalorieDetailsScreen(),
                    ),
                  );
                } else {
                  // User is missing necessary preferences, navigate to onboarding
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalorieOnboardingScreen(),
                    ),
                  );
                }
              } else {
                // Preferences not loaded yet, navigate to onboarding to be safe
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CalorieOnboardingScreen(),
                  ),
                );
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Calories",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Changed from CrossAxisAlignment.start
              children: [
                // Left side: Calorie Pie Chart
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                          height: 16.0), // Added to lower the pie chart
                      CaloriePieChart(
                        consumedCalories: displayCalories.toDouble(),
                        targetCalories: (target > 0 ? target : 2000).toDouble(),
                        chartSize: 160.0,
                        centerFontSize: 24.0,
                        labelFontSize: 12.0,
                        consumedColor: Color(0xFF54577C),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                // Right side: MacronutrientBarChart
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16.0),
                      MacronutrientBarChart(
                        protein: protein,
                        proteinTarget: proteinTarget,
                        carbs: carbs,
                        carbsTarget: carbsTarget,
                        fat: fat,
                        fatTarget: fatTarget,
                        proteinColor: Color(0xFF09ABCA7),
                        carbsColor: Colors.yellow,
                        fatColor: Color(0xFF06D6A0),
                        backgroundColor: Colors.grey.shade800,
                        barHeight: 12.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPrompt(BuildContext context) {
    return TransparentCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up your calorie tracking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please set your weight, height, and activity level to enable calorie tracking.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CalorieOnboardingScreen(),
                  ),
                );
              },
              child: const Text('Set up calorie tracking'),
            ),
          ],
        ),
      ),
    );
  }
}
