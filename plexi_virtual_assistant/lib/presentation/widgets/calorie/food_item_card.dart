import 'package:flutter/material.dart';
import '../common/transparent_card.dart';

class FoodItemCard extends StatelessWidget {
  final String name;
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final String? imagePath;
  final VoidCallback? onOptionsPressed;
  final String? servingSize;

  const FoodItemCard({
    Key? key,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.imagePath,
    this.onOptionsPressed,
    this.servingSize = '100g',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TransparentCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),

          // Food details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Food name and calories
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$calories kcal',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (servingSize != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· $servingSize',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Scrollable nutrient pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildNutrientPill('Protein', protein, Colors.green),
                      const SizedBox(width: 8),
                      _buildNutrientPill('Fats', fat, Colors.amber),
                      const SizedBox(width: 8),
                      _buildNutrientPill('Carbs', carbs,
                          const Color.fromARGB(255, 178, 82, 195)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Options menu
          if (onOptionsPressed != null)
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white70,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onOptionsPressed,
            ),
        ],
      ),
    );
  }

  Widget _buildNutrientPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${value}g',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
