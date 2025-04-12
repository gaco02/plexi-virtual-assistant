import '../models/chat_response.dart';
import '../models/chat_message.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatRepository {
  final ApiService _apiService;
  static const String _storageKey = 'chat_messages';
  static List<ChatMessage> _messages = [];
  static bool _initialized = false;

  ChatRepository(this._apiService) {
    _initializeMessages();
  }

  Future<void> _initializeMessages() async {
    if (!_initialized) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final messagesJson = prefs.getStringList(_storageKey);

        if (messagesJson != null && messagesJson.isNotEmpty) {
          _messages = messagesJson.map((json) {
            return ChatMessage.fromJson(jsonDecode(json));
          }).toList();
        }

        _initialized = true;
      } catch (e) {
        _initialized = true;
      }
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson =
          _messages.map((msg) => jsonEncode(msg.toJson())).toList();
      await prefs.setStringList(_storageKey, messagesJson);
    } catch (e) {}
  }

  Future<List<ChatMessage>> getMessages({String? userId}) async {
    await _initializeMessages();
    if (userId != null) {
      final userMessages =
          _messages.where((msg) => msg.userId == userId).toList();

      return userMessages;
    }

    return List.from(_messages);
  }

  Future<void> addMessage(ChatMessage message) async {
    await _initializeMessages();
    _messages.add(message);
    await _saveMessages();
  }

  Future<void> clearMessages({String? userId}) async {
    await _initializeMessages();
    if (userId != null) {
      _messages.removeWhere((msg) => msg.userId == userId);
    } else {
      _messages.clear();
    }
    await _saveMessages();
  }

  Future<ChatResponse> sendMessage(
    String message,
    List<Map<String, String>> conversationHistory, {
    String? timestamp,
    String? userId,
  }) async {
    try {
      final requestData = {
        'message': message,
        'conversation_history': conversationHistory,
        'timestamp': timestamp,
        'tool': null,
        'user_id': userId,
        'local_time': timestamp,
        'timezone': DateTime.now().timeZoneName,
      };

      final response = await _apiService.post('/chat/', requestData);

      // Log specific parts of the response for debugging
      if (response['calorie_info'] != null) {
        final calorieInfo = response['calorie_info'];
        if (calorieInfo['is_query_response'] == true) {}
      }

      return ChatResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}
