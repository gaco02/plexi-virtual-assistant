import 'package:flutter/material.dart';
import '../../../data/models/restaurant.dart';
import 'restaurant_card.dart';

class RestaurantList extends StatelessWidget {
  final List<Restaurant> restaurants;

  const RestaurantList({
    super.key,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          return RestaurantCard(
            restaurant: restaurants[index],
            onTap: () {
              // Handle restaurant tap
            },
          );
        },
      ),
    );
  }
}
