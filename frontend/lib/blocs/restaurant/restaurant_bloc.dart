import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/restaurant.dart';
import 'restaurant_event.dart';
import 'restaurant_state.dart';

class RestaurantBloc extends Bloc<RestaurantEvent, RestaurantState> {
  final RestaurantRepository restaurantRepository;

  // Keep track of loaded restaurants to avoid losing them during navigation
  List<Restaurant> _loadedRestaurants = [];

  RestaurantBloc({required this.restaurantRepository})
      : super(RestaurantInitial()) {
    on<LoadRestaurantsEvent>(_onLoadRestaurants);
    on<LoadDailyRecommendationsEvent>(_onLoadDailyRecommendations);
    on<SearchRestaurantsEvent>(_onSearchRestaurants);
    on<LoadRestaurantsByCuisineEvent>(_onLoadRestaurantsByCuisine);
    on<LoadRestaurantDetailsEvent>(_onLoadRestaurantDetails);
  }

  @override
  void onChange(Change<RestaurantState> change) {
    super.onChange(change);
    log('RestaurantBloc: State changing from ${change.currentState.runtimeType} to ${change.nextState.runtimeType}');
    log('Cache status: ${_loadedRestaurants.length} restaurants in cache');
    if (change.nextState is RestaurantLoading) {
      log('WARNING: Emitting loading state. Current cache size: ${_loadedRestaurants.length}');
    }
    if (change.nextState is RestaurantsLoaded) {
      final loaded = change.nextState as RestaurantsLoaded;
      log('Emitting RestaurantsLoaded with ${loaded.restaurants.length} restaurants');
    }
    if (change.nextState is RestaurantDetailLoaded) {
      final detail = change.nextState as RestaurantDetailLoaded;
      log('Emitting RestaurantDetailLoaded for ${detail.restaurant.name}');
      log('Previous state type: ${detail.previousState?.runtimeType}');
    }
  }

  Future<void> _onLoadRestaurants(
    LoadRestaurantsEvent event,
    Emitter<RestaurantState> emit,
  ) async {
    try {
      // Only emit loading if we don't have restaurants already
      if (_loadedRestaurants.isEmpty) {
        emit(RestaurantLoading());
      }

      final restaurants = await restaurantRepository.getRestaurants();
      _loadedRestaurants = restaurants;
      emit(RestaurantsLoaded(restaurants));
    } catch (e) {
      log('Error loading restaurants: $e');
      // If we have cached restaurants, use them instead of showing error
      if (_loadedRestaurants.isNotEmpty) {
        emit(RestaurantsLoaded(_loadedRestaurants));
      } else {
        emit(RestaurantError(e.toString()));
      }
    }
  }

  Future<void> _onLoadDailyRecommendations(
    LoadDailyRecommendationsEvent event,
    Emitter<RestaurantState> emit,
  ) async {
    try {
      log('_onLoadDailyRecommendations: Starting to load ${event.count} recommendations');
      log('Current state type: ${state.runtimeType}');
      log('Current cache size: ${_loadedRestaurants.length}');

      // Check if we're already in a loaded state with the same count
      final currentState = state;
      if (currentState is RestaurantsLoaded &&
          currentState.restaurants.isNotEmpty &&
          currentState.restaurants.length == event.count) {
        log('Already have ${event.count} restaurants loaded, skipping fetch');
        return;
      }

      // Only emit loading if we don't have any restaurants
      if (_loadedRestaurants.isEmpty) {
        log('Emitting loading state (empty cache)');
        emit(RestaurantLoading());
      } else {
        log('Using existing cache of ${_loadedRestaurants.length} restaurants');
      }

      final restaurants = await restaurantRepository.getDailyRecommendations(
          count: event.count);
      log('Loaded ${restaurants.length} recommendations from API');

      // Store the loaded restaurants
      _loadedRestaurants = restaurants;
      log('Updated cache with ${_loadedRestaurants.length} restaurants');

      emit(RestaurantsLoaded(restaurants));
    } catch (e) {
      log('Error loading daily recommendations: $e');
      // If we have cached restaurants, use them as fallback
      if (_loadedRestaurants.isNotEmpty) {
        final recommendations = _loadedRestaurants.take(event.count).toList();
        log('Using ${recommendations.length} cached restaurants as fallback');
        emit(RestaurantsLoaded(recommendations));
      } else {
        log('No cache available, emitting error');
        emit(RestaurantError(e.toString()));
      }
    }
  }

  Future<void> _onSearchRestaurants(
    SearchRestaurantsEvent event,
    Emitter<RestaurantState> emit,
  ) async {
    try {
      // Keep the current state while searching
      final currentState = state;
      if (!(currentState is RestaurantDetailLoaded)) {
        emit(RestaurantLoading());
      }

      final restaurants =
          await restaurantRepository.searchRestaurants(event.query);
      emit(RestaurantsLoaded(restaurants));
    } catch (e) {
      log('Error searching restaurants: $e');
      // If we have cached restaurants, show them instead of error
      if (_loadedRestaurants.isNotEmpty) {
        emit(RestaurantsLoaded(_loadedRestaurants));
      } else {
        emit(RestaurantError(e.toString()));
      }
    }
  }

