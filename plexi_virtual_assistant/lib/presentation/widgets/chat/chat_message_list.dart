import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  bool _keyboardVisible = false;
  bool _isScrolling = false;
  double? _previousMaxScrollExtent;
  double _lastKeyboardHeight = 0;
  bool _firstKeyboardAppearance = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Schedule scroll after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(immediate: true);
    });

    _scrollController.addListener(_onUserScroll);
  }

  void _onUserScroll() {
    if (!_scrollController.hasClients || _isScrolling) return;

    // Calculate how far we are from the bottom
    final distanceFromBottom = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    // Only mark as user scrolled if they're significantly away from bottom
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

  // Primary method to scroll to bottom - uses either jump or animate
  void _scrollToBottom(
      {bool immediate = false, Duration delay = Duration.zero}) {
    Future.delayed(delay, () {
      if (!mounted || !_scrollController.hasClients) return;

      // Track that we're programmatically scrolling
      _isScrolling = true;

      try {
        // Get max extent - this may change during scrolling due to layout
        final maxExtent = _scrollController.position.maxScrollExtent;

        // Store for comparison
        _previousMaxScrollExtent = maxExtent;

        if (immediate) {
          // Jump immediately without animation
          _scrollController.jumpTo(maxExtent);

          // Schedule a check to see if we need to adjust after layout
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _verifyScrollPosition();
          });
        } else {
          _scrollController
              .animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
              .then((_) {
            _verifyScrollPosition();
          });
        }
      } finally {
        // End scroll tracking after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _isScrolling = false;
          }
        });
      }
    });
  }

  // Verify and adjust scroll position if needed
  void _verifyScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;

    final currentMaxExtent = _scrollController.position.maxScrollExtent;

    // If max extent changed during scrolling, jump to the new bottom
    if (_previousMaxScrollExtent != currentMaxExtent) {
      _previousMaxScrollExtent = currentMaxExtent;
      _scrollController.jumpTo(currentMaxExtent);
    } else {
      // Check if we're not at the very bottom (allowing small tolerance)
      final distanceFromBottom = _scrollController.position.maxScrollExtent -
          _scrollController.position.pixels;

      if (distanceFromBottom > 10) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _handleKeyboardVisibilityChange(bool visible, double keyboardHeight) {
    if (visible) {
      // When keyboard appears
      _userHasScrolled = false;

      // Special handling for first keyboard appearance
      if (_firstKeyboardAppearance) {
        _firstKeyboardAppearance = false;

        // Schedule the scroll after the frame finishes, plus a longer delay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 450), () {
            // Increased delay further
            if (mounted && _scrollController.hasClients) {
              _scrollToBottom(immediate: true); // Use immediate jump
            }
          });
        });
      } else {
        // Regular keyboard appearance after first time - use animation
        _scrollToBottom(delay: const Duration(milliseconds: 100));
      }
    }
    // Update internal state directly
    _lastKeyboardHeight = keyboardHeight;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;

    // Use addPostFrameCallback to ensure metrics are read after layout changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      final keyboardVisible = bottomInset > 0;

      if (keyboardVisible != _keyboardVisible) {
        setState(() {
          _keyboardVisible = keyboardVisible;
          _lastKeyboardHeight = bottomInset;
        });
        _handleKeyboardVisibilityChange(keyboardVisible, bottomInset);
      } else if (keyboardVisible && bottomInset != _lastKeyboardHeight) {
        setState(() {
          _lastKeyboardHeight = bottomInset;
        });
        _handleKeyboardVisibilityChange(keyboardVisible, bottomInset);
      }
    });
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hasNewMessages = widget.messages.length != oldWidget.messages.length;
    final typingStateChanged =
        widget.isAssistantTyping != oldWidget.isAssistantTyping;

    // Scroll down for new messages or typing indicator changes
    if ((hasNewMessages || typingStateChanged) &&
        (!_userHasScrolled || _keyboardVisible)) {
      // First let the build complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(delay: const Duration(milliseconds: 100));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update keyboard visibility state directly from MediaQuery
    // Note: didChangeMetrics is generally more reliable for state changes,
    // but reading here ensures the padding is correct for the current build.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _keyboardVisible = bottomInset > 0;

    // When view first loads with messages, ensure we scroll to bottom
    if (_isFirstLoad && widget.messages.isNotEmpty) {
      _isFirstLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(immediate: true);
      });
    }

    // Create a list view with appropriate padding
    final listView = widget.messages.isEmpty
        ? _buildWelcomeMessage()
        : ListView.builder(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            // Ensure padding reflects current keyboard state
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + bottomInset, // Use bottomInset directly
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
          );

    return AnimatedPadding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // When scrolled to bottom, reset the user scroll state
          if (notification is ScrollUpdateNotification &&
              !_isScrolling &&
              _scrollController.hasClients) {
            final distanceFromBottom =
                _scrollController.position.maxScrollExtent -
                    _scrollController.position.pixels;

            if (distanceFromBottom < 20) {
              _userHasScrolled = false;
            }
          }

          // Process all keyboard status notifications
          if (_keyboardVisible &&
              notification is ScrollEndNotification &&
              !_userHasScrolled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }

          return true;
        },
        child: Column(
          children: [
            Expanded(child: listView),
            if (widget.isAssistantTyping)
              Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 8.0
                        : 0.0),
                child: const TypingIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  // Widget that displays the welcome message when there are no messages
  Widget _buildWelcomeMessage() {
    // Create a virtual welcome message
    final welcomeMessage = ChatMessage(
      id: 'welcome',
      content:
          "Hi, I'm Plexi and I will be your virtual assistant. You can chat with me or tell me how much you spent today or what food you ate.",
      isUser: false,
      timestamp: DateTime.now(),
    );

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20, // Extra padding on top for better appearance
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      children: [
        ChatMessageBubble(
          message: welcomeMessage,
          isLastMessage: true,
          isTyping: false,
        ),
      ],
    );
  }
}
