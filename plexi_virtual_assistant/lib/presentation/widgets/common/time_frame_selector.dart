// lib/presentation/widgets/time_frame_selector.dart
import 'package:flutter/material.dart';

class TimeFrameSelector extends StatelessWidget {
  final List<String> timeFrames;
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;

  const TimeFrameSelector({
    Key? key,
    required this.timeFrames,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: timeFrames.map((timeFrame) {
          final isSelected = timeFrame == selectedTimeFrame;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTimeFrameChanged(timeFrame),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  timeFrame,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
