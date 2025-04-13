import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_response.dart';
import '../transaction/transaction_bloc.dart';
import '../transaction/transaction_event.dart';
import '../calorie/calorie_bloc.dart';
import '../calorie/calorie_event.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../auth/auth_bloc.dart';
import 'dart:async'; // Add this import for TimeoutException

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository chatRepository;
  final RestaurantRepository restaurantRepository;
  final TransactionBloc transactionBloc;
  final CalorieBloc calorieBloc;
  final AuthBloc authBloc;

  ChatBloc({
    required this.chatRepository,
    required this.restaurantRepository,
    required this.transactionBloc,
    required this.calorieBloc,
    required this.authBloc,
  }) : super(ChatInitial()) {
    on<LoadChatHistory>(_onLoadChatHistory);
    on<SendMessage>(_onSendMessage);
    on<ReceiveMessage>(_onReceiveMessage);
    on<ClearChatHistory>(_onClearChatHistory);
  }

  Future<void> _onLoadChatHistory(
      LoadChatHistory event, Emitter<ChatState> emit) async {
    try {
      final authState = authBloc.state;
      final userId = authState is AuthAuthenticated ? authState.user.uid : null;

      final messages = await chatRepository.getMessages(userId: userId);
      print('Initial messages count: ${messages.length}'); // Debug print
      if (messages.isNotEmpty) {
        print(
            'First message content: ${messages.first.content}'); // Debug print
      }

      // If there are no previous messages, add a welcome message from Plexi
      if (messages.isEmpty) {
        print(
            'Adding welcome message because messages list is empty'); // Debug print
        final welcomeMessage = ChatMessage(
          id: 'welcome',
          content:
              "Hi, I'm Plexi and I will be your virtual assistant. You can chat with me or tell me how much you spent today or what food you ate.",
          isUser: false,
          timestamp: DateTime.now(),
          userId: userId,
        );

        // Add welcome message to the list and save it to the repository
        messages.add(welcomeMessage);
        await chatRepository.addMessage(welcomeMessage);
        print(
            'Welcome message added, new messages count: ${messages.length}'); // Debug print
      }

      emit(ChatMessageState(
        messages: messages,
        isAssistantTyping: false,
      ));
    } catch (e) {
      print('Error loading chat history: $e'); // Debug print
      emit(ChatError('Failed to load chat history'));
    }
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<ChatState> emit) async {
    try {
      final authState = authBloc.state;
      final userId = authState is AuthAuthenticated ? authState.user.uid : null;

      final currentMessages = state is ChatMessageState
          ? List<ChatMessage>.from((state as ChatMessageState).messages)
          : <ChatMessage>[];

      // Add the user message
      final newMessage = ChatMessage(
        id: DateTime.now().toString(),
        content: event.message,
        isUser: true,
        timestamp: DateTime.now(),
        userId: userId,
      );
      currentMessages.add(newMessage);
      await chatRepository.addMessage(newMessage);

      // Emit the state indicating the assistant is typing
      emit(ChatMessageState(
        messages: currentMessages,
        isAssistantTyping: true,
      ));

      // Set a timeout for the API request
      final localTimestamp = DateTime.now().toLocal();
      ChatResponse response;

      try {
        response = await chatRepository
            .sendMessage(
          event.message,
          event.conversationHistory,
          timestamp: localTimestamp.toIso8601String(),
          userId: userId,
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Request timed out after 30 seconds');
          },
        );
      } catch (e) {
        final errorMessage = ChatMessage(
          id: DateTime.now().toString(),
          content:
              "Sorry, I couldn't process your request. Please try again later.",
          isUser: false,
          timestamp: DateTime.now(),
          userId: userId,
        );
        currentMessages.add(errorMessage);
        await chatRepository.addMessage(errorMessage);

        emit(ChatMessageState(
          messages: currentMessages,
          isAssistantTyping: false,
          error: e is TimeoutException
              ? "Request timed out. Please try again later."
              : "An error occurred. Please try again.",
        ));
        return;
      }

      // Add the assistant's response as a message
      final assistantMessage = ChatMessage(
        id: DateTime.now().toString(),
        content: _processResponseContent(response),
        isUser: false,
        timestamp: DateTime.now(),
        userId: userId,
        toolUsed: response.conversationContext,
        toolResponse: {
          'expense_info': response.expenseInfo,
          'calorie_info': response.calorieInfo,
          'original_response': response
              .response, // Store the original response for food extraction
        },
      );

      if (assistantMessage.toolResponse != null &&
          assistantMessage.toolResponse!['calorie_info'] != null) {}

      currentMessages.add(assistantMessage);
      await chatRepository.addMessage(assistantMessage);

      // Emit the updated state with messages
      emit(ChatMessageState(
        messages: currentMessages,
        isAssistantTyping: false,
        responseData: response.toJson(),
      ));

      // Process expense info if present
      if (response.expenseInfo != null) {
        final expenseInfo = response.expenseInfo!;
        if (!event.message.toLowerCase().contains('week') &&
            !event.message.toLowerCase().contains('month')) {
          final transactions = <Map<String, dynamic>>[];
          if (expenseInfo['categories'] != null) {
            final categories =
                expenseInfo['categories'] as Map<String, dynamic>;
            categories.forEach((category, amount) {
              // Handle both formats: direct numeric values or maps with 'amount' key
              num amountValue;
              if (amount is Map<String, dynamic> &&
                  amount.containsKey('amount')) {
                amountValue = amount['amount'] as num;
              } else {
                // Direct numeric value
                amountValue = amount as num;
              }

              transactions.add({
                'amount': amountValue,
                'category': category,
                'description': 'Transaction from summary',
                'timestamp': localTimestamp.toIso8601String(),
              });
            });
          }

          // Safely extract total amount
          num totalAmount = 0;
          if (expenseInfo.containsKey('total_amount')) {
            totalAmount = expenseInfo['total_amount'] as num? ?? 0;
          } else if (expenseInfo.containsKey('total')) {
            totalAmount = expenseInfo['total'] as num? ?? 0;
          }

          transactionBloc.add(UpdateTransactionsFromChat(
            transactions: transactions,
            totalAmount: totalAmount,
            isQuery: expenseInfo['is_query_response'] == true,
          ));
        }
      }

      // Process calorie info if present
      if (response.calorieInfo != null) {
        final calorieInfo = response.calorieInfo!;

        // Check if this is a query response rather than a food entry
        if (calorieInfo['is_query_response'] == true) {
          // Handle query response without updating calories

          // Extract the actual calorie data from the server response
          final totalCalories = calorieInfo['total_calories'] is int
              ? calorieInfo['total_calories']
              : int.tryParse(calorieInfo['total_calories'].toString()) ?? 0;

          // Convert items to breakdown list if available
          List<dynamic>? breakdownList;
          if (calorieInfo['items'] != null) {
            if (calorieInfo['items'] is Map<String, dynamic>) {
              final Map<String, dynamic> itemsMap =
                  calorieInfo['items'] as Map<String, dynamic>;
              breakdownList = itemsMap.entries
                  .map((e) => {'item': e.key, 'calories': e.value})
                  .toList();
            } else if (calorieInfo['items'] is List) {
              breakdownList = calorieInfo['items'] as List<dynamic>;
            }
          }

          calorieBloc.add(
            UpdateCaloriesFromChat(
              totalCalories: totalCalories,
              breakdown: breakdownList,
            ),
          );

          emit(ChatMessageState(
            messages: currentMessages,
            isAssistantTyping: false,
            responseData: response.toJson(),
          ));
          return;
        }

        if (calorieInfo['actions_logged'] > 0 &&
            calorieInfo['total_calories'] != null) {
          // Check if multiple actions were logged
          final actionsLogged = calorieInfo['actions_logged'] as int? ?? 1;

          if (actionsLogged > 1) {
            // Multiple food items in one message

            // Extract total calories
            final totalCalories = calorieInfo['total_calories'] is int
                ? calorieInfo['total_calories']
                : int.tryParse(calorieInfo['total_calories'].toString()) ?? 0;

            // Create a combined food item entry
            String foodItem = "Combined meal";

            // Try to extract individual food items from the response
            final foodItemRegex = RegExp(
                r'for (?:(?:\d+\.?\d*)|one|a|an) ([a-zA-Z ]+?)(?:,|\.|$)');
            final matches = foodItemRegex.allMatches(response.response);

            if (matches.isNotEmpty) {
              final foodItems = matches
                  .map((m) => m.group(1)?.trim())
                  .whereType<String>()
                  .toList();
              if (foodItems.isNotEmpty) {
                foodItem = foodItems.join(", ");
              }
            }

            // Convert breakdown to a list if it's a map
            List<dynamic>? breakdownList;
            if (calorieInfo['items'] != null) {
              if (calorieInfo['items'] is Map<String, dynamic>) {
                final Map<String, dynamic> itemsMap =
                    calorieInfo['items'] as Map<String, dynamic>;
                breakdownList = itemsMap.entries
                    .map((e) => {'item': e.key, 'calories': e.value})
                    .toList();
              } else if (calorieInfo['items'] is List) {
                breakdownList = calorieInfo['items'] as List<dynamic>;
              }
            }

            calorieBloc.add(
              UpdateCaloriesFromChat(
                totalCalories: totalCalories,
                foodInfo: {
                  'food_item': foodItem,
                  'calories': totalCalories.toString(),
                  'quantity': '1',
                  'timestamp': localTimestamp.toIso8601String(),
                },
                breakdown: breakdownList,
              ),
            );
          } else {
            // Single food item - use existing code
            // Extract food item and calories from response if possible
            // Try multiple regex patterns to handle different response formats
            String? calories;
            String? quantity;
            String? foodItem;

            // Pattern 1: Standard format with "for" or "from" followed by quantity and food
            final pattern1 = RegExp(
                r'(\d+) calories[^:]*(?:for|from) (?:(\d+\.?\d*)|one|a|an) (.+?)(?:\.|\s*$)');
            final match1 = pattern1.firstMatch(response.response);
            if (match1 != null) {
              calories = match1.group(1);
              quantity = match1.group(2) ??
                  '1'; // Default to 1 if using words like "one", "a"
              foodItem = match1.group(3);
            }

            // Pattern 2: Format with food item mentioned first
            if (calories == null) {
              final pattern2 = RegExp(
                  r'(?:a|an|one|(\d+\.?\d*)) (.+?) (?:has|contains|is) (\d+) calories');
              final match2 = pattern2.firstMatch(response.response);
              if (match2 != null) {
                calories = match2.group(3);
                quantity = match2.group(1) ?? '1';
                foodItem = match2.group(2);
              }
            }

            // Pattern 3: Simple format with just "calories" and "for" somewhere
            if (calories == null) {
              final calorieMatch =
                  RegExp(r'(\d+) calories').firstMatch(response.response);
              final foodItemMatch =
                  RegExp(r'for (?:a |an |one |some )?([a-zA-Z ]+)')
                      .firstMatch(response.response);

              if (calorieMatch != null && foodItemMatch != null) {
                calories = calorieMatch.group(1);
                quantity = '1'; // default quantity
                foodItem = foodItemMatch.group(1);
              }
            }

            if (calories != null && foodItem != null) {
              // Parse the extracted values
              final caloriesInt = int.parse(calories);
              final quantityDouble = double.tryParse(quantity ?? '1') ?? 1.0;
              final foodItemStr = foodItem.trim();

              // Convert breakdown to a list if it's a map
              List<dynamic>? breakdownList;
              if (calorieInfo['items'] != null) {
                if (calorieInfo['items'] is Map<String, dynamic>) {
                  final Map<String, dynamic> itemsMap =
                      calorieInfo['items'] as Map<String, dynamic>;
                  breakdownList = itemsMap.entries
                      .map((e) => {'item': e.key, 'calories': e.value})
                      .toList();
                } else if (calorieInfo['items'] is List) {
                  breakdownList = calorieInfo['items'] as List<dynamic>;
                }
              }

              calorieBloc.add(
                UpdateCaloriesFromChat(
                  totalCalories: calorieInfo['total_calories'] is int
                      ? calorieInfo['total_calories']
                      : int.tryParse(
                              calorieInfo['total_calories'].toString()) ??
                          0,
                  foodInfo: {
                    'food_item': foodItemStr,
                    'calories': caloriesInt.toString(),
                    'quantity': quantityDouble.toString(),
                    'timestamp': localTimestamp.toIso8601String(),
                  },
                  breakdown: breakdownList,
                ),
              );
            } else {
              // Fallback when regex doesn't match but we still have calorie info

              // Extract total calories from the calorie info
              final totalCalories = calorieInfo['total_calories'] is int
                  ? calorieInfo['total_calories']
                  : int.tryParse(calorieInfo['total_calories'].toString()) ?? 0;

              // Try to extract food name from response using a simpler approach
              String foodItem = 'food';

              // Look for any food-related words in the response
              final foodWords = [
                'banana',
                'apple',
                'chocolate',
                'pizza',
                'burger',
                'salad',
                'sandwich',
                'egg',
                'chicken',
                'beef',
                'pork',
                'fish',
                'rice',
                'pasta',
                'bread',
                'cereal',
                'yogurt',
                'cheese',
                'milk',
                'fruit',
                'vegetable',
                'snack',
                'meal',
                'breakfast',
                'lunch',
                'dinner'
              ];

              for (final word in foodWords) {
                if (response.response.toLowerCase().contains(word)) {
                  foodItem = word;
                  break;
                }
              }

              // Convert breakdown to a list if it's a map
              List<dynamic>? breakdownList;
              if (calorieInfo['items'] != null) {
                if (calorieInfo['items'] is Map<String, dynamic>) {
                  final Map<String, dynamic> itemsMap =
                      calorieInfo['items'] as Map<String, dynamic>;
                  breakdownList = itemsMap.entries
                      .map((e) => {'item': e.key, 'calories': e.value})
                      .toList();
                } else if (calorieInfo['items'] is List) {
                  breakdownList = calorieInfo['items'] as List<dynamic>;
                }
              }

              calorieBloc.add(
                UpdateCaloriesFromChat(
                  totalCalories: totalCalories,
                  foodInfo: {
                    'food_item': foodItem,
                    'calories': totalCalories.toString(),
                    'quantity': '1',
                    'timestamp': localTimestamp.toIso8601String(),
                  },
                  breakdown: breakdownList,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      emit(ChatError('Failed to process message'));
    }
  }

  String _processResponseContent(ChatResponse response) {
    // Check if this is a calorie-related response
    if (response.calorieInfo != null) {
      // Check if this is a calorie logging action (adding a food item)
      bool isLoggingAction = false;

      // Check for actions_logged to identify logging actions
      if (response.calorieInfo!['actions_logged'] != null &&
          response.calorieInfo!['actions_logged'] is int &&
          response.calorieInfo!['actions_logged'] > 0) {
        isLoggingAction = true;
      }

      // Also check for specific text patterns that indicate calorie logging
      if (response.response.startsWith("Logged:") ||
          (response.response.contains("calories") &&
              response.response.contains("for ") &&
              (response.response.contains("carbs") ||
                  response.response.contains("protein") ||
                  response.response.contains("fat")))) {
        isLoggingAction = true;
      }

      // For logging actions, return empty string to only show the blue box
      // ONLY if there's no expense info (to handle multiple intents)
      if (isLoggingAction && response.expenseInfo == null) {
        return "";
      }

      // For nutrition queries (not logging), keep the response text
      // This allows users to see responses to questions like "How many calories did I eat today?"
    }

    // For all other responses, return the original content
    return response.response;
  }

  void _onReceiveMessage(ReceiveMessage event, Emitter<ChatState> emit) {
    final currentMessages = state is ChatMessageState
        ? List<ChatMessage>.from((state as ChatMessageState).messages)
        : <ChatMessage>[];

    final newMessage = ChatMessage(
      id: DateTime.now().toString(),
      content: event.message,
      isUser: false,
      timestamp: DateTime.now(),
    );

    emit(ChatMessageState(
      messages: [...currentMessages, newMessage],
      restaurants: event.restaurants,
    ));
  }

  Future<void> _onClearChatHistory(
      ClearChatHistory event, Emitter<ChatState> emit) async {
    try {
      final authState = authBloc.state;
      final userId = authState is AuthAuthenticated ? authState.user.uid : null;

      await chatRepository.clearMessages(userId: userId);
      emit(ChatMessageState(
        messages: [],
        isAssistantTyping: false,
      ));
    } catch (e) {
      emit(ChatError('Failed to clear chat history'));
    }
  }
}
