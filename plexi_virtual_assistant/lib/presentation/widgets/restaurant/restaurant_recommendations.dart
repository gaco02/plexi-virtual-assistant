import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';
import '../../../blocs/restaurant/restaurant_bloc.dart';
import '../../../blocs/restaurant/restaurant_event.dart';
import '../../../blocs/restaurant/restaurant_state.dart';
import '../../../data/models/restaurant.dart';
import '../../screens/restaurant/restaurant_detail_screen.dart';
import '../common/transparent_card.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/cached_network_image.dart';

class RestaurantRecommendations extends StatefulWidget {
  const RestaurantRecommendations({super.key});

  @override
  State<RestaurantRecommendations> createState() =>
      _RestaurantRecommendationsState();
}

class _RestaurantRecommendationsState extends State<RestaurantRecommendations>
    with AutomaticKeepAliveClientMixin {
  bool _hasLoadedRecommendations = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    log('RestaurantRecommendations: initState');
    _loadRecommendations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    log('RestaurantRecommendations: didChangeDependencies');
    _loadRecommendations();
  }

  void _loadRecommendations() {
    final bloc = context.read<RestaurantBloc>();
    final currentState = bloc.state;

    // Only load if we don't have restaurants already or if there was an error
    if (!_hasLoadedRecommendations ||
        currentState is RestaurantInitial ||
        currentState is RestaurantError ||
        (currentState is RestaurantsLoaded &&
            currentState.restaurants.isEmpty)) {
      log('Loading restaurant recommendations');
      bloc.add(const LoadDailyRecommendationsEvent(count: 3));
      _hasLoadedRecommendations = true;
    } else {
      log('Skipping restaurant recommendations load, already have data');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return BlocBuilder<RestaurantBloc, RestaurantState>(
      builder: (context, state) {
        log('Restaurant state: $state');

        // If we're in detail state, we should show recommendations
        // from the previous state if available
        if (state is RestaurantDetailLoaded) {
          final previousState = state.previousState;
          if (previousState is RestaurantsLoaded) {
            log('Using restaurants from previous state');
            return _buildRestaurantList(context, previousState.restaurants);
          }

          // If no previous state with restaurants, try to load them
          if (!_hasLoadedRecommendations) {
            log('In detail state, loading recommendations');
            context
                .read<RestaurantBloc>()
                .add(const LoadDailyRecommendationsEvent(count: 3));
            _hasLoadedRecommendations = true;
          }
        }

        if (state is RestaurantLoading && !_hasLoadedRecommendations) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is RestaurantError) {
          log('Restaurant error: ${state.message}');
          return SizedBox(
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load recommendations',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _hasLoadedRecommendations = false;
                      _loadRecommendations();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is RestaurantsLoaded && state.restaurants.isNotEmpty) {
          log('Loaded ${state.restaurants.length} restaurants');
          return _buildRestaurantList(context, state.restaurants);
        }

        if (state is RestaurantsLoaded && state.restaurants.isEmpty) {
          log('No restaurants found');
          return SizedBox(
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No restaurant recommendations available',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _hasLoadedRecommendations = false;
                      _loadRecommendations();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Default case - show loading
        return const SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantList(
      BuildContext context, List<Restaurant> restaurants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recommended Places',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestaurantListScreen(),
                    ),
                  );
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              return RestaurantRecommendationCard(restaurant: restaurant);
            },
          ),
        ),
      ],
    );
  }
}

class RestaurantRecommendationCard extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantRecommendationCard({
    Key? key,
    required this.restaurant,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailScreen(
              restaurantId: restaurant.id.toString(),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 160,
        child: TransparentCard(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.all(12), // Using the new padding parameter
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SafeNetworkImage(
                  imageUrl: restaurant.imageUrl,
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    height: 80,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                restaurant.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13, // Smaller font size
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    restaurant.rating.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12, // Smaller font size
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                restaurant.cuisineType,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11, // Smaller font size
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  void _loadRestaurants() {
    final bloc = context.read<RestaurantBloc>();
    final currentState = bloc.state;

    // Only load if we don't have restaurants or if we're in detail state
    if (currentState is! RestaurantsLoaded ||
        currentState.restaurants.isEmpty ||
        currentState is RestaurantDetailLoaded) {
      log('Loading all restaurants');
      bloc.add(LoadRestaurantsEvent());
    } else {
      log('Using existing restaurants from state');
    }
  }

  Future<void> _launchMaps(String address) async {
    final url = Uri.parse('https://maps.google.com/?q=$address');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      log('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants', style: TextStyle(color: Colors.white)),
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
        child: BlocBuilder<RestaurantBloc, RestaurantState>(
          builder: (context, state) {
            // If in detail state, try to use previous state
            if (state is RestaurantDetailLoaded) {
              final previousState = state.previousState;
              if (previousState is RestaurantsLoaded) {
                log('Using restaurants from previous state in list screen');
                return _buildRestaurantList(previousState.restaurants);
              }
              // If no previous state, trigger a load
              _loadRestaurants();
            }

            if (state is RestaurantLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is RestaurantError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${state.message}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadRestaurants,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is RestaurantsLoaded) {
              if (state.restaurants.isEmpty) {
                return const Center(
                  child: Text(
                    'No restaurants found',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return _buildRestaurantList(state.restaurants);
            }

            return const Center(child: Text('No restaurants found'));
          },
        ),
      ),
    );
  }

  Widget _buildRestaurantList(List<Restaurant> restaurants) {
    return ListView.builder(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        final restaurant = restaurants[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantDetailScreen(
                  restaurantId: restaurant.id.toString(),
                ),
              ),
            );
          },
          child: TransparentCard(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: SafeNetworkImage(
                    imageUrl: restaurant.imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade800,
                      child:
                          const Icon(Icons.restaurant, color: Colors.white54),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                restaurant.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  restaurant.rating.toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restaurant.cuisineType,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restaurant.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _launchMaps(restaurant.address),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  restaurant.address,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
