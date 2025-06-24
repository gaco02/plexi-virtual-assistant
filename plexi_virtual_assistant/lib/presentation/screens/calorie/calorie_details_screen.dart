import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../blocs/calorie/calorie_bloc.dart';
import '../../../blocs/calorie/calorie_state.dart';
import '../../../blocs/calorie/calorie_event.dart';
import '../../../data/models/calorie_entry.dart';
import '../../../data/models/user_preferences.dart';
import '../../../data/repositories/calorie_repository.dart';
import '../../../utils/nutrition_calculator.dart';
import '../../widgets/common/app_background.dart';
import '../../widgets/calorie/index.dart';

class CalorieDetailsScreen extends StatefulWidget {
  const CalorieDetailsScreen({super.key});

  @override
  State<CalorieDetailsScreen> createState() => _CalorieDetailsScreenState();
}

class _CalorieDetailsScreenState extends State<CalorieDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CalorieRepository _repository;
  List<CalorieEntry> _entries = [];
  bool _isLoading = true;
  bool _justCompletedOnboarding = true; // Add this flag
  String _selectedTimeFrame = 'Today';

  // Add a flag to prevent multiple didChangeDependencies calls
  bool _isInitialized = false;

  // Debouncing for calorie entry loading
  Timer? _loadEntriesDebouncer;
  DateTime? _lastLoadEntriesCall;

  // Selected date for the calendar view
  DateTime _selectedDate = DateTime.now();

  // Maximum number of entries to load at once to prevent memory issues
  final int _maxEntriesToLoad =
      200; // Increased from 50 to 200 to ensure historical entries are loaded

  // State variables to store fetched totals for Week/Month
  int? _fetchedTotalCalories;
  double? _fetchedTotalProtein;
  double? _fetchedTotalCarbs;
  double? _fetchedTotalFat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen for tab changes to refresh data when switching to history tab
    _tabController.addListener(() {
      print(
          "CalorieDetailsScreen: Tab controller listener triggered, current index: ${_tabController.index}");
      if (_tabController.index == 1) {
        print(
            "CalorieDetailsScreen: Tab switched to history tab (index 1), calling _loadCalorieEntries");
        // Use debounced loading when switching to history tab
        _loadCalorieEntries(forceRefresh: false);
      }
    });

    // Set initial loading state
    _isLoading = true;

    // Set a timeout to reset loading state if it gets stuck
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    print("CalorieDetailsScreen: didChangeDependencies called");

    // Only initialize repository and data once when the widget dependencies are first available
    if (!_isInitialized) {
      print("CalorieDetailsScreen: Initial data load triggered");
      _isInitialized = true;

      // Get the repository from context
      _repository = context.read<CalorieRepository>();

      // Check current bloc state before loading
      final calorieState = context.read<CalorieBloc>().state;
      print("CalorieDetailsScreen: Current bloc state: ${calorieState.status}");
      print(
          "CalorieDetailsScreen: Current totalCalories in bloc: ${calorieState.totalCalories}");

      // If we already have loaded data, don't trigger a reload
      if (calorieState.status == CalorieStatus.loaded) {
        print(
            "CalorieDetailsScreen: Already loaded state - not forcing refresh");
        setState(() {
          _isLoading = false;
        });
        // Just load the entries without forcing a refresh
        _loadCalorieEntries(forceRefresh: false);
      } else if (calorieState.status != CalorieStatus.loading) {
        print(
            "CalorieDetailsScreen: Loading state not detected - triggering daily calories load");
        // Only load daily calories if we don't have data
        context
            .read<CalorieBloc>()
            .add(const LoadDailyCalories(forceRefresh: true));

        // Wait for daily data to load before loading entries
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isLoading) {
            print("CalorieDetailsScreen: Loading entries after delay");
            _loadCalorieEntries(forceRefresh: false);
          }
        });
      }
    } else {
      print(
          "CalorieDetailsScreen: didChangeDependencies skipping load - already initialized");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loadEntriesDebouncer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar transparent on iOS (optional)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return BlocBuilder<PreferencesBloc, PreferencesState>(
      builder: (context, prefsState) {
        if (prefsState is PreferencesLoaded) {
          final preferences = prefsState.preferences;

          // Check if essential metrics are available
          final hasEssentialMetrics = preferences.currentWeight != null &&
              preferences.height != null &&
              preferences.age != null;

          // If essential metrics are missing, show a screen prompting to complete profile
          if (!hasEssentialMetrics) {
            return Scaffold(
                extendBodyBehindAppBar: true,
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text('Calorie Tracker'),
                ),
                body: AppBackground(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Complete Your Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'We need some information about you to provide accurate calorie tracking and recommendations.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () {
                              // Navigate to profile completion screen
                            },
                            child: const Text('Complete Profile'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
          }

          final filteredEntries = _getFilteredEntries();
          final dailyCalorieTarget = preferences.dailyCalorieTarget ?? 0;

          return BlocBuilder<CalorieBloc, CalorieState>(
            builder: (context, calorieState) {
              // Debug current state

              // Make sure to update loading state when bloc changes
              if (calorieState.status == CalorieStatus.loaded) {
                if (_isLoading) {
                  _isLoading = false;
                }
              }

              int totalCalories;
              double totalProtein;
              double totalCarbs;
              double totalFat;

              if (_selectedTimeFrame == 'Today') {
                // Use data from the bloc for Today.
                totalCalories = calorieState.totalCalories;
                totalProtein = calorieState.totalProtein;
                totalCarbs = calorieState.totalCarbs;
                totalFat = calorieState.totalFat;
              } else {
                // For Week/Month, use fetched totals if available,
                // otherwise fall back to totals from entries
                totalCalories =
                    _fetchedTotalCalories ?? _getTotalCalories(filteredEntries);
                totalProtein =
                    _fetchedTotalProtein ?? _getTotalProtein(filteredEntries);
                totalCarbs =
                    _fetchedTotalCarbs ?? _getTotalCarbs(filteredEntries);
                totalFat = _fetchedTotalFat ?? _getTotalFat(filteredEntries);
              }

              // Create nutrition plan if possible
              NutritionPlan? nutritionPlan;
              if (preferences.currentWeight != null &&
                  preferences.height != null &&
                  preferences.age != null) {
                try {
                  nutritionPlan = NutritionCalculator.generateNutritionPlan(
                    preferences,
                    activityLevel: preferences.activityLevel ??
                        ActivityLevel.moderatelyActive,
                  );
                } catch (e) {}
              }

              NutritionAnalysis? nutritionAnalysis;
              if (nutritionPlan != null) {
                nutritionAnalysis = NutritionCalculator.analyzeNutrition(
                  nutritionPlan,
                  actualCalories: totalCalories,
                  actualProtein: totalProtein,
                  actualCarbs: totalCarbs,
                  actualFat: totalFat,
                );
              }

              return Scaffold(
                // Make the body behind the AppBar
                extendBodyBehindAppBar: true,
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  // Transparent background so gradient shows
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text(
                    'Calorie details',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _refreshFromServer,
                      tooltip: 'Refresh from server',
                    ),
                  ],
                  // Put the TabBar inside the AppBar
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Summary'),
                      Tab(text: 'History'),
                    ],
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                  ),
                ),
                body: AppBackground(
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Show loading indicator at the top if data is loading
                        if (calorieState.status == CalorieStatus.loading ||
                            _isLoading)
                          LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: Colors.green,
                          ),

                        // Expand to fill the rest of the screen
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSummaryTab(
                                filteredEntries,
                                totalCalories,
                                totalProtein,
                                totalCarbs,
                                totalFat,
                                dailyCalorieTarget,
                                nutritionPlan,
                                nutritionAnalysis,
                              ),
                              _buildHistoryTab(filteredEntries),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else if (prefsState is PreferencesLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          return const Scaffold(
            body: Center(child: Text('Error loading preferences')),
          );
        }
      },
    );
  }

  // -------------------------------
  //  BUILD SUMMARY TAB
  // -------------------------------
  Widget _buildSummaryTab(
    List<CalorieEntry> entries,
    int totalCalories,
    double totalProtein,
    double totalCarbs,
    double totalFat,
    int dailyCalorieTarget,
    NutritionPlan? nutritionPlan,
    NutritionAnalysis? nutritionAnalysis,
  ) {
    return BlocBuilder<CalorieBloc, CalorieState>(
      buildWhen: (previous, current) {
        // Only rebuild when the entries or status changes
        return previous.entries != current.entries ||
            previous.status != current.status;
      },
      builder: (context, state) {
        // If we don't have entries in the state, trigger monthly data load
        // But only if we're not just coming from onboarding
        if (state.entries.isEmpty &&
            state.status != CalorieStatus.loading &&
            !_justCompletedOnboarding) {
          context.read<CalorieBloc>().add(const LoadMonthlyCalories());
        }

        // If this is the first time we're building after onboarding, set the flag to false
        // so that future refreshes will work normally
        if (_justCompletedOnboarding) {
          // Use Future.microtask to avoid setState during build
          Future.microtask(() {
            setState(() {
              _justCompletedOnboarding = false;
            });
          });
        }

        // Use either the entries from the state or the passed entries parameter
        final List<CalorieEntry> allEntries = state.entries.isNotEmpty
            ? state
                .entries // No conversion needed since entries is now List<CalorieEntry>
            : entries;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CalorieSummary(enableNavigation: false),

              if (state.status == CalorieStatus.loading && allEntries.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              if (state.status == CalorieStatus.error)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading data: ${state.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),

              if (allEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: WeeklyCalorieChart(
                    key: ValueKey(
                        'monthly_chart_${allEntries.length}_${state.status}'),
                    entries: allEntries,
                    targetCalories: dailyCalorieTarget,
                    showTarget: dailyCalorieTarget > 0,
                    barColor: const Color(0xFFfd7835),
                  ),
                ),

              // Nutrition goals if available
              if (nutritionPlan != null && nutritionAnalysis != null) ...[
                NutritionGoalsSection(
                  title: 'Nutrition Goals',
                  goals: [
                    NutritionGoalCard(
                      title: 'Calorie Goal',
                      value: '${nutritionPlan.calorieTarget.round()} cal',
                      status: nutritionAnalysis.isCalorieOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.caloriePercentage,
                    ),
                    NutritionGoalCard(
                      title: 'Protein Goal',
                      value: '${nutritionPlan.proteinTarget.round()} g',
                      status: nutritionAnalysis.isProteinOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.proteinPercentage,
                    ),
                    NutritionGoalCard(
                      title: 'Carbs Goal',
                      value: '${nutritionPlan.carbTarget.round()} g',
                      status: nutritionAnalysis.isCarbOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.carbPercentage,
                    ),
                    NutritionGoalCard(
                      title: 'Fat Goal',
                      value: '${nutritionPlan.fatTarget.round()} g',
                      status: nutritionAnalysis.isFatOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.fatPercentage,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // -------------------------------
  //  BUILD HISTORY TAB
  // -------------------------------
  Widget _buildHistoryTab(List<CalorieEntry> entries) {
    // For the history tab, we want to show ALL entries, not just those filtered by timeframe
    // So we use _entries directly instead of the filtered entries
    final allEntries = _entries;

    // Set a timeout to reset loading state if it gets stuck
    if (_isLoading) {
      Future.microtask(() {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isLoading) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      });
    }

    return SafeArea(
      child: Column(
        children: [
          // Date selector
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DateSelector(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
          ),

          // Food entries for the selected date and meal or "No entries" message
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading entries...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : allEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.no_food,
                              size: 64,
                              color: Colors.white.withAlpha(77),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No food entries available',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Entry'),
                              onPressed: _addEntry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildFoodEntriesForSelectedDate(allEntries),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodEntriesForSelectedDate(List<CalorieEntry> allEntries) {
    // Filter entries for the selected date

    // Filter by date only (month and day, not year)
    final dateFilteredEntries = allEntries.where((entry) {
      final matchesDate = entry.timestamp.month == _selectedDate.month &&
          entry.timestamp.day == _selectedDate.day;

      if (matchesDate) {}

      return matchesDate;
    }).toList();

    // No meal type filtering - use all entries that match the date
    final filteredEntries = dateFilteredEntries;

    // Remove duplicates by comparing foodItem and timestamp
    final uniqueEntries = <CalorieEntry>[];
    final seenItems = <String>{};

    for (final entry in filteredEntries) {
      final key = '${entry.foodItem}_${entry.timestamp.millisecondsSinceEpoch}';
      if (!seenItems.contains(key)) {
        seenItems.add(key);
        uniqueEntries.add(entry);
      }
    }

    if (uniqueEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food,
              size: 64,
              color: Colors.white.withAlpha(77),
            ),
            const SizedBox(height: 16),
            Text(
              'No food entries for ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
              onPressed: _addEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: uniqueEntries.length,
      itemBuilder: (context, index) {
        final entry = uniqueEntries[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FoodItemCard(
            name: entry.foodItem,
            calories: entry.calories,
            protein: entry.protein ?? 0,
            fat: entry.fat ?? 0,
            carbs: entry.carbs ?? 0,
            servingSize: '${entry.quantity} ${entry.unit}',
            onOptionsPressed: () => _showEntryOptions(entry),
          ),
        );
      },
    );
  }

  // -------------------------------
  //  SHOW ENTRY OPTIONS (Edit/Delete)
  // -------------------------------
  void _showEntryOptions(CalorieEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit Entry',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editEntry(entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Entry',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteEntry(entry);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editEntry(CalorieEntry entry) async {
    // Create controller with initial value from the entry
    final TextEditingController foodItemController =
        TextEditingController(text: entry.foodItem);

    // Store original values to use for calculations
    final double originalQuantity = entry.quantity;
    final int caloriesPerUnit = (entry.calories / originalQuantity).round();
    final int? proteinPerUnit = entry.protein != null
        ? (entry.protein! / originalQuantity).round()
        : null;
    final int? carbsPerUnit =
        entry.carbs != null ? (entry.carbs! / originalQuantity).round() : null;
    final int? fatPerUnit =
        entry.fat != null ? (entry.fat! / originalQuantity).round() : null;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Food Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: foodItemController,
              decoration: const InputDecoration(
                labelText: 'Food Item',
                hintText: 'e.g., 2 pizzas, 3 apples, etc.',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tip: Include quantity in the name (e.g., "2 pizzas") to automatically adjust nutritional values.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final foodItem = foodItemController.text.trim();
              if (foodItem.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Food item cannot be empty')),
                );
                return;
              }
              Navigator.pop(context, foodItem);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get the entry ID from the entry object
        final entryId = entry.id;

        // Parse the food item to extract quantity if present
        final RegExp quantityRegex = RegExp(r'^(\d+(\.\d+)?)\s+(.+)$');
        final match = quantityRegex.firstMatch(result);

        double newQuantity = originalQuantity;
        String foodName = result;

        if (match != null) {
          // Extract quantity and food name
          newQuantity = double.parse(match.group(1)!);
          foodName = match.group(3)!;
        }

        // Calculate new nutritional values based on the quantity
        final int newCalories = (caloriesPerUnit * newQuantity).round();
        final int? newProtein = proteinPerUnit != null
            ? (proteinPerUnit * newQuantity).round()
            : null;
        final int? newCarbs =
            carbsPerUnit != null ? (carbsPerUnit * newQuantity).round() : null;
        final int? newFat =
            fatPerUnit != null ? (fatPerUnit * newQuantity).round() : null;

        // First, remove the old entry from the local list for immediate UI feedback
        setState(() {
          _entries.removeWhere((e) => e.id == entryId);
        });

        // Dispatch the edit event to the CalorieBloc
        context.read<CalorieBloc>().add(
              EditCalorieEntry(
                id: entryId,
                foodItem: foodName, // Use the parsed food name
                calories: newCalories,
                protein: newProtein,
                carbs: newCarbs,
                fat: newFat,
                quantity: newQuantity,
                unit: entry.unit,
              ),
            );

        // Wait a moment to allow the server operation to complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Refresh the UI without force refresh since local cache is already updated
        await _loadCalorieEntries(forceRefresh: false);

        // Also refresh the daily calorie data to update the summary
        context
            .read<CalorieBloc>()
            .add(const LoadDailyCalories(forceRefresh: false));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating entry: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteEntry(CalorieEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Are you sure you want to delete "${entry.foodItem}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Prevent multiple deletion operations
      if (_isLoading) {
        print(
            "CalorieDetailsScreen: Delete operation already in progress, skipping");
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Get the entry ID from the entry object
        final entryId = entry.id;

        print(
            "CalorieDetailsScreen: Attempting to delete entry with ID: $entryId");

        // Optimistically remove from local list for immediate UI feedback
        setState(() {
          _entries.removeWhere((e) => e.id == entryId);
        });

        // Dispatch the delete event to the CalorieBloc and wait for completion
        context.read<CalorieBloc>().add(DeleteCalorieEntry(entryId));

        // Wait for the bloc operation to complete
        await Future.delayed(const Duration(milliseconds: 800));

        // Check if widget is still mounted before continuing
        if (!mounted) return;

        // The bloc delete operation already reloaded daily data,
        // so we just need to update our local entries without forcing another refresh
        await _loadCalorieEntries(forceRefresh: false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted successfully')),
          );
        }
      } catch (e) {
        print("CalorieDetailsScreen: Error deleting entry: $e");

        // Only show error and refresh if widget is still mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting entry: $e')),
          );

          // Just sync the UI with the current state, don't force server refresh
          await _loadCalorieEntries(forceRefresh: false);
        }
      } finally {
        // Only update state if widget is still mounted
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _loadCalorieEntries({bool forceRefresh = false}) async {
    print(
        "CalorieDetailsScreen: _loadCalorieEntries called with forceRefresh=$forceRefresh");

    // Implement debouncing to prevent duplicate calls - even for forced refreshes
    final now = DateTime.now();
    if (_lastLoadEntriesCall != null &&
        now.difference(_lastLoadEntriesCall!).inMilliseconds < 1000) {
      print(
          "CalorieDetailsScreen: Skipping _loadCalorieEntries due to debouncing (${now.difference(_lastLoadEntriesCall!).inMilliseconds}ms since last call)");
      return;
    }
    _lastLoadEntriesCall = now;

    // Cancel any existing debouncer
    _loadEntriesDebouncer?.cancel();

    // Always execute immediately for this version to see what's happening
    await _performLoadCalorieEntries(forceRefresh: forceRefresh);
  }

  Future<void> _performLoadCalorieEntries({bool forceRefresh = false}) async {
    print(
        "CalorieDetailsScreen: _performLoadCalorieEntries called with forceRefresh=$forceRefresh");

    // Check if widget is still mounted before starting
    if (!mounted) {
      print(
          "CalorieDetailsScreen: Widget not mounted, aborting load operation");
      return;
    }

    // Prevent duplicate loading operations
    if (_isLoading && !forceRefresh) {
      print("CalorieDetailsScreen: Already loading, skipping duplicate call");
      return;
    }

    setState(() => _isLoading = true);

    try {
      print(
          "CalorieDetailsScreen: Calling repository.getCalorieEntries(forceRefresh=$forceRefresh)");

      // Only get entries from repository with timeout protection
      final allEntries = await _repository
          .getCalorieEntries(forceRefresh: forceRefresh)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException(
            'Load calorie entries timed out after 30 seconds');
      });

      print(
          "CalorieDetailsScreen: Retrieved ${allEntries.length} entries from repository");

      // Check if widget is still mounted after async operation
      if (!mounted) {
        print("CalorieDetailsScreen: Widget unmounted during load, aborting");
        return;
      }

      // Sort entries by timestamp (newest first)
      allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Deduplicate entries to prevent memory issues and UI glitches
      final uniqueEntries = <CalorieEntry>[];
      final seenItems = <String>{};

      for (final entry in allEntries) {
        // Use a more robust key that includes timestamp milliseconds
        final key =
            '${entry.foodItem}_${entry.timestamp.millisecondsSinceEpoch}_${entry.calories}';
        if (!seenItems.contains(key)) {
          seenItems.add(key);
          uniqueEntries.add(entry);
        } else {
          print(
              "CalorieDetailsScreen: Filtered duplicate entry: ${entry.foodItem}");
        }
      }

      print(
          "CalorieDetailsScreen: After deduplication, got ${uniqueEntries.length} unique entries");

      // Limit the number to prevent memory issues
      final limitedEntries = uniqueEntries.take(_maxEntriesToLoad).toList();
      print(
          "CalorieDetailsScreen: Limited to ${limitedEntries.length} entries");

      // Final mounted check before updating state
      if (mounted) {
        setState(() {
          _entries = limitedEntries;
          _isLoading = false;
        });

        // Only update the CalorieBloc if we've refreshed the data
        if (forceRefresh && mounted) {
          print(
              "CalorieDetailsScreen: Dispatching LoadDailyCalories event to bloc due to forceRefresh=true");
          context
              .read<CalorieBloc>()
              .add(const LoadDailyCalories(forceRefresh: true));
        }
      }
    } catch (e) {
      print("CalorieDetailsScreen: Error loading entries: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading entries: $e')),
        );
      }
    }
  }

  // -------------------------------
  //  FILTER ENTRIES BY TIME FRAME
  // -------------------------------
  List<CalorieEntry> _getFilteredEntries() {
    if (_entries.isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<CalorieEntry> filteredEntries;

    switch (_selectedTimeFrame) {
      case 'Today':
        filteredEntries = _entries.where((entry) {
          final entryDate = DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          );
          final isToday = entryDate.isAtSameMomentAs(today);
          return isToday;
        }).toList();
        break;
      case 'Week':
        final weekAgo = today.subtract(const Duration(days: 7));
        filteredEntries = _entries.where((entry) {
          final entryDate = DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          );
          return entryDate.isAfter(weekAgo.subtract(const Duration(days: 1))) &&
              entryDate.isBefore(today.add(const Duration(days: 1)));
        }).toList();
        break;
      case 'Month':
        final monthAgo = DateTime(today.year, today.month - 1, today.day);
        filteredEntries = _entries.where((entry) {
          final entryDate = DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          );
          return entryDate
                  .isAfter(monthAgo.subtract(const Duration(days: 1))) &&
              entryDate.isBefore(today.add(const Duration(days: 1)));
        }).toList();
        break;
      default:
        filteredEntries = List.from(_entries);
    }

    // Debug: Check for March 28 entries specifically (can be removed in production)
    final march28Entries = filteredEntries
        .where(
            (entry) => entry.timestamp.month == 3 && entry.timestamp.day == 28)
        .toList();

    if (march28Entries.isNotEmpty) {
      print("Found ${march28Entries.length} entries for March 28");
    }

    return filteredEntries;
  }

  // -------------------------------
  //  CALCULATIONS
  // -------------------------------
  int _getTotalCalories(List<CalorieEntry> entries) =>
      entries.fold(0, (sum, e) => sum + e.calories);

  double _getTotalProtein(List<CalorieEntry> entries) =>
      entries.fold(0.0, (sum, e) => sum + (e.protein?.toDouble() ?? 0.0));

  double _getTotalCarbs(List<CalorieEntry> entries) =>
      entries.fold(0.0, (sum, e) => sum + (e.carbs?.toDouble() ?? 0.0));

  double _getTotalFat(List<CalorieEntry> entries) =>
      entries.fold(0.0, (sum, e) => sum + (e.fat?.toDouble() ?? 0.0));

  // -------------------------------
  //  REFRESH FROM SERVER
  // -------------------------------
  Future<void> _refreshFromServer() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshing calorie data...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Use the existing getCalorieEntries method with forceRefresh set to true
      await _repository.getCalorieEntries(forceRefresh: true);

      context
          .read<CalorieBloc>()
          .add(const LoadDailyCalories(forceRefresh: true));
      await _loadCalorieEntries(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calorie data refreshed from server'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: $e')),
      );
    }
  }

  // -------------------------------
  //  LOAD CALORIE ENTRIES
  // Add a new calorie entry
  Future<void> _addEntry() async {
    // Create controllers for the form fields
    final TextEditingController foodItemController = TextEditingController();
    final TextEditingController caloriesController = TextEditingController();
    final TextEditingController proteinController = TextEditingController();
    final TextEditingController carbsController = TextEditingController();
    final TextEditingController fatController = TextEditingController();
    final TextEditingController quantityController =
        TextEditingController(text: '1');

    // Default unit to 'serving'
    String selectedUnit = 'serving';

    // List of available units
    final List<String> units = [
      'serving',
      'g',
      'oz',
      'cup',
      'tbsp',
      'tsp',
      'piece',
      'bowl'
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Calorie Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: foodItemController,
                decoration: const InputDecoration(labelText: 'Food Item'),
              ),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: proteinController,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: carbsController,
                decoration: const InputDecoration(labelText: 'Carbs (g)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(labelText: 'Fat (g)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: units.map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedUnit = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Validate and create the entry
              final foodItem = foodItemController.text.trim();
              final caloriesText = caloriesController.text.trim();
              final quantityText = quantityController.text.trim();

              if (foodItem.isEmpty ||
                  caloriesText.isEmpty ||
                  quantityText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill in all required fields')),
                );
                return;
              }

              try {
                final calories = int.parse(caloriesText);
                final protein = proteinController.text.isEmpty
                    ? 0
                    : int.parse(proteinController.text);
                final carbs = carbsController.text.isEmpty
                    ? 0
                    : int.parse(carbsController.text);
                final fat = fatController.text.isEmpty
                    ? 0
                    : int.parse(fatController.text);
                final quantity = double.parse(quantityText);

                Navigator.pop(context, {
                  'foodItem': foodItem,
                  'calories': calories,
                  'protein': protein,
                  'carbs': carbs,
                  'fat': fat,
                  'quantity': quantity,
                  'unit': selectedUnit,
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid input: $e')),
                );
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create a new entry
        final entry = CalorieEntry(
          foodItem: result['foodItem'],
          calories: result['calories'],
          protein: result['protein'].toDouble(),
          carbs: result['carbs'].toDouble(),
          fat: result['fat'].toDouble(),
          quantity: result['quantity'],
          unit: result['unit'],
          timestamp: DateTime.now(),
        );

        // Add the entry to the repository
        final success = await _repository.addCalorieEntry(entry);

        if (success) {
          // Refresh to get the latest data including server-generated ID
          await _loadCalorieEntries(forceRefresh: true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry added successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add entry')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding entry: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
