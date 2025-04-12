import 'package:equatable/equatable.dart';

abstract class RestaurantEvent extends Equatable {
  const RestaurantEvent();

  @override
  List<Object?> get props => [];
}

class LoadRestaurantsEvent extends RestaurantEvent {}

class LoadDailyRecommendationsEvent extends RestaurantEvent {
  final int count;

  const LoadDailyRecommendationsEvent({this.count = 3});

  @override
  List<Object?> get props => [count];
}

class SearchRestaurantsEvent extends RestaurantEvent {
  final String query;

  const SearchRestaurantsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class LoadRestaurantsByCuisineEvent extends RestaurantEvent {
  final String cuisineType;

  const LoadRestaurantsByCuisineEvent(this.cuisineType);

  @override
  List<Object?> get props => [cuisineType];
}

class LoadRestaurantDetailsEvent extends RestaurantEvent {
  final String restaurantId;

  const LoadRestaurantDetailsEvent(this.restaurantId);

  @override
  List<Object?> get props => [restaurantId];
}
