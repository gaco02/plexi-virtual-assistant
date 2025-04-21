import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/calorie/calorie_bloc.dart';
import '../../../blocs/calorie/calorie_state.dart';
import '../../../data/models/calorie_entry.dart';
import '../common/transparent_card.dart';
import 'package:plexi_virtual_assistant/blocs/calorie/calorie_event.dart';
import 'package:flutter/foundation.dart';

class WeeklyCalorieChart extends StatefulWidget {
  final List<CalorieEntry>? entries;
  final int targetCalories;
  final bool showTarget;
  final Color barColor;
  final Color targetLineColor;
  final Color backgroundColor;
  final double cornerRadius;

  const WeeklyCalorieChart({
    Key? key,
    this.entries,
    this.targetCalories = 0,
    this.showTarget = true,
    this.barColor = const Color(0xFFfd7835),
    this.targetLineColor = Colors.redAccent,
    this.backgroundColor = const Color(0x33FFFFFF),
    this.cornerRadius = 8.0,
  }) : super(key: key);

  @override
  State<WeeklyCalorieChart> createState() => _WeeklyCalorieChartState();
}

class _WeeklyCalorieChartState extends State<WeeklyCalorieChart> {
  int? touchedIndex;
  final ScrollController _scrollController = ScrollController();
  Map<DateTime, int> _dailyCalories = {};
  List<DateTime> _visibleDays = [];
  bool _hasInitialized = false;
  bool _isProcessing = false;
  int? _todayIndex; // Store today's index in the visible days list

