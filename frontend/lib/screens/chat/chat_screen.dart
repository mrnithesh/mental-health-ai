import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/service_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isInputFocused = false;
  ChatSession? _chatSession;

  late AnimationController _typingController;
  late VoidCallback _messageInputListener;

  bool get _canSend => _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _messageInputListener = () {
      if (mounted) setState(() {});
    };
    _messageController.addListener(_messageInputListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final geminiService = ref.read(geminiServiceProvider);
      _chatSession = geminiService.startChat();
    });

    _messages.add(_ChatMessage(
      text:
          "Hey! I'm NILAA, your virtual friend. You can talk to me about anything—casual stuff, feelings, or whatever is on your mind. How are you doing today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.removeListener(_messageInputListener);
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_chatSession == null) {
      debugPrint('Chat session is null — reinitializing');
      try {
        final geminiService = ref.read(geminiServiceProvider);
        _chatSession = geminiService.startChat();
      } catch (e) {
        debugPrint('Failed to init chat session: $e');
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Failed to initialize Gemini: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
        return;
      }
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      int? aiMessageIndex;
      final aiMessageTime = DateTime.now();
      final responseStream = _chatSession!.sendMessageStream(
        Content.text(text),
      );

      await for (final chunk in responseStream) {
        final chunkText = chunk.text;
        if (chunkText != null && chunkText.isNotEmpty) {
          setState(() {
            _isTyping = false;
            aiMessageIndex ??= _messages.length;
            if (aiMessageIndex == _messages.length) {
              _messages.add(_ChatMessage(
                text: chunkText,
                isUser: false,
                timestamp: aiMessageTime,
              ));
            } else if (aiMessageIndex! < _messages.length) {
              _messages[aiMessageIndex!] = _ChatMessage(
                text: _messages[aiMessageIndex!].text + chunkText,
                isUser: false,
                timestamp: _messages[aiMessageIndex!].timestamp,
              );
            }
          });
          _scrollToBottom();
        }
      }

      if (mounted) {
        setState(() {
          _isTyping = false;
          if (aiMessageIndex == null) {
            _messages.add(_ChatMessage(
              text: "I couldn't generate a response right now. Please try again.",
              isUser: false,
              timestamp: aiMessageTime,
              isError: true,
            ));
          }
        });
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text:
              'Error: ${e.toString()}\n\nMake sure Firebase AI Logic (Gemini API) is enabled in your Firebase Console.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }

    setState(() {
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const isDark = false;
    return Scaffold(
      backgroundColor: _ChatPalette.background(isDark),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.06),
                AppColors.background,
                AppColors.secondary.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildAppBar(isDark),
              Expanded(child: _buildMessagesList(isDark)),
              if (_isTyping) _buildTypingIndicator(isDark),
              _buildInputArea(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _ChatPalette.headerSurface(isDark),
        border: Border(
          bottom: BorderSide(color: _ChatPalette.border(isDark), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _ChatPalette.avatarBackground(isDark),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _ChatPalette.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NILAA',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _ChatPalette.textPrimary(isDark),
                      ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _ChatPalette.online,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Online',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _ChatPalette.textSecondary(isDark),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _ChatPalette.statusPillBackground(isDark),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _ChatPalette.border(isDark)),
            ),
            child: Text(
              'Private chat',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _ChatPalette.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showAvatar =
            index == 0 || _messages[index - 1].isUser != message.isUser;

        return _AnimatedMessageEntry(
          key: ValueKey('${message.timestamp.microsecondsSinceEpoch}-${message.isUser}'),
          isUser: message.isUser,
          child: _MessageBubble(
            message: message,
            showAvatar: showAvatar,
            isDark: isDark,
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _ChatPalette.avatarBackground(isDark),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _ChatPalette.accent,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _ChatPalette.assistantBubbleBackground(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _ChatPalette.border(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(
                  controller: _typingController,
                  delay: 0.0,
                  color: _ChatPalette.accent,
                ),
                const SizedBox(width: 4),
                _TypingDot(
                  controller: _typingController,
                  delay: 0.2,
                  color: _ChatPalette.accent,
                ),
                const SizedBox(width: 4),
                _TypingDot(
                  controller: _typingController,
                  delay: 0.4,
                  color: _ChatPalette.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: _ChatPalette.composerSurface(isDark),
        border: Border(
          top: BorderSide(color: _ChatPalette.border(isDark), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _ChatPalette.inputBackground(isDark),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isInputFocused
                      ? _ChatPalette.accent
                      : _ChatPalette.border(isDark),
                  width: _isInputFocused ? 1.3 : 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                onTap: () {
                  if (!_isInputFocused && mounted) {
                    setState(() => _isInputFocused = true);
                  }
                },
                onTapOutside: (_) {
                  if (_isInputFocused && mounted) {
                    setState(() => _isInputFocused = false);
                  }
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: _ChatPalette.textHint(isDark)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                style: TextStyle(
                  color: _ChatPalette.textPrimary(isDark),
                  height: 1.35,
                ),
                onChanged: (_) {
                  if (mounted) setState(() {});
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _canSend
                  ? _ChatPalette.accent
                  : _ChatPalette.sendDisabled(isDark),
              borderRadius: BorderRadius.circular(22),
              boxShadow: _canSend
                  ? [
                      BoxShadow(
                        color: _ChatPalette.accent.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
              border: Border.all(
                color: _canSend
                    ? _ChatPalette.accent
                    : _ChatPalette.border(isDark),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _canSend
                    ? _sendMessage
                    : () => Navigator.of(context).pushNamed(AppRoutes.voiceChat),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _canSend ? Icons.send_rounded : Icons.mic_rounded,
                    color: _canSend ? Colors.white : _ChatPalette.textHint(isDark),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool showAvatar;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: message.isUser ? 48 : 0,
        right: message.isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser && showAvatar)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                color: _ChatPalette.avatarBackground(isDark),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _ChatPalette.accent,
                size: 14,
              ),
            )
          else if (!message.isUser)
            const SizedBox(width: 35),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: message.isUser
                    ? _ChatPalette.userBubbleBackground
                    : message.isError
                        ? _ChatPalette.errorBubbleBackground(isDark)
                        : _ChatPalette.assistantBubbleBackground(isDark),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 5),
                  bottomRight: Radius.circular(message.isUser ? 5 : 16),
                ),
                border: Border.all(
                  color: message.isUser
                      ? _ChatPalette.userBubbleBackground
                      : message.isError
                          ? _ChatPalette.errorBorder
                          : _ChatPalette.border(isDark),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: message.isUser
                          ? Colors.white
                          : message.isError
                              ? AppColors.error
                              : _ChatPalette.textPrimary(isDark),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : _ChatPalette.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
          if (message.isUser && showAvatar)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 7),
              decoration: BoxDecoration(
                color: _ChatPalette.userAvatarBackground,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 14,
              ),
            )
          else if (message.isUser)
            const SizedBox(width: 35),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TypingDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _TypingDot({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = ((controller.value + delay) % 1.0);
        final opacity =
            0.3 + (0.7 * (value < 0.5 ? value * 2 : (1 - value) * 2));

        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _AnimatedMessageEntry extends StatelessWidget {
  final Widget child;
  final bool isUser;

  const _AnimatedMessageEntry({
    super.key,
    required this.child,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final offsetY = (1 - value) * 0.045;
        final offsetX = (1 - value) * (isUser ? 0.02 : -0.02);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offsetX * 100, offsetY * 100),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ChatPalette {
  static const Color accent = AppColors.primary;
  static const Color online = AppColors.success;
  static const Color userBubbleBackground = AppColors.primary;
  static const Color userAvatarBackground = AppColors.primaryDark;
  static const Color errorBorder = Color(0xFFFCA5A5);

  static Color background(bool isDark) =>
      isDark ? AppColors.darkBackground : AppColors.background;
  static Color headerSurface(bool isDark) =>
      isDark ? AppColors.darkSurface : AppColors.surface;
  static Color composerSurface(bool isDark) =>
      isDark ? AppColors.darkSurface : AppColors.surface;
  static Color inputBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  static Color assistantBubbleBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surface;
  static Color errorBubbleBackground(bool isDark) =>
      isDark ? const Color(0xFF3A2520) : const Color(0xFFFEF0EE);
  static Color avatarBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  static Color statusPillBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  static Color border(bool isDark) =>
      isDark ? const Color(0xFF4A4540) : AppColors.surfaceVariant;
  static Color sendDisabled(bool isDark) =>
      isDark ? const Color(0xFF4A4540) : AppColors.surfaceVariant;
  static Color textPrimary(bool isDark) =>
      isDark ? const Color(0xFFEDE8E4) : AppColors.textPrimary;
  static Color textSecondary(bool isDark) =>
      isDark ? AppColors.textTertiary : AppColors.textSecondary;
  static Color textHint(bool isDark) =>
      isDark ? AppColors.textTertiary : AppColors.textTertiary;
}
