// windsurf.dart
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import '../../../data/models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLastMessage;
  final bool isTyping;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isLastMessage = false,
    this.isTyping = false,
  });

  String _formatMessage(String text) {
    // Decode HTML entities (e.g., &amp;, &#39;) to get proper Unicode characters
    final unescape = HtmlUnescape();
    text = unescape.convert(text);

    // Replace common problematic symbols
    text = text.replaceAll('â€¢', '•'); // Replace corrupted bullet points
    text = text.replaceAll('â', ''); // Remove problematic 'â' character
    text = text.replaceAll('€™', "'"); // Fix apostrophe
    text = text.replaceAll('€œ', '"'); // Fix opening quote
    text = text.replaceAll('€', '"'); // Fix closing quote

    // IMPORTANT: Removed the line below to preserve valid emojis
    // text = text.replaceAll(RegExp(r'ðŸ[\w\d]{1,3}'), '');

    // Add extra line breaks for bullet points for better readability
    text = text.replaceAll('\n● ', '\n\n● ');

    // If this is a calorie-related message, filter out duplicate calorie info
    if ((message.toolUsed == 'calories' ||
            message.toolUsed == 'multiple_actions') &&
        message.toolResponse != null &&
        message.toolResponse!['calorie_info'] != null) {
      text = _removeCalorieSummary(text);
    }

    return text;
  }

  // Helper method to remove calorie summary information from the text
  String _removeCalorieSummary(String text) {
    // Common patterns for calorie summaries in the text
    final patterns = [
      // Pattern for "Today's nutrition summary:" or "This week's nutrition summary:"
      // Updated to handle both straight and curly apostrophes
      RegExp(
          r"(Today(?:'s|'s)|This week(?:'s|'s)) nutrition summary:[\s\S]*?(Food breakdown:[\s\S]*?(?=\n\n|\Z)|\Z)",
          caseSensitive: false),

      // Pattern for "Calorie Summary" sections
      RegExp(
          r"Calorie Summary:?[\s\S]*?(Food breakdown:[\s\S]*?(?=\n\n|\Z)|\Z)",
          caseSensitive: false),

      // Pattern for "I've logged X calories" followed by breakdown
      RegExp(
          r"I've logged \d+ calories[\s\S]*?(Food breakdown:[\s\S]*?(?=\n\n|\Z)|\Z)",
          caseSensitive: false),

      // Pattern for "Total: X calories" with macros
      RegExp(
          r"Total: \d+ calories[\s\S]*?(Food breakdown:[\s\S]*?(?=\n\n|\Z)|\Z)",
          caseSensitive: false),

      // Pattern for bullet points of macronutrients
      RegExp(r"[•●] (Total|Carbs|Protein|Fat):.*?(\n|$)", caseSensitive: false),

      // Pattern for food items in breakdown
      RegExp(r"[•●] \d+ cal from .*?(\n|$)", caseSensitive: false),
    ];

    // Apply all patterns to remove calorie information
    for (final pattern in patterns) {
      text = text.replaceAll(pattern, '');
    }

    // Clean up any excessive newlines that might be left
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();

    // If we've removed everything, provide a simple acknowledgment
    if (text.isEmpty) {
      return "I've logged your calories! See the summary below.";
    }

    return text;
  }

  // Helper method to calculate percentage of calories
  int _calculatePercentage(num partialCalories, int totalCalories) {
    if (totalCalories == 0) return 0;
    return ((partialCalories / totalCalories) * 100).round();
  }

  // Helper method to build a food breakdown item
  Widget _buildFoodBreakdownItem(String name, int calories,
      {double? carbs, double? protein, double? fat}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '● $calories cal from $name${_formatMacros(carbs, protein, fat)}',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // Helper method to format macronutrients for food items
  String _formatMacros(double? carbs, double? protein, double? fat) {
    if (carbs == null && protein == null && fat == null) return '';

    final parts = <String>[];
    if (carbs != null) parts.add('${carbs}g carbs');
    if (protein != null) parts.add('${protein}g protein');
    if (fat != null) parts.add('${fat}g fat');

    return parts.isEmpty ? '' : ' (${parts.join(', ')})';
  }

  // Helper method to format calorie information
  Widget _buildCalorieInfo() {
    if (message.toolUsed != 'calories' &&
            message.toolUsed != 'multiple_actions' ||
        message.toolResponse == null ||
        message.toolResponse!['calorie_info'] == null) {
      return const SizedBox.shrink();
    }

    final calorieInfo = message.toolResponse!['calorie_info'];
    final isQueryResponse = calorieInfo['is_query_response'] == true;

    // Handle items field which could be either a Map or a List
    Map<String, dynamic>? itemsMap;
    List<dynamic>? itemsList;

    if (calorieInfo['items'] is Map<String, dynamic>) {
      itemsMap = calorieInfo['items'] as Map<String, dynamic>;
    } else if (calorieInfo['items'] is List<dynamic>) {
      itemsList = calorieInfo['items'] as List<dynamic>;
    }

    final breakdown = calorieInfo['breakdown'] as List<dynamic>?;
    final totalCalories = calorieInfo['total_calories'] as int? ?? 0;

    // If no calorie data, don't show anything
    if (totalCalories == 0 &&
        (itemsMap == null || itemsMap.isEmpty) &&
        (itemsList == null || itemsList.isEmpty) &&
        (breakdown == null || breakdown.isEmpty)) {
      return const SizedBox.shrink();
    }

    // Determine if this is a food logging action (single item) or a query (multiple items/summary)
    bool isLoggingAction = false;

    // Check if this is a logging action based on actions_logged field
    if (calorieInfo['actions_logged'] != null &&
        calorieInfo['actions_logged'] is int &&
        calorieInfo['actions_logged'] > 0) {
      isLoggingAction = true;
    }

    // Also check based on items or breakdown
    if (!isQueryResponse &&
        ((itemsMap != null && itemsMap.length == 1) ||
            (breakdown != null && breakdown.length == 1))) {
      isLoggingAction = true;
    }

    // Check if this is a daily summary (not a weekly summary and not a logging action)
    final bool isDailySummary = !isQueryResponse && !isLoggingAction;

    // Get the food item name if this is a logging action
    String? foodItemName;
    int quantity = 1; // Changed from int? to int since we always default to 1
    if (isLoggingAction) {
      // Try to get food item from items map
      if (itemsMap != null && itemsMap.isNotEmpty) {
        foodItemName = itemsMap.keys.first;
      }
      // Try to get food item from breakdown list
      else if (breakdown != null && breakdown.isNotEmpty) {
        foodItemName = breakdown.first['item'] as String?;
        quantity = breakdown.first['count'] as int? ?? 1;
      }

      // If we still don't have a food item, try to extract it from the original message text
      if (foodItemName == null || foodItemName.isEmpty) {
        // Get the original response text from the API
        final String originalResponse =
            message.toolResponse?['original_response'] as String? ??
                message.text;

        // Try to extract from "Logged: X calories for [food]" pattern
        if (originalResponse.contains("for ")) {
          final forIndex = originalResponse.indexOf("for ");
          if (forIndex >= 0 && forIndex + 4 < originalResponse.length) {
            final afterFor = originalResponse.substring(forIndex + 4);
            // Extract until period, parenthesis, or end of string
            int endIndex = afterFor.length;
            for (final char in ['.', '(', '\n']) {
              final idx = afterFor.indexOf(char);
              if (idx >= 0 && idx < endIndex) {
                endIndex = idx;
              }
            }
            foodItemName = afterFor.substring(0, endIndex).trim();
          }
        }
      }

      // If we STILL don't have a food item, try to get it from the calorie info directly
      if (foodItemName == null || foodItemName.isEmpty) {
        // Some APIs might include the food_item directly in the calorie_info
        foodItemName = calorieInfo['food_item'] as String?;
      }

      // Last resort: use a generic name if we couldn't extract anything
      if (foodItemName == null || foodItemName.isEmpty) {
        foodItemName = "food item";
      }
    }

    // Add more debugging for the final food item name

    // Build a summary widget for calorie information
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Feel free to change this color to match your "windsurf" theme
        color: const Color(0xFFffe8d5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(builder: (context) {
            // Debug print for the header text
            final headerText = isLoggingAction
                ? 'Added to your food log: ${(quantity > 1 ? "$quantity " : "")}${foodItemName ?? ""}'
                : isQueryResponse
                    ? 'This week\'s nutrition summary:'
                    : isDailySummary
                        ? 'Today\'s nutrition summary:'
                        : 'Nutrition information:';

            return const SizedBox.shrink();
          }),
          Text(
            isLoggingAction
                ? 'Added to your food log: ${(quantity > 1 ? "$quantity " : "")}${foodItemName ?? ""}'
                : isQueryResponse
                    ? 'This week\'s nutrition summary:'
                    : isDailySummary
                        ? 'Today\'s nutrition summary:'
                        : 'Nutrition information:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF440d06),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          // Macronutrient summary
          Row(
            children: [
              Text(
                isLoggingAction
                    ? '● Calories: $totalCalories'
                    : '● Total: $totalCalories calories',
                style: const TextStyle(color: Color(0xFF440d06)),
              ),
            ],
          ),
          if (calorieInfo['total_carbs'] != null)
            Row(
              children: [
                Text(
                  '● Carbs: ${calorieInfo['total_carbs']}g '
                  '(${_calculatePercentage(calorieInfo['total_carbs'] * 4, totalCalories)}%)',
                  style: const TextStyle(color: Color(0xFF440d06)),
                ),
              ],
            ),
          if (calorieInfo['total_protein'] != null)
            Row(
              children: [
                Text(
                  '● Protein: ${calorieInfo['total_protein']}g '
                  '(${_calculatePercentage(calorieInfo['total_protein'] * 4, totalCalories)}%)',
                  style: const TextStyle(
                    color: Color(0xFF440d06),
                  ),
                ),
              ],
            ),
          if (calorieInfo['total_fat'] != null)
            Row(
              children: [
                Text(
                  '● Fat: ${calorieInfo['total_fat']}g '
                  '(${_calculatePercentage(calorieInfo['total_fat'] * 9, totalCalories)}%)',
                  style: const TextStyle(
                    color: Color(0xFF440d06),
                  ),
                ),
              ],
            ),

          // Only show food breakdown for queries with multiple items
          if (!isLoggingAction &&
              ((itemsMap != null && itemsMap.isNotEmpty) ||
                  (breakdown != null && breakdown.isNotEmpty)))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Food breakdown:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF440d06),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                // Display food items from breakdown if available, otherwise use items
                if (breakdown != null && breakdown.isNotEmpty)
                  ...breakdown.map((item) => _buildFoodBreakdownItem(
                        item['item'] as String,
                        item['calories'] as int,
                        carbs: item['carbs'] as double?,
                        protein: item['protein'] as double?,
                        fat: item['fat'] as double?,
                      )),
                if (breakdown == null && itemsMap != null)
                  ...itemsMap.entries.map((entry) => _buildFoodBreakdownItem(
                        entry.key,
                        entry.value['calories'] is int
                            ? entry.value['calories']
                            : int.tryParse(
                                    entry.value['calories'].toString()) ??
                                0,
                        carbs: entry.value['carbs'] is double
                            ? entry.value['carbs']
                            : double.tryParse(entry.value['carbs'].toString()),
                        protein: entry.value['protein'] is double
                            ? entry.value['protein']
                            : double.tryParse(
                                entry.value['protein'].toString()),
                        fat: entry.value['fat'] is double
                            ? entry.value['fat']
                            : double.tryParse(entry.value['fat'].toString()),
                      )),
              ],
            ),
        ],
      ),
    );
  }

  // Helper method to check if the message is a calorie logging action
  bool get isCalorieLoggingAction {
    if (message.toolUsed != 'calories' &&
        message.toolUsed != 'multiple_actions') {
      return false;
    }

    if (message.toolResponse == null ||
        message.toolResponse!['calorie_info'] == null) {
      return false;
    }

    final calorieInfo = message.toolResponse!['calorie_info'];
    final isQueryResponse = calorieInfo['is_query_response'] == true;

    if (isQueryResponse) {
      return false;
    }

    final items = calorieInfo['items'] as Map<String, dynamic>?;
    final breakdown = calorieInfo['breakdown'] as List<dynamic>?;

    return ((items != null && items.length == 1) ||
        (breakdown != null && breakdown.length == 1));
  }

  // Helper method to format budget information
  Widget _buildBudgetInfo() {
    // Check if this message looks like a budget response based on content
    final String messageText = message.text;
    final bool looksLikeBudgetResponse = _isBudgetResponse(messageText);

    // If it doesn't look like a budget response and doesn't have budget tool info, return empty
    if (!looksLikeBudgetResponse &&
        (message.toolUsed != 'budget' &&
            message.toolUsed != 'multiple_actions')) {
      return const SizedBox.shrink();
    }

    // First, try to extract budget info from the standard fields if available
    double total = 0.0;
    List<dynamic> breakdown = [];
    String? category;
    double? addedAmount; // Track the specific amount that was added
    bool isQueryResponse = false;
    String timePeriod = 'today'; // Default time period

    // Check if this is a query about a specific time period
    if (messageText.toLowerCase().contains('week')) {
      timePeriod = 'this week';
    } else if (messageText.toLowerCase().contains('month')) {
      timePeriod = 'this month';
    } else if (messageText.toLowerCase().contains('year')) {
      timePeriod = 'this year';
    }

    // Determine if this is a logging action or a query
    bool isLoggingAction = !messageText.toLowerCase().contains('how much') &&
        !messageText.toLowerCase().contains('spent this') &&
        !messageText.toLowerCase().contains('spent last') &&
        !messageText.toLowerCase().contains('total spent') &&
        _isExpenseLoggingAction(messageText);

    // Try to extract expense description for logging actions
    String? expenseDescription;
    if (isLoggingAction) {
      // Try to get expense description from expense info
      if (message.toolResponse != null &&
          message.toolResponse!['expense_info'] != null) {
        final expenseInfo = message.toolResponse!['expense_info'];

        // Check if this is a query response from the server
        if (expenseInfo['is_query_response'] == true) {
          isLoggingAction = false;
          isQueryResponse = true;
        }

        // Check if this is explicitly a logging action (has actions_logged)
        if (expenseInfo['actions_logged'] != null &&
            expenseInfo['actions_logged'] is int &&
            expenseInfo['actions_logged'] > 0) {
          isLoggingAction = true;
          isQueryResponse = false;
        }

        if (expenseInfo['description'] != null) {
          expenseDescription = expenseInfo['description'] as String?;
        }
      }

      // If we couldn't get the description from the response, try to extract it from the message text
      if (expenseDescription == null) {
        expenseDescription = _extractExpenseDescription(messageText);
      }

      // Try to extract the specific amount that was added from the message text
      RegExp amountRegex = RegExp(r'\$(\d+(\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(messageText);
      if (amountMatch != null) {
        addedAmount = double.tryParse(amountMatch.group(1) ?? "0") ?? 0.0;
      }
    }

    if (message.toolResponse != null) {
      final budgetInfo = message.toolResponse!['expense_info'] ??
          (message.toolResponse!['context'] == 'expenses'
              ? message.toolResponse!['info']
              : null);

      // If we have structured budget info, use it
      if (budgetInfo != null) {
        // Check if this is a query response
        if (budgetInfo['is_query_response'] == true) {
          isQueryResponse = true;
          isLoggingAction = false; // Override if this is a query response
        }

        // Check if this is explicitly a logging action (has actions_logged)
        if (budgetInfo['actions_logged'] != null &&
            budgetInfo['actions_logged'] is int &&
            budgetInfo['actions_logged'] > 0) {
          isLoggingAction = true;
          isQueryResponse = false;
        }

        // For query responses, determine the time period from the message
        if (isQueryResponse) {
          if (messageText.toLowerCase().contains('week')) {
            timePeriod = 'this week';
          } else if (messageText.toLowerCase().contains('month')) {
            timePeriod = 'this month';
          } else if (messageText.toLowerCase().contains('year')) {
            timePeriod = 'this year';
          }
        }

        // Check if this is a logging action with actions_logged field
        if (isLoggingAction && budgetInfo['actions_logged'] != null) {
          // If actions_logged is 1, this is a single transaction
          if (budgetInfo['actions_logged'] == 1) {
            // Try to get the specific amount from the response
            if (addedAmount == null && budgetInfo['amount'] != null) {
              addedAmount = (budgetInfo['amount'] as num).toDouble();
            }
          }
        }

        // Extract total and breakdown
        total = budgetInfo['total_amount'] != null
            ? (budgetInfo['total_amount'] as num).toDouble()
            : (budgetInfo['total'] != null
                ? (budgetInfo['total'] as num).toDouble()
                : 0.0);

        // Handle categories - they can be direct numeric values or maps with 'amount' key
        if (budgetInfo['categories'] != null) {
          final categories = budgetInfo['categories'] as Map<String, dynamic>;
          breakdown = categories.entries.map((e) {
            // Handle both formats: direct numeric values or maps with 'amount' key
            final amount =
                e.value is Map<String, dynamic> && e.value.containsKey('amount')
                    ? e.value['amount'] as num
                    : e.value as num;

            return {'category': e.key, 'amount': amount.toDouble()};
          }).toList();
        } else if (budgetInfo['breakdown'] != null) {
          breakdown = budgetInfo['breakdown'] as List<dynamic>;
        } else {
          breakdown = [];
        }

        // For logging actions, try to get the category
        if (isLoggingAction && breakdown.isNotEmpty) {
          category = breakdown.first['category'] as String?;
        }
      }
    }

    // If we don't have structured info or it was empty, try to parse it from the response text
    if ((total == 0 && breakdown.isEmpty) && looksLikeBudgetResponse) {
      // Try to extract the total amount
      RegExp totalRegex = RegExp(r'\$(\d+(\.\d+)?)');
      final totalMatch = totalRegex.firstMatch(messageText);

      if (totalMatch != null) {
        total = double.tryParse(totalMatch.group(1) ?? "0") ?? 0.0;
      }

      // Check if this is a query response based on text patterns
      isQueryResponse = messageText.toLowerCase().contains("you've spent") ||
          messageText.toLowerCase().contains("you spent") ||
          messageText.toLowerCase().contains("total spending");

      // For query responses, determine the time period from the message
      if (isQueryResponse) {
        if (messageText.toLowerCase().contains('week')) {
          timePeriod = 'this week';
        } else if (messageText.toLowerCase().contains('month')) {
          timePeriod = 'this month';
        } else if (messageText.toLowerCase().contains('year')) {
          timePeriod = 'this year';
        }
      }

      // Try to extract category breakdowns
      // Look for patterns like "$X on category"
      RegExp categoryRegex = RegExp(r'\$(\d+(\.\d+)?) (?:on|for) (\w+)');
      final categoryMatches = categoryRegex.allMatches(messageText);

      for (final match in categoryMatches) {
        final amount = double.tryParse(match.group(1) ?? "0") ?? 0.0;
        final cat = match.group(3) ?? "other";
        breakdown.add({'category': cat, 'amount': amount});

        // For logging actions, use the first category and amount
        if (isLoggingAction && category == null) {
          category = cat;
          if (addedAmount == null) {
            addedAmount = amount;
          }
        }
      }

      // If we couldn't extract a category but have a description, try to infer category
      if (isLoggingAction && category == null && expenseDescription != null) {
        // Simple category inference based on keywords
        final String desc = expenseDescription.toLowerCase();
        if (desc.contains("food") ||
            desc.contains("eat") ||
            desc.contains("restaurant") ||
            desc.contains("meal") ||
            desc.contains("lunch") ||
            desc.contains("dinner")) {
          category = "food";
        } else if (desc.contains("transport") ||
            desc.contains("uber") ||
            desc.contains("lyft") ||
            desc.contains("taxi") ||
            desc.contains("bus") ||
            desc.contains("train")) {
          category = "transport";
        } else if (desc.contains("movie") ||
            desc.contains("game") ||
            desc.contains("entertainment")) {
          category = "entertainment";
        } else if (desc.contains("shop") ||
            desc.contains("buy") ||
            desc.contains("purchase")) {
          category = "shopping";
        } else {
          category = "other";
        }
      }
    }

    // If we found no data, don't show anything
    if (total == 0 && breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build the budget summary container
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFffe8d5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isQueryResponse
                ? 'Expense Summary'
                : isLoggingAction
                    ? 'Expense Added'
                    : 'Expense Summary',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF440d06),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // For query responses, show the total for the specific time period
          if (isQueryResponse)
            Text(
              '● Total spent $timePeriod: \$${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF440d06),
                fontWeight: FontWeight.w500,
              ),
            ),

          // Show the specific transaction details for logging actions
          if (isLoggingAction &&
              (addedAmount != null || expenseDescription != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '● Added: \$${addedAmount?.toStringAsFixed(2) ?? "?"} for ${expenseDescription ?? _formatCategory(category ?? "other")}',
                style: const TextStyle(
                  color: Color(0xFF440d06),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Total amount for logging actions
          if (isLoggingAction)
            Text(
              '● Total spent today: \$${total.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF440d06)),
            ),

          // Show category breakdown for both queries and logging actions if multiple categories
          if (breakdown.length > 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Category breakdown:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF440d06),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                ...breakdown.map((item) {
                  final cat = item['category'] as String;
                  final amount = item['amount'] is num
                      ? (item['amount'] as num).toDouble()
                      : double.tryParse(item['amount'].toString()) ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '● ${_formatCategory(cat)}: \$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF440d06)),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  // Helper method to check if a message is an expense logging action
  bool _isExpenseLoggingAction(String text) {
    final String lowerText = text.toLowerCase();

    // Check for patterns that indicate logging rather than querying
    return (lowerText.contains("spent") &&
            !lowerText.contains("you've spent") &&
            !lowerText.contains("you spent")) ||
        lowerText.contains("logged") ||
        lowerText.contains("recorded") ||
        lowerText.contains("added") ||
        lowerText.contains("expense added") ||
        lowerText.contains("transaction added") ||
        // Check for common logging patterns
        (lowerText.contains("for ") && text.contains("\$")) ||
        (lowerText.contains("on") &&
            text.contains("\$") &&
            !lowerText.contains("spent on"));
  }

  // Helper method to extract expense description from message
  String? _extractExpenseDescription(String text) {
    // Try different patterns to extract description

    // Pattern: "spent $X on Y"
    RegExp spentOnRegex = RegExp(r'spent \$\d+(\.\d+)? on (.+?)(?:\.|\s*$)');
    var match = spentOnRegex.firstMatch(text);
    if (match != null && match.group(2) != null) {
      return match.group(2)!.trim();
    }

    // Pattern: "$X for Y"
    RegExp forRegex = RegExp(r'\$\d+(\.\d+)? for (.+?)(?:\.|\s*$)');
    match = forRegex.firstMatch(text);
    if (match != null && match.group(2) != null) {
      return match.group(2)!.trim();
    }

    // Pattern: "Added expense: Y for $X"
    RegExp addedExpenseRegex =
        RegExp(r'added expense:? (.+?) for \$\d+', caseSensitive: false);
    match = addedExpenseRegex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    return null;
  }

  // Helper method to check if a message looks like a budget response
  bool _isBudgetResponse(String text) {
    // First check if this is the welcome message
    if (text.contains("Hi, I'm Plexi and I will be your virtual assistant")) {
      return false;
    }

    final String lowerText = text.toLowerCase();

    return lowerText.contains("you've spent") ||
        lowerText.contains("you spent") ||
        lowerText.contains("total spending") ||
        lowerText.contains("expense summary") ||
        lowerText.contains("spending summary") ||
        lowerText.contains("budget summary") ||
        lowerText.contains("transactionrepository: fetching transactions") ||
        lowerText.contains("expense added") ||
        lowerText.contains("transaction added") ||
        lowerText.contains("spent") ||
        (lowerText.contains("week") && text.contains("\$")) ||
        (lowerText.contains("month") && text.contains("\$")) ||
        (lowerText.contains("today") && text.contains("\$")) ||
        // Check for dollar amount patterns
        (text.contains("\$") &&
            (lowerText.contains("groceries") ||
                lowerText.contains("dining") ||
                lowerText.contains("transport") ||
                lowerText.contains("entertainment") ||
                lowerText.contains("shopping") ||
                lowerText.contains("housing") ||
                lowerText.contains("savings") ||
                lowerText.contains("investment") ||
                lowerText.contains("other")));
  }

  // Helper method to format category names
  String _formatCategory(String category) {
    // Convert snake_case or lowercase to Title Case
    return category
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.sender == 'user';
    final formattedText = _formatMessage(message.text);

    // Check if this is a query response with calorie or budget info
    final bool isCalorieQueryResponse = (message.toolUsed == 'calories' ||
            message.toolUsed == 'multiple_actions') &&
        message.toolResponse != null &&
        message.toolResponse!['calorie_info'] != null &&
        message.toolResponse!['calorie_info']['is_query_response'] == true;

    final bool isBudgetQueryResponse = _isBudgetResponse(formattedText);
    final bool isCalorieLoggingAction = this.isCalorieLoggingAction;

    // Check if we have both calorie and expense information
    final bool hasCalorieInfo = message.toolResponse != null &&
        message.toolResponse!['calorie_info'] != null;
    final bool hasExpenseInfo = message.toolResponse != null &&
        message.toolResponse!['expense_info'] != null;
    final bool hasBothIntents = hasCalorieInfo && hasExpenseInfo;

    // Determine if we should hide the text response
    // Only hide text if we have only one intent or if the text is empty
    final bool hideText = (isCalorieQueryResponse ||
            isCalorieLoggingAction ||
            isBudgetQueryResponse) &&
        (!hasBothIntents || formattedText.isEmpty);

    if (isUser) {
      // USER MESSAGE: right-aligned, blue-grey bubble
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFB5814),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            formattedText,
            style: const TextStyle(
              color: Color(0xFF440d06),
              fontSize: 16,
              height: 1.4,
              fontFamily: 'Roboto',
            ),
          ),
        ),
      );
    } else {
      // ASSISTANT MESSAGE: left-aligned, system default font
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFffe8d5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only show the text response if it's not a query response or logging action
              // or if we have both intents and the text is not empty
              if (!hideText && formattedText.isNotEmpty)
                SelectableText(
                  formattedText,
                  style: const TextStyle(
                    color: const Color(0xFF440d06),
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              // Display calorie info (blue box) if available
              _buildCalorieInfo(),
              // Display budget info (blue box) if available
              _buildBudgetInfo(),
            ],
          ),
        ),
      );
    }
  }
}
