import 'package:equatable/equatable.dart';
import '../../data/models/restaurant.dart';

abstract class RestaurantState extends Equatable {
  const RestaurantState();

  @override
  List<Object?> get props => [];
}

class RestaurantInitial extends RestaurantState {}

class RestaurantLoading extends RestaurantState {}

class RestaurantsLoaded extends RestaurantState {
  final List<Restaurant> restaurants;

  const RestaurantsLoaded(this.restaurants);

  @override
  List<Object?> get props => [restaurants];
}

class RestaurantDetailLoaded extends RestaurantState {
  final Restaurant restaurant;
  final RestaurantState? previousState;

  const RestaurantDetailLoaded(this.restaurant, {this.previousState});

  @override
  List<Object?> get props => [restaurant, previousState];
}

class RestaurantError extends RestaurantState {
  final String message;

  const RestaurantError(this.message);

  @override
  List<Object?> get props => [message];
}
