import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../data/models/chat_message.dart';
import '../widgets/chat/chat_input.dart';
import '../widgets/common/app_background.dart';
import '../widgets/chat/chat_message_list.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Load chat history when the screen is opened
    context.read<ChatBloc>().add(LoadChatHistory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Keep this true so the background extends behind the transparent AppBar
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1) Background at the bottom
          const AppBackground(
            child: SizedBox
                .expand(), // Use SizedBox.expand() to fill the available space
          ),

          // 2) SafeArea to keep chat below status bar & not behind the AppBar
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      if (state is ChatMessageState && state.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.error!),
                            backgroundColor: Color(0xFFE75A42),
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'Dismiss',
                              textColor: Colors.white,
                              onPressed: () {
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                              },
                            ),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is ChatError) {
                        return Center(
                          child: Text(
                            state.error,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      if (state is ChatMessageState) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ChatMessageList(
                            messages: state.messages,
                            isAssistantTyping: state.isAssistantTyping,
                          ),
                        );
                      }

                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
                ChatInput(
                  onSendMessage: (message) {
                    context.read<ChatBloc>().add(SendMessage(message));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