  Future<void> _onLoadRestaurantsByCuisine(
    LoadRestaurantsByCuisineEvent event,
    Emitter<RestaurantState> emit,
  ) async {
    try {
      // Keep the current state while loading
      final currentState = state;
      if (!(currentState is RestaurantDetailLoaded)) {
        emit(RestaurantLoading());
      }

      final restaurants =
          await restaurantRepository.getRestaurantsByCuisine(event.cuisineType);
      emit(RestaurantsLoaded(restaurants));
    } catch (e) {
      log('Error loading restaurants by cuisine: $e');
      // If we have cached restaurants, show them instead of error
      if (_loadedRestaurants.isNotEmpty) {
        emit(RestaurantsLoaded(_loadedRestaurants));
      } else {
        emit(RestaurantError(e.toString()));
      }
    }
  }

  Future<void> _onLoadRestaurantDetails(
    LoadRestaurantDetailsEvent event,
    Emitter<RestaurantState> emit,
  ) async {
    try {
      log('_onLoadRestaurantDetails: Starting to load details for restaurant ${event.restaurantId}');
      log('Current state type: ${state.runtimeType}');
      log('Current cache size: ${_loadedRestaurants.length}');

      // Save the current state before any transitions
      final currentState = state;

      // If we're already in a detail state for this restaurant, don't reload
      if (currentState is RestaurantDetailLoaded &&
          currentState.restaurant.id.toString() == event.restaurantId &&
          currentState.previousState != null) {
        log('Already showing details for this restaurant, no need to reload');
        return;
      }

      // Try to find the restaurant in the current state first
      Restaurant? targetRestaurant;
      if (currentState is RestaurantsLoaded) {
        try {
          targetRestaurant = currentState.restaurants.firstWhere(
            (r) => r.id.toString() == event.restaurantId,
          );
          log('Found restaurant in current state: ${targetRestaurant.name}');
        } catch (_) {
          log('Restaurant not found in current state');
        }
      }

      // If not in current state, try the cache
      if (targetRestaurant == null && _loadedRestaurants.isNotEmpty) {
        try {
          targetRestaurant = _loadedRestaurants.firstWhere(
            (r) => r.id.toString() == event.restaurantId,
          );
          log('Found restaurant in cache: ${targetRestaurant.name}');
        } catch (_) {
          log('Restaurant not found in cache');
        }
      }

      // If we found the restaurant, emit it with the proper previous state
      if (targetRestaurant != null) {
        log('Using found restaurant: ${targetRestaurant.name}');
        final previousState = currentState is RestaurantsLoaded
            ? currentState
            : (currentState is RestaurantDetailLoaded &&
                    currentState.previousState != null)
                ? currentState.previousState!
                : RestaurantsLoaded(_loadedRestaurants);

        log('Previous state type: ${previousState.runtimeType}');
        emit(RestaurantDetailLoaded(
          targetRestaurant,
          previousState: previousState,
        ));
        return;
      }

      // If we get here, we need to load from the API
      log('Loading restaurant details from API');
      emit(RestaurantLoading());

      final restaurant =
          await restaurantRepository.getRestaurantDetails(event.restaurantId);
      log('Loaded restaurant details from API: ${restaurant.name}');

      // Update or add to cache
      final index = _loadedRestaurants
          .indexWhere((r) => r.id.toString() == event.restaurantId);
      if (index != -1) {
        log('Updating restaurant in cache at index $index');
        _loadedRestaurants[index] = restaurant;
      } else {
        log('Adding new restaurant to cache');
        _loadedRestaurants.add(restaurant);
      }

      // Determine the previous state to preserve
      final previousState = currentState is RestaurantsLoaded
          ? currentState
          : (currentState is RestaurantDetailLoaded &&
                  currentState.previousState != null)
              ? currentState.previousState!
              : RestaurantsLoaded(_loadedRestaurants);

      log('Emitting detail state with previous state type: ${previousState.runtimeType}');
      emit(RestaurantDetailLoaded(
        restaurant,
        previousState: previousState,
      ));
    } catch (e) {
      log('Error loading restaurant details: $e');

      // Try to restore the previous state
      if (state is RestaurantDetailLoaded) {
        final detailState = state as RestaurantDetailLoaded;
        if (detailState.previousState != null) {
          log('Restoring previous state: ${detailState.previousState.runtimeType}');
          emit(detailState.previousState!);
          return;
        }
      }

      // If we can't restore the previous state, show the cache
      if (_loadedRestaurants.isNotEmpty) {
        log('Falling back to cached restaurants list');
        emit(RestaurantsLoaded(_loadedRestaurants));
      } else {
        log('No fallback available, showing error');
        emit(RestaurantError(e.toString()));
      }
    }
  }
}
