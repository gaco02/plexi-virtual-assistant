import 'package:flutter/material.dart';

class DateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final bool showMonth;

  const DateSelector({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    this.showMonth = true,
  }) : super(key: key);

  @override
  _DateSelectorState createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Delay the scroll to today’s position after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  void _scrollToToday() {
    final todayIndex = 29; // Index of today in the list
    final scrollOffset = todayIndex * 60.0; // Estimated width per item
    _scrollController.jumpTo(scrollOffset);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    
    // Generate dates for the past 30 days including today
    final dates = List.generate(
      30, // Show last 30 days
      (index) => today.subtract(Duration(days: 29 - index)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController, // Attach the scroll controller
      child: Row(
        children: dates.map((date) {
          final isSelected = widget.selectedDate.year == date.year &&
              widget.selectedDate.month == date.month &&
              widget.selectedDate.day == date.day;

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? Colors.orange : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showMonth)
                    Text(
                      _getMonthAbbreviation(date),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  if (widget.showMonth) const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getMonthAbbreviation(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[date.month - 1];
  }

  @override
  void dispose() {
    _scrollController
        .dispose(); // Dispose the controller when widget is removed
    super.dispose();
  }
}
