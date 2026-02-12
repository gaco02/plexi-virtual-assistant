import 'package:equatable/equatable.dart';

class Restaurant extends Equatable {
  final int id;
  final String name;
  final String cuisineType;
  final String priceLevel;
  final int totalLikes;
  final List<String> highlights;
  final String imageUrl;
  final List<String> cuisine;
  final String address;
  final String description;
  final double rating;
  final List<String> menu;

  const Restaurant({
    this.id = 0,
    required this.name,
    required this.cuisineType,
    required this.priceLevel,
    required this.totalLikes,
    required this.highlights,
    required this.imageUrl,
    required this.cuisine,
    required this.address,
    required this.description,
    required this.rating,
    required this.menu,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // Handle highlights which might be a string, list, or null
    List<String> parseHighlights(dynamic highlights) {
      if (highlights == null) return [];
      if (highlights is String) return [highlights];
      if (highlights is List) {
        return highlights.map((item) => item.toString()).toList();
      }
      return [];
    }

    // Handle cuisine which might be a string, list, or null
    List<String> parseCuisine(dynamic cuisine) {
      if (cuisine == null) return [];
      if (cuisine is String) return [cuisine];
      if (cuisine is List) {
        return cuisine.map((item) => item.toString()).toList();
      }
      return [];
    }

    // Handle menu which might be a string, list, or null
    List<String> parseMenu(dynamic menu) {
      if (menu == null) return [];
      if (menu is String) return [menu];
      if (menu is List) {
        return menu.map((item) => item.toString()).toList();
      }
      return [];
    }

    return Restaurant(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Restaurant',
      cuisineType: json['cuisine_type'] ?? 'Various',
      priceLevel: json['price_level'] ?? '\$',
      totalLikes: json['total_likes'] ?? 0,
      highlights: parseHighlights(json['highlights']),
      imageUrl: json['image_url'] ??
          'https://dummyimage.com/600x400/cccccc/ffffff&text=Restaurant',
      cuisine: parseCuisine(json['cuisine']),
      address: json['address'] ?? 'Address not available',
      description: json['description'] ?? 'No description available',
      rating:
          (json['rating'] != null) ? (json['rating'] as num).toDouble() : 0.0,
      menu: parseMenu(json['menu']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cuisine_type': cuisineType,
      'price_level': priceLevel,
      'total_likes': totalLikes,
      'highlights': highlights,
      'image_url': imageUrl,
      'cuisine': cuisine,
      'address': address,
      'description': description,
      'rating': rating,
      'menu': menu,
    };
  }

  @override
  List<Object> get props => [
        id,
        name,
        cuisineType,
        priceLevel,
        totalLikes,
        highlights,
        imageUrl,
        cuisine,
        address,
        description,
        rating,
        menu
      ];
}
