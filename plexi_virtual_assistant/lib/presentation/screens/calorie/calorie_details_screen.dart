import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../../widgets/common/time_frame_selector.dart';

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
  bool _hasLoadedInitialData = false;
  String _selectedTimeFrame = 'Today';
  final List<String> _timeFrames = ['Today', 'Week', 'Month'];

  // Selected date for the calendar view
  DateTime _selectedDate = DateTime.now();

  // Maximum number of entries to load at once to prevent memory issues
  final int _maxEntriesToLoad =
      200; // Increased from 50 to 200 to ensure historical entries are loaded

  // Maximum number of entries to display in the chart
  final int _maxChartEntries = 15; // Reduced from 30 to 15

  // Map to store expanded state of each day in history tab
  final Map<String, bool> _expandedDays = {};

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
      if (_tabController.index == 1) {
        _loadCalorieEntries(forceRefresh: true);
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

    // Only load data once when the widget is first built
    if (!_hasLoadedInitialData) {
      _hasLoadedInitialData = true;

      // Get the repository from context
      _repository = context.read<CalorieRepository>();

      // Check current bloc state before loading
      final calorieState = context.read<CalorieBloc>().state;

      // If we already have loaded data, don't trigger a reload
      if (calorieState.status == CalorieStatus.loaded) {
        _isLoading = false;
        // Just load the entries without forcing a refresh
        _loadCalorieEntries(forceRefresh: false);
      } else if (calorieState.status != CalorieStatus.loading) {
        // Only load daily calories if we don't have data
        context
            .read<CalorieBloc>()
            .add(const LoadDailyCalories(forceRefresh: true));

        // Wait for daily data to load before loading entries
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isLoading) {
            _loadCalorieEntries(forceRefresh: true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                          style: TextStyle(color: Colors.white70, fontSize: 16),
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
              ),
            );
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
        if (state.entries.isEmpty && state.status != CalorieStatus.loading) {
          context.read<CalorieBloc>().add(const LoadMonthlyCalories());
        }

        // Use either the entries from the state or the passed entries parameter
        final List<CalorieEntry> allEntries = state.entries.isNotEmpty
            ? List<CalorieEntry>.from(state.entries)
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
                      percentage: nutritionAnalysis.caloriePercentage ?? 0,
                    ),
                    NutritionGoalCard(
                      title: 'Protein Goal',
                      value: '${nutritionPlan.proteinTarget.round()} g',
                      status: nutritionAnalysis.isProteinOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.proteinPercentage ?? 0,
                    ),
                    NutritionGoalCard(
                      title: 'Carbs Goal',
                      value: '${nutritionPlan.carbTarget.round()} g',
                      status: nutritionAnalysis.isCarbOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.carbPercentage ?? 0,
                    ),
                    NutritionGoalCard(
                      title: 'Fat Goal',
                      value: '${nutritionPlan.fatTarget.round()} g',
                      status: nutritionAnalysis.isFatOnTarget == true
                          ? NutritionStatus.good
                          : NutritionStatus.warning,
                      percentage: nutritionAnalysis.fatPercentage ?? 0,
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

        if (entryId == null) {
          throw Exception('Entry ID is missing');
        }

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

        // Refresh the UI with force refresh to ensure we get the latest data
        await _loadCalorieEntriesWithForceRefresh();

        // Also refresh the daily calorie data to update the summary
        context
            .read<CalorieBloc>()
            .add(const LoadDailyCalories(forceRefresh: true));

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

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get the entry ID from the entry object
        final entryId = entry.id;

        // Print debug information

        if (entryId == null) {
          throw Exception('Entry ID is missing');
        }

        // Dispatch the delete event to the CalorieBloc
        context.read<CalorieBloc>().add(DeleteCalorieEntry(entryId));

        // Remove the entry from the local list immediately for better UX
        setState(() {
          _entries.removeWhere((e) => e.id == entryId);
        });

        // Wait a moment to allow the server operation to complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Force refresh from server to ensure we have the latest data
        await _loadCalorieEntriesWithForceRefresh();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entry: $e')),
        );

        // Refresh entries anyway to ensure UI is in sync with server
        await _loadCalorieEntriesWithForceRefresh();
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCalorieEntries({bool forceRefresh = false}) async {
    // Prevent duplicate loading operations but don't return if already loading
    // since we need to ensure data loads
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Only refresh from server if explicitly requested
      if (forceRefresh) {
        await _repository.refreshFromServer();
      }

      final allEntries =
          await _repository.getCalorieEntries(forceRefresh: forceRefresh);
      allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Deduplicate
      final uniqueEntries = <CalorieEntry>[];
      final seenItems = <String>{};
      for (final entry in allEntries) {
        final key =
            '${entry.foodItem}_${entry.timestamp.millisecondsSinceEpoch}';
        if (!seenItems.contains(key)) {
          seenItems.add(key);
          uniqueEntries.add(entry);
        }
      }

      // Limit the number
      final limitedEntries = uniqueEntries.take(_maxEntriesToLoad).toList();

      if (mounted) {
        setState(() {
          _entries = limitedEntries;
          _isLoading = false;
        });

        // Only update the CalorieBloc if we've refreshed the data
        if (forceRefresh) {
          context
              .read<CalorieBloc>()
              .add(const LoadDailyCalories(forceRefresh: true));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading entries: $e')),
        );
      }
    }
  }

  // -------------------------------
  //  BUILD TIME FRAME SELECTOR
  // -------------------------------
  Widget _buildTimeFrameSelector() {
    return TimeFrameSelector(
      timeFrames: _timeFrames,
      selectedTimeFrame: _selectedTimeFrame,
      onTimeFrameChanged: (timeFrame) {
        setState(() {
          _selectedTimeFrame = timeFrame;
        });
        _handleTimeFrameChange(timeFrame);
      },
    );
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

    // Check for March 28 entries specifically
    final march28Entries = filteredEntries
        .where(
            (entry) => entry.timestamp.month == 3 && entry.timestamp.day == 28)
        .toList();

    if (march28Entries.isNotEmpty) {
      for (var entry in march28Entries) {}
    } else {}

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
  //  TIME FRAME CHANGES
  // -------------------------------
  void _handleTimeFrameChange(String timeFrame) async {
    if (_isLoading || _selectedTimeFrame == timeFrame) return;

    setState(() {
      _selectedTimeFrame = timeFrame;
      _isLoading = true;
      _fetchedTotalCalories = null;
      _fetchedTotalProtein = null;
      _fetchedTotalCarbs = null;
      _fetchedTotalFat = null;
    });

    try {
      switch (timeFrame) {
        case 'Today':
          context
              .read<CalorieBloc>()
              .add(const LoadDailyCalories(forceRefresh: true));
          break;
        case 'Week':
          context.read<CalorieBloc>().add(const LoadWeeklyCalories());
          break;
        case 'Month':
          final data = await _repository.getMonthlyCalories(forceRefresh: true);
          _updateFetchedData(data);
          break;
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

      final success = await _repository.refreshFromServer();
      if (success) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh data from server'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // -------------------------------
  //  LOAD CALORIE ENTRIES
  // -------------------------------
  Future<void> _loadCalorieEntriesWithForceRefresh() async {
    await _loadCalorieEntries(forceRefresh: true);
  }

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
          // Force refresh to get the latest data including server-generated ID
          await _loadCalorieEntriesWithForceRefresh();

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

  void _updateFetchedData(Map<String, dynamic> data) {
    setState(() {
      _fetchedTotalCalories = data['total_calories'];
      _fetchedTotalProtein = data['total_protein'];
      _fetchedTotalCarbs = data['total_carbs'];
      _fetchedTotalFat = data['total_fat'];
    });
  }
}
