import 'package:flutter/material.dart';

class WeatherSummary extends StatelessWidget {
  const WeatherSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.white.withAlpha(77),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  // Prevents text overflow
                  child: Text(
                    'Today\'s Weather',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
                Text(
                  '9°C',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Hourly forecast
            ClipRect(
              // Prevents possible pixel overdraw
              child: SizedBox(
                width: double
                    .infinity, // Ensures it doesn't extend beyond screen width
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final hours = ['11am', '12pm', '1pm', '2pm', '3pm', '4pm'];
                    return Padding(
                      padding: const EdgeInsets.only(
                          right: 16), // Adjusted padding to prevent overflow
                      child: Column(
                        children: [
                          Text(
                            hours[index],
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          const Icon(
                            Icons.cloudy_snowing,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '9°',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Weather conditions
            const Row(
              children: [
                Icon(Icons.umbrella, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Flexible(
                  // Ensures long text wraps properly
                  child: Text(
                    'Rain likely to continue',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.thermostat, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Today\'s temperatures will be higher than yesterday',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
