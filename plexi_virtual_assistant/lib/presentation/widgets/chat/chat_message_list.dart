import 'package:flutter/material.dart';
import '../../../data/models/chat_message.dart';
import 'chat_message_bubble.dart';
import '../common/typing_indicator.dart';

class ChatMessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isAssistantTyping;

  const ChatMessageList({
    Key? key,
    required this.messages,
    required this.isAssistantTyping,
  }) : super(key: key);

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _isFirstLoad = true;
  bool _userHasScrolled = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Schedule initial scroll after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait additional time to ensure all layout is complete
      Future.delayed(const Duration(milliseconds: 150), () {
        _ensureScrolledToBottom();
      });
    });

    _scrollController.addListener(_onUserScroll);
  }
  
  void _onUserScroll() {
    if (!_scrollController.hasClients) return;
    
    // Calculate how far we are from the bottom
    final distanceFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
    
    if (distanceFromBottom > 100) {
      _userHasScrolled = true;
    } else if (distanceFromBottom < 20) {
      _userHasScrolled = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onUserScroll);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
  
  // More reliable method to ensure we're at the bottom
  void _ensureScrolledToBottom({Duration initialDelay = Duration.zero}) {
    Future.delayed(initialDelay, () {
      if (!mounted || !_scrollController.hasClients) return;
      
      // Get actual maximum extent after layout is complete
      final maxExtent = _scrollController.position.maxScrollExtent;
      
      _scrollController.animateTo(
        maxExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      
      // Double-check we reached the bottom by doing one more scroll after a short delay
      // This helps when content is still rendering/measuring
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;
        
        // If we're not at the very bottom (allowing small tolerance), scroll again
        if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels > 10) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  @override
  void didChangeMetrics() {
    // This is called when viewInsets (keyboard) change
    if (!_userHasScrolled) {
      _ensureScrolledToBottom(initialDelay: const Duration(milliseconds: 100));
    }
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    bool shouldScroll = widget.messages.length != oldWidget.messages.length || 
                      widget.isAssistantTyping != oldWidget.isAssistantTyping;
    
    // Scroll to bottom when messages change but only if the user hasn't scrolled up
    if (shouldScroll && !_userHasScrolled) {
      // Give time for the layout to update with the new messages
      _ensureScrolledToBottom(initialDelay: const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    // When view first loads with messages, ensure we scroll to bottom
    if (_isFirstLoad && widget.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isFirstLoad = false;
        _ensureScrolledToBottom(initialDelay: const Duration(milliseconds: 200));
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // When keyboard appears, scroll to the bottom if user hasn't scrolled up
        if (notification is ScrollEndNotification && 
            MediaQuery.of(context).viewInsets.bottom > 0 && 
            !_userHasScrolled) {
          _ensureScrolledToBottom();
        }
        return true;
      },
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                return ChatMessageBubble(
                  message: message,
                  isLastMessage: index == widget.messages.length - 1,
                  isTyping: index == widget.messages.length - 1 &&
                      widget.isAssistantTyping,
                );
              },
            ),
          ),
          if (widget.isAssistantTyping) const TypingIndicator(),
        ],
      ),
    );
  }
}