  @override
  void initState() {
    super.initState();

    // Don't process entries in initState, wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _processEntries(widget.entries ?? []);
    }
  }

  @override
  void didUpdateWidget(WeeklyCalorieChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only process entries if they've changed and we're not already processing
    if (!_isProcessing && !listEquals(widget.entries, oldWidget.entries)) {
      _processEntries(widget.entries ?? []);
    }
  }

  // Scroll to show the last 7 days (including today)
  void _scrollToToday() {
    if (_visibleDays.isEmpty || _todayIndex == null) {
      return;
    }

    // Calculate position to show the last 7 days (or as many as available up to today)
    final daysToShow = 7;
    final startIndex =
        _todayIndex! >= daysToShow - 1 ? _todayIndex! - (daysToShow - 1) : 0;

    // Calculate scroll offset (40.0 is the width per day)
    final scrollOffset = startIndex * 40.0;

    // Use Future.delayed to ensure the scroll happens after the widget is built
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          scrollOffset,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _processEntries(List<CalorieEntry> entries) {
    if (entries.isEmpty) {
      setState(() {
        _dailyCalories = {};
        _visibleDays = [];
        _todayIndex = null;
      });
      return;
    }

    // Sort entries by date
    final sortedEntries = List<CalorieEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Get the first day of the current month
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year, now.month, 1);
    final lastDate = DateTime(now.year, now.month + 1, 0);

    // Initialize daily calories map
    final Map<DateTime, int> newDailyCalories = {};
    final List<DateTime> newVisibleDays = [];
    int? newTodayIndex;

    // Generate all days in the month
    var currentDate = firstDate;
    int dayIndex = 0;
    while (currentDate.isBefore(lastDate.add(const Duration(days: 1)))) {
      final normalizedDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      // Mark today's index
      if (normalizedDate.year == today.year &&
          normalizedDate.month == today.month &&
          normalizedDate.day == today.day) {
        newTodayIndex = dayIndex;
      }

      newDailyCalories[normalizedDate] = 0;
      newVisibleDays.add(normalizedDate);
      currentDate = currentDate.add(const Duration(days: 1));
      dayIndex++;
    }

    // Sum calories for each day
    for (final entry in sortedEntries) {
      final normalizedDate = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      if (normalizedDate.isAfter(firstDate.subtract(const Duration(days: 1))) &&
          normalizedDate.isBefore(lastDate.add(const Duration(days: 1)))) {
        newDailyCalories[normalizedDate] =
            (newDailyCalories[normalizedDate] ?? 0) + entry.calories;
      }
    }
    newDailyCalories.forEach((date, calories) {
      if (calories > 0) {}
    });

    // Only update state if the data has actually changed
    final dataChanged = !mapEquals(_dailyCalories, newDailyCalories) ||
        _todayIndex != newTodayIndex;

    if (dataChanged) {
      setState(() {
        _dailyCalories = newDailyCalories;
        _visibleDays = newVisibleDays;
        _todayIndex = newTodayIndex;
      });

      // Scroll to today's position after state update
      _scrollToToday();
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.entries == null
        ? _buildChartFromBloc()
        : _buildChartWithEntries(widget.entries!);
  }

  Widget _buildChartFromBloc() {
    return BlocBuilder<CalorieBloc, CalorieState>(
      buildWhen: (previous, current) {
        // Only rebuild when entries change or status changes from loading to loaded
        final shouldRebuild = previous.entries != current.entries ||
            (previous.status == CalorieStatus.loading &&
                current.status == CalorieStatus.loaded);
        return shouldRebuild;
      },
      builder: (context, state) {
        if (state.status == CalorieStatus.loading && _dailyCalories.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading monthly data...',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        if (state.status == CalorieStatus.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'Error loading data: ${state.errorMessage}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                TextButton(
                  // Remove the automatic trigger of LoadMonthlyCalories here
                  // and only load data when explicitly requested by the user
                  onPressed: () {},
                  child: Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        final List<CalorieEntry> typedEntries =
            List<CalorieEntry>.from(state.entries);
        // Use dailyTotals cache if available
        if (state.dailyTotals != null && state.dailyTotals!.isNotEmpty) {
          // Set up visible days and daily calories from cache
          final sortedDays = state.dailyTotals!.keys.toList()
            ..sort((a, b) => a.compareTo(b));
          _visibleDays = sortedDays;
          _dailyCalories = Map.from(state.dailyTotals!);
          // Find today's index
          final today = DateTime.now();
          _todayIndex = sortedDays.indexWhere((d) =>
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day);
        } else {
          // Fallback: process entries as before
          _processEntries(typedEntries);
        }
        return _buildChartWithEntries(typedEntries);
      },
    );
  }

  Widget _buildChartWithEntries(List<CalorieEntry> entries) {
    if (!_isProcessing) {
      _processEntries(entries);
    }

    // Calculate max Y value for the chart
    final maxCalories = _dailyCalories.values.isEmpty
        ? 0
        : _dailyCalories.values.reduce(maxInt);
    final maxY = maxDouble(
      widget.targetCalories * 1.2,
      maxCalories * 1.2,
    );

    return TransparentCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Daily calorie consumption',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: maxDouble(_visibleDays.length * 40.0,
                        MediaQuery.of(context).size.width - 32),
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipColor: (group) => Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final date = _visibleDays[groupIndex];
                              return BarTooltipItem(
                                '${date.month}/${date.day}\n${rod.toY.round()} cal',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          touchCallback:
                              (FlTouchEvent event, barTouchResponse) {
                            setState(() {
                              touchedIndex = event
                                          .isInterestedForInteractions &&
                                      barTouchResponse?.spot != null
                                  ? barTouchResponse!.spot!.touchedBarGroupIndex
                                  : null;
                            });
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= _visibleDays.length)
                                  return const SizedBox();
                                final date = _visibleDays[value.toInt()];
                                return SideTitleWidget(
                                  space: 4,
                                  meta: meta,
                                  child: Text(
                                    '${date.day}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _createBarGroups(),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: 500,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.white10,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        extraLinesData:
                            widget.showTarget && widget.targetCalories > 0
                                ? ExtraLinesData(
                                    horizontalLines: [
                                      HorizontalLine(
                                        y: widget.targetCalories.toDouble(),
                                        color: widget.targetLineColor,
                                        strokeWidth: 2,
                                        dashArray: [5, 5],
                                        label: HorizontalLineLabel(
                                          show: true,
                                          alignment: Alignment.topRight,
                                          padding: const EdgeInsets.only(
                                              right: 5, bottom: 5),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                          labelResolver: (line) => 'Target',
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 250),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    if (_visibleDays.isEmpty) {
      return [];
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // Define colors for different states
    final Color normalColor = widget.barColor;
    final Color todayColor = Colors.greenAccent;
    final Color excessColor = Colors.redAccent;
    final Color todayExcessColor = Colors.redAccent;

    return _visibleDays.asMap().entries.map((entry) {
      final index = entry.key;
      final date = entry.value;
      final calories = _dailyCalories[date] ?? 0;

      final bool isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final bool isOverTarget =
          widget.targetCalories > 0 && calories > widget.targetCalories;

      // Select appropriate color based on conditions
      Color barColor;
      if (isToday && isOverTarget) {
        barColor = todayExcessColor;
      } else if (isToday) {
        barColor = todayColor;
      } else if (isOverTarget) {
        barColor = excessColor;
      } else {
        barColor = normalColor;
      }

      final bool isHighlighted = touchedIndex == index;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: calories.toDouble(),
            color: isHighlighted ? barColor.withAlpha(77) : barColor,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: widget.targetCalories.toDouble(),
              color: widget.backgroundColor.withAlpha(77),
            ),
          ),
        ],
        showingTooltipIndicators: touchedIndex == index ? [0] : [],
      );
    }).toList();
  }
}

// Helper function to get max value for integers
int maxInt(int a, int b) => a > b ? a : b;

// Helper function to get max value for doubles
double maxDouble(double a, double b) => a > b ? a : b;
