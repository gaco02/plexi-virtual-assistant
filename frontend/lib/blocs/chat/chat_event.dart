import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadChatHistory extends ChatEvent {}

class SendMessage extends ChatEvent {
  final String message;
  final List<Map<String, String>> conversationHistory;

  SendMessage(this.message, {this.conversationHistory = const []});

  @override
  List<Object> get props => [message, conversationHistory];
}

class ReceiveMessage extends ChatEvent {
  final String message;
  final List<Map<String, dynamic>> restaurants;

  ReceiveMessage(this.message, {this.restaurants = const []});

  @override
  List<Object> get props => [message, restaurants];
}

class ClearChatHistory extends ChatEvent {}
