import 'package:equatable/equatable.dart';
import '../../data/models/chat_message.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatError extends ChatState {
  final String error;
  const ChatError(this.error);

  @override
  List<Object?> get props => [error];
}

/// This single state holds both the messages and any additional response data.
class ChatMessageState extends ChatState {
  final List<ChatMessage> messages;
  final bool isAssistantTyping;
  final Map<String, dynamic>? responseData;
  final List<Map<String, dynamic>> restaurants;
  final String? error;

  ChatMessageState({
    required this.messages,
    this.isAssistantTyping = false,
    this.responseData,
    this.restaurants = const [],
    this.error,
  }) {}

  @override
  List<Object?> get props =>
      [messages, isAssistantTyping, responseData, restaurants, error];
}
