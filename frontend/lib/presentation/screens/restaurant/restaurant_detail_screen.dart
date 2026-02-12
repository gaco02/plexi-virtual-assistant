import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';
import '../../../blocs/restaurant/restaurant_bloc.dart';
import '../../../blocs/restaurant/restaurant_event.dart';
import '../../../blocs/restaurant/restaurant_state.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/common/cached_network_image.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load restaurant details when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<RestaurantBloc>()
          .add(LoadRestaurantDetailsEvent(widget.restaurantId));
    });
  }

  Future<void> _launchMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final googleMapsAppUrl =
        'geo:0,0?q=$encodedAddress'; // Tries to open Google Maps app
    final googleMapsWebUrl =
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress';

    if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
      await launchUrl(Uri.parse(googleMapsAppUrl));
    } else if (await canLaunchUrl(Uri.parse(googleMapsWebUrl))) {
      await launchUrl(Uri.parse(googleMapsWebUrl));
    } else {
      log('Could not launch Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RestaurantBloc, RestaurantState>(
      builder: (context, state) {
        // Loading state
        if (state is RestaurantLoading) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            extendBodyBehindAppBar: true,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Error state
        if (state is RestaurantError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Restaurant Details',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            extendBodyBehindAppBar: true,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.message}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<RestaurantBloc>().add(
                            LoadRestaurantDetailsEvent(widget.restaurantId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Restaurant details loaded
        if (state is RestaurantDetailLoaded) {
          final restaurant = state.restaurant;
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        restaurant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          SafeNetworkImage(
                            imageUrl: restaurant.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: Colors.grey.shade800,
                              child: const Center(
                                child: Icon(
                                  Icons.restaurant,
                                  color: Colors.white54,
                                  size: 50,
                                ),
                              ),
                            ),
                          ),
                          // Gradient overlay for better text visibility
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(77),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rating and price level
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text(
                                restaurant.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const SizedBox(width: 16),
                              Expanded(
                                // Add this to prevent overflow
                                child: Text(
                                  restaurant.priceLevel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow
                                      .ellipsis, // Prevents overflow issue
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  restaurant.cuisineType,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow
                                      .ellipsis, // Prevents text overflow
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            restaurant.description,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cuisine
                          const Text(
                            'Cuisine',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: restaurant.cuisine.isEmpty
                                ? [const Chip(label: Text('Various'))]
                                : restaurant.cuisine
                                    .map(
                                      (cuisine) => Chip(label: Text(cuisine)),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: 16),

                          // Address with map link
                          const Text(
                            'Address',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _launchMaps(restaurant.address),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    restaurant.address,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Menu section if available
                          if (restaurant.menu.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Menu',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: restaurant.menu.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(
                                    restaurant.menu[index],
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  leading: const Icon(
                                    Icons.restaurant_menu,
                                    color: Colors.white70,
                                  ),
                                );
                              },
                            ),
                          ],

                          // Highlights section if available
                          if (restaurant.highlights.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Highlights',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: restaurant.highlights
                                  .map(
                                    (highlight) => Chip(
                                      label: Text(highlight),
                                      backgroundColor:
                                          Colors.blue.withAlpha(77),
                                      labelStyle:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],

                          // Bottom padding
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Default loading state (initial state)
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}
