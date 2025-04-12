import 'package:equatable/equatable.dart';
import 'restaurant.dart';

class ChatResponse extends Equatable {
  final String response;
  final bool success;
  final String? conversationContext;
  final List<Restaurant>? restaurantSuggestions;
  final Map<String, dynamic>? expenseInfo;
  final Map<String, dynamic>? calorieInfo;

  const ChatResponse({
    required this.response,
    required this.success,
    this.conversationContext,
    this.restaurantSuggestions,
    this.expenseInfo,
    this.calorieInfo,
  });

  @override
  List<Object?> get props => [
        response,
        success,
        conversationContext,
        restaurantSuggestions,
        expenseInfo,
        calorieInfo,
      ];

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'] as String,
      success: json['success'] as bool,
      conversationContext: json['conversation_context'] as String?,
      restaurantSuggestions: json['restaurant_suggestions'] != null
          ? (json['restaurant_suggestions'] as List)
              .map((r) => Restaurant.fromJson(r as Map<String, dynamic>))
              .toList()
          : null,
      expenseInfo: json['expense_info'] as Map<String, dynamic>?,
      calorieInfo: json['calorie_info'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'success': success,
      'conversation_context': conversationContext,
      'restaurant_suggestions':
          restaurantSuggestions?.map((e) => e.toJson()).toList(),
      'expense_info': expenseInfo,
      'calorie_info': calorieInfo,
    };
  }
}
