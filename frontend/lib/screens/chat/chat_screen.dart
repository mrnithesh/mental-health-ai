import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/voice_provider.dart';
import '../journal/journal_editor_screen.dart' show JournalEditorArgs;

class ChatScreen extends ConsumerStatefulWidget {
  final bool journalMode;
  final String? conversationId;

  const ChatScreen({super.key, this.journalMode = false, this.conversationId});

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
  bool _savedAsJournal = false;
  bool _isSummarizing = false;
  bool _isLoadingHistory = false;
  ChatSession? _chatSession;
  bool _conversationCreated = false;
  int _userMessageCount = 0;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  late AnimationController _typingController;
  late VoidCallback _messageInputListener;

  bool get _canSend => _messageController.text.trim().isNotEmpty;
  bool get _isPrivate => ref.read(chatSessionProvider).isPrivate;

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
      if (widget.conversationId != null) {
        _resumeConversation(widget.conversationId!);
      } else if (!widget.journalMode) {
        _loadOrStartConversation();
      } else {
        _startFreshChat();
      }
    });
  }

  Future<void> _resumeConversation(String conversationId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final chatNotifier = ref.read(chatSessionProvider.notifier);
      chatNotifier.resumeConversation(conversationId);

      final firestoreService = ref.read(firestoreServiceProvider);

      final conversation = await firestoreService.getConversation(conversationId);
      final contextSummary = conversation?.contextSummary;

      final messagesStream = firestoreService.getMessages(conversationId);
      final messagesList = await messagesStream.first;

      final history = <Content>[];

      if (contextSummary != null && contextSummary.isNotEmpty) {
        history.add(Content('user', [TextPart('Previous context: $contextSummary')]));
        history.add(Content('model', [TextPart('I remember our previous conversation. How can I help you today?')]));
      }

      for (final msg in messagesList) {
        _messages.add(_ChatMessage(
          firestoreId: msg.id,
          text: msg.content,
          isUser: msg.isUser,
          timestamp: msg.createdAt,
        ));
        history.add(msg.isUser
            ? Content('user', [TextPart(msg.content)])
            : Content('model', [TextPart(msg.content)]));
        if (msg.isUser) _userMessageCount++;
      }

      final geminiService = ref.read(geminiServiceProvider);
      _chatSession = geminiService.startChat(history: history);
      _conversationCreated = true;
    } catch (e) {
      debugPrint('Failed to resume conversation: $e');
      final geminiService = ref.read(geminiServiceProvider);
      _chatSession = geminiService.startChat();
    }
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _loadOrStartConversation() async {
    if (_isPrivate) {
      _startFreshChat();
      return;
    }

    setState(() => _isLoadingHistory = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final conversationsStream = firestoreService.getConversations();
      final conversations = await conversationsStream.first;

      if (conversations.isNotEmpty) {
        final latest = conversations.first;
        final age = DateTime.now().difference(latest.updatedAt);
        // Resume if the conversation is less than 24 hours old
        if (age.inHours < 24) {
          if (mounted) setState(() => _isLoadingHistory = false);
          await _resumeConversation(latest.id);
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to load recent conversation: $e');
    }

    if (mounted) setState(() => _isLoadingHistory = false);
    _startFreshChat();
  }

  void _startFreshChat() {
    final geminiService = ref.read(geminiServiceProvider);
    _chatSession = geminiService.startChat();
    final voiceName = ref.read(activeVoiceProvider).name;
    _messages.add(_ChatMessage(
      text:
          "Hey! I'm $voiceName, your virtual friend. You can talk to me about anything—casual stuff, feelings, or whatever is on your mind. How are you doing today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
    if (mounted) setState(() {});
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  Future<void> _deleteSelectedMessages() async {
    final indices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    final firestoreIds = <String>[];

    for (final i in indices) {
      if (i < _messages.length) {
        final msg = _messages[i];
        if (msg.firestoreId != null) firestoreIds.add(msg.firestoreId!);
      }
    }

    if (firestoreIds.isNotEmpty && !_isPrivate) {
      final chatNotifier = ref.read(chatSessionProvider.notifier);
      await chatNotifier.deleteMessages(firestoreIds);
    }

    setState(() {
      for (final i in indices) {
        if (i < _messages.length) _messages.removeAt(i);
      }
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
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

    _userMessageCount++;
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

    final chatNotifier = ref.read(chatSessionProvider.notifier);
    if (!_isPrivate && !_conversationCreated && !widget.journalMode) {
      await chatNotifier.createConversation(
        title: text.length > 40 ? '${text.substring(0, 40)}...' : text,
      );
      _conversationCreated = true;
      // Persist the initial greeting so it appears when resuming
      if (_messages.isNotEmpty && !_messages.first.isUser) {
        chatNotifier.persistMessage(
          role: 'assistant',
          content: _messages.first.text,
        );
      }
    }

    if (!_isPrivate) {
      chatNotifier.persistMessage(role: 'user', content: text);
    }

    try {
      int? aiMessageIndex;
      final aiMessageTime = DateTime.now();
      final responseStream = _chatSession!.sendMessageStream(
        Content.text(text),
      );

      final responseBuffer = StringBuffer();

      await for (final chunk in responseStream) {
        final chunkText = chunk.text;
        if (chunkText != null && chunkText.isNotEmpty) {
          responseBuffer.write(chunkText);
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

      if (responseBuffer.isNotEmpty && !_isPrivate) {
        chatNotifier.persistMessage(
          role: 'assistant',
          content: responseBuffer.toString(),
        );
      }

      // Context memory: summarize older messages when threshold is exceeded
      // TODO: Move threshold to config; consider token counting instead of message counting
      const contextWindowSize = 20;
      final totalMessages =
          _messages.where((m) => !m.isError).length;
      if (!_isPrivate &&
          totalMessages > contextWindowSize &&
          totalMessages % 10 == 0) {
        _summarizeContextInBackground();
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

  Future<void> _summarizeContextInBackground() async {
    try {
      final olderMessages = _messages
          .where((m) => !m.isError)
          .skip(1)
          .take((_messages.length - 10).clamp(0, _messages.length))
          .map((m) => '${m.isUser ? "User" : ref.read(activeVoiceProvider).name}: ${m.text}')
          .join('\n');

      if (olderMessages.isEmpty) return;

      final geminiService = ref.read(geminiServiceProvider);
      final summary = await geminiService.summarizeForContext(olderMessages);

      if (summary.isNotEmpty) {
        final chatNotifier = ref.read(chatSessionProvider.notifier);
        await chatNotifier.saveContextSummary(summary);
        debugPrint('Context summary saved (${summary.length} chars)');
      }
    } catch (e) {
      debugPrint('Context summarization failed: $e');
    }
  }

  bool get _canSaveAsJournal => _userMessageCount >= 2;

  String _gatherMessagesAsText() {
    final msgs = _messages
        .where((m) => !m.isError)
        .skip(1) // skip initial Amigo greeting
        .toList();
    final limit = msgs.length > 30 ? msgs.length - 30 : 0;
    final buffer = StringBuffer();
    for (int i = limit; i < msgs.length; i++) {
      final label = msgs[i].isUser ? 'User' : ref.read(activeVoiceProvider).name;
      buffer.writeln('$label: ${msgs[i].text}');
    }
    return buffer.toString();
  }

  void _showSaveConfirmation() {
    final userMsgCount =
        _messages.where((m) => m.isUser && !m.isError).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (_isSummarizing) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  '${ref.read(activeVoiceProvider).name} is writing up your conversation...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Icon(Icons.note_add_rounded,
                    size: 32, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  'Save this conversation as a journal entry?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '$userMsgCount messages with ${ref.read(activeVoiceProvider).name}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _isSummarizing = true);
                      setSheetState(() {});
                      Navigator.pop(ctx);
                      await _summarizeAndNavigate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save as Journal',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _summarizeAndNavigate() async {
    setState(() => _isSummarizing = true);
    try {
      final geminiService = ref.read(geminiServiceProvider);
      final transcript = _gatherMessagesAsText();
      final result = await geminiService.summarizeConversation(transcript);

      if (mounted) {
        setState(() {
          _isSummarizing = false;
          _savedAsJournal = true;
        });
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.journalEditor,
          arguments: JournalEditorArgs(
            prefillTitle: result.title,
            prefillContent: result.body,
            prefillTags: ['chat-journal'],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSummarizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not summarize conversation'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
              if (_isSelectionMode)
                _buildSelectionBar()
              else
                _buildAppBar(isDark),
              Expanded(child: _buildMessagesList(isDark)),
              if (_isTyping) _buildTypingIndicator(isDark),
              if (!_isSelectionMode) _buildInputArea(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE0DCD6), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _exitSelectionMode,
            color: AppColors.textPrimary,
            iconSize: 22,
          ),
          Text(
            '${_selectedIndices.length} selected',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectedIndices.isEmpty
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Messages'),
                        content: Text(
                          'Delete ${_selectedIndices.length} message${_selectedIndices.length == 1 ? '' : 's'}? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) await _deleteSelectedMessages();
                  },
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: _selectedIndices.isEmpty
                  ? AppColors.textTertiary
                  : AppColors.error,
            ),
            label: Text(
              'Delete',
              style: TextStyle(
                color: _selectedIndices.isEmpty
                    ? AppColors.textTertiary
                    : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
          if (widget.journalMode && Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _ChatPalette.textPrimary(isDark),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
          ],
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
                  ref.watch(activeVoiceProvider).name,
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
          if (widget.journalMode)
            TextButton(
              onPressed:
                  _canSaveAsJournal && !_savedAsJournal && !_isSummarizing
                      ? () => _showSaveConfirmation()
                      : null,
              style: TextButton.styleFrom(
                backgroundColor: _canSaveAsJournal && !_savedAsJournal
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                foregroundColor: _canSaveAsJournal && !_savedAsJournal
                    ? Colors.white
                    : _ChatPalette.textSecondary(isDark),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                _savedAsJournal ? 'Saved' : 'Done -- Save',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            GestureDetector(
              onTap: () {
                final notifier = ref.read(chatSessionProvider.notifier);
                notifier.togglePrivate();
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isPrivate
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : _ChatPalette.statusPillBackground(isDark),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _isPrivate
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : _ChatPalette.border(isDark),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPrivate
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 13,
                      color: _isPrivate
                          ? AppColors.accent
                          : _ChatPalette.textSecondary(isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isPrivate ? 'Private' : 'Saved',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _isPrivate
                                ? AppColors.accent
                                : _ChatPalette.textSecondary(isDark),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _canSaveAsJournal && !_savedAsJournal && !_isSummarizing
                  ? _showSaveConfirmation
                  : null,
              child: Icon(
                _savedAsJournal
                    ? Icons.check_circle_rounded
                    : Icons.note_add_rounded,
                size: 22,
                color: _savedAsJournal
                    ? AppColors.accent
                    : _canSaveAsJournal
                        ? _ChatPalette.textPrimary(isDark)
                        : _ChatPalette.textHint(isDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    if (_isLoadingHistory) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Loading conversation...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showAvatar =
            index == 0 || _messages[index - 1].isUser != message.isUser;
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() => _isSelectionMode = true);
            }
            _toggleSelection(index);
          },
          onTap: _isSelectionMode ? () => _toggleSelection(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Row(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                Expanded(
                  child: _AnimatedMessageEntry(
                    key: ValueKey('${message.timestamp.microsecondsSinceEpoch}-${message.isUser}'),
                    isUser: message.isUser,
                    child: _MessageBubble(
                      message: message,
                      showAvatar: showAvatar,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
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
                  width: _isInputFocused ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                    : () => Navigator.of(context).pushNamed(
                          AppRoutes.voiceChat,
                          arguments: widget.journalMode
                              ? {'journalMode': true}
                              : null,
                        ),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _canSend ? Icons.send_rounded : Icons.mic_rounded,
                    color: _canSend ? Colors.white : _ChatPalette.textSecondary(isDark),
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
  final String? firestoreId;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  _ChatMessage({
    this.firestoreId,
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
      isDark ? AppColors.darkSurfaceVariant : Colors.white;
  static Color assistantBubbleBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surface;
  static Color errorBubbleBackground(bool isDark) =>
      isDark ? const Color(0xFF3A2520) : const Color(0xFFFEF0EE);
  static Color avatarBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  static Color statusPillBackground(bool isDark) =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  static Color border(bool isDark) =>
      isDark ? const Color(0xFF4A4540) : const Color(0xFFE0DCD6);
  static Color sendDisabled(bool isDark) =>
      isDark ? const Color(0xFF4A4540) : AppColors.surfaceVariant;
  static Color textPrimary(bool isDark) =>
      isDark ? const Color(0xFFEDE8E4) : AppColors.textPrimary;
  static Color textSecondary(bool isDark) =>
      isDark ? AppColors.textTertiary : AppColors.textSecondary;
  static Color textHint(bool isDark) =>
      isDark ? AppColors.textTertiary : AppColors.textSecondary;
}
