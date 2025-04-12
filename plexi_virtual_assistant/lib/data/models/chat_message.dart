import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? toolUsed;
  final Map<String, dynamic>? toolResponse;
  final String? userId;

  String get sender => isUser ? 'user' : 'assistant';
  String get text => content;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.toolUsed,
    this.toolResponse,
    this.userId,
  });

  @override
  List<Object?> get props =>
      [id, content, isUser, timestamp, toolUsed, toolResponse, userId];

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'is_user': isUser,
        'timestamp': timestamp.toIso8601String(),
        'tool_used': toolUsed,
        'tool_response': toolResponse,
        'user_id': userId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['is_user'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolUsed: json['tool_used'] as String?,
      toolResponse: json['tool_response'] as Map<String, dynamic>?,
      userId: json['user_id'] as String?,
    );
  }
}
