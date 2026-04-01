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

class _P {
  static const bg         = AppColors.background;
  static const surface    = AppColors.surface;
  static const surfaceAlt = AppColors.surfaceVariant;
  static const inputBg    = AppColors.surface;

  static const border     = Color(0xFFD4E8DC);
  static const borderFocus= AppColors.primary;

  static const teal       = AppColors.primary;
  static const tealLight  = AppColors.surfaceVariant;
  static const tealDark   = AppColors.primaryDark;

  static const userBubble    = AppColors.primary;
  static const userBubbleDark= AppColors.primaryDark;

  static const textPrimary   = AppColors.textPrimary;
  static const textSecondary = AppColors.textSecondary;
  static const textHint      = AppColors.textTertiary;
  static const textOnTeal    = Color(0xFFFFFFFF);

  static const error      = AppColors.error;
  static const errorBg    = Color(0xFFFEF2F2);
  static const online     = AppColors.success;
  static const shadow     = Color(0x0C000000);
}

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
  final FocusNode _inputFocusNode = FocusNode();
  final List<_ChatMessage> _messages = [];

  bool _isTyping         = false;
  bool _isInputFocused   = false;
  bool _savedAsJournal   = false;
  bool _isSummarizing    = false;
  bool _isLoadingHistory = false;

  ChatSession? _chatSession;
  bool _conversationCreated = false;
  int  _userMessageCount    = 0;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  late AnimationController _typingController;
  late VoidCallback _messageInputListener;

  bool get _canSend  => _messageController.text.trim().isNotEmpty;
  bool get _isPrivate => ref.read(chatSessionProvider).isPrivate;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _messageInputListener = () { if (mounted) setState(() {}); };
    _messageController.addListener(_messageInputListener);

    _inputFocusNode.addListener(() {
      if (mounted) setState(() => _isInputFocused = _inputFocusNode.hasFocus);
    });

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

  @override
  void dispose() {
    _messageController.removeListener(_messageInputListener);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _typingController.dispose();
    super.dispose();
  }

  // ── conversation management ────────────────────────────────────────────────

  Future<void> _resumeConversation(String conversationId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final chatNotifier = ref.read(chatSessionProvider.notifier);
      chatNotifier.resumeConversation(conversationId);

      final firestoreService = ref.read(firestoreServiceProvider);
      final conversation     = await firestoreService.getConversation(conversationId);
      final contextSummary   = conversation?.contextSummary;
      final messagesList     = await firestoreService.getMessages(conversationId).first;
      final history          = <Content>[];

      if (contextSummary != null && contextSummary.isNotEmpty) {
        history.add(Content('user',  [TextPart('Previous context: $contextSummary')]));
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
            ? Content('user',  [TextPart(msg.content)])
            : Content('model', [TextPart(msg.content)]));
        if (msg.isUser) _userMessageCount++;
      }

      final geminiService = ref.read(geminiServiceProvider);
      _chatSession = geminiService.startChat(history: history);
      _conversationCreated = true;
    } catch (e) {
      debugPrint('Failed to resume conversation: $e');
      _chatSession = ref.read(geminiServiceProvider).startChat();
    }
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _loadOrStartConversation() async {
    if (_isPrivate) { _startFreshChat(); return; }
    setState(() => _isLoadingHistory = true);
    try {
      final conversations = await ref.read(firestoreServiceProvider).getConversations().first;
      if (conversations.isNotEmpty) {
        final latest = conversations.first;
        if (DateTime.now().difference(latest.updatedAt).inHours < 24) {
          if (mounted) setState(() => _isLoadingHistory = false);
          await _resumeConversation(latest.id);
          return;
        }
      }
    } catch (e) { debugPrint('Failed to load recent conversation: $e'); }
    if (mounted) setState(() => _isLoadingHistory = false);
    _startFreshChat();
  }

  void _startFreshChat() {
    _chatSession = ref.read(geminiServiceProvider).startChat();
    final voiceName = ref.read(activeVoiceProvider).name;
    _messages.add(_ChatMessage(
      text: "Hey! I'm $voiceName, your virtual friend. You can talk to me about anything—casual stuff, feelings, or whatever is on your mind. How are you doing today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
    if (mounted) setState(() {});

    // Check for a pending message from the home quick-chat widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingChatMessageProvider);
      if (pending != null && pending.isNotEmpty) {
        ref.read(pendingChatMessageProvider.notifier).state = null;
        _messageController.text = pending;
        _sendMessage();
      }
    });
  }

  // ── selection mode ─────────────────────────────────────────────────────────

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

  void _exitSelectionMode() => setState(() {
    _isSelectionMode = false;
    _selectedIndices.clear();
  });

  Future<void> _deleteSelectedMessages() async {
    final indices     = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    final firestoreIds = <String>[];

    for (final i in indices) {
      if (i < _messages.length) {
        final msg = _messages[i];
        if (msg.firestoreId != null) firestoreIds.add(msg.firestoreId!);
      }
    }

    if (firestoreIds.isNotEmpty && !_isPrivate) {
      await ref.read(chatSessionProvider.notifier).deleteMessages(firestoreIds);
    }

    setState(() {
      for (final i in indices) {
        if (i < _messages.length) _messages.removeAt(i);
      }
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  // ── messaging ──────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_chatSession == null) {
      try {
        _chatSession = ref.read(geminiServiceProvider).startChat();
      } catch (e) {
        setState(() => _messages.add(_ChatMessage(
          text: 'Failed to initialize: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        )));
        return;
      }
    }

    _userMessageCount++;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
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
      if (_messages.isNotEmpty && !_messages.first.isUser) {
        chatNotifier.persistMessage(role: 'assistant', content: _messages.first.text);
      }
    }
    if (!_isPrivate) chatNotifier.persistMessage(role: 'user', content: text);

    try {
      int?   aiMessageIndex;
      final  aiMessageTime   = DateTime.now();
      final  responseStream  = _chatSession!.sendMessageStream(Content.text(text));
      final  responseBuffer  = StringBuffer();

      await for (final chunk in responseStream) {
        final chunkText = chunk.text;
        if (chunkText != null && chunkText.isNotEmpty) {
          responseBuffer.write(chunkText);
          setState(() {
            _isTyping = false;
            aiMessageIndex ??= _messages.length;
            if (aiMessageIndex == _messages.length) {
              _messages.add(_ChatMessage(text: chunkText, isUser: false, timestamp: aiMessageTime));
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
        chatNotifier.persistMessage(role: 'assistant', content: responseBuffer.toString());
      }

      const contextWindowSize = 20;
      final totalMessages = _messages.where((m) => !m.isError).length;
      if (!_isPrivate && totalMessages > contextWindowSize && totalMessages % 10 == 0) {
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
          text: 'Error: ${e.toString()}\n\nMake sure Firebase AI Logic (Gemini API) is enabled.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }

    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
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

      final summary = await ref.read(geminiServiceProvider).summarizeForContext(olderMessages);
      if (summary.isNotEmpty) {
        await ref.read(chatSessionProvider.notifier).saveContextSummary(summary);
      }
    } catch (e) { debugPrint('Context summarization failed: $e'); }
  }

  // ── journal ────────────────────────────────────────────────────────────────

  bool get _canSaveAsJournal => _userMessageCount >= 2;

  String _gatherMessagesAsText() {
    final msgs  = _messages.where((m) => !m.isError).skip(1).toList();
    final limit = msgs.length > 30 ? msgs.length - 30 : 0;
    final buf   = StringBuffer();
    for (int i = limit; i < msgs.length; i++) {
      buf.writeln('${msgs[i].isUser ? "User" : ref.read(activeVoiceProvider).name}: ${msgs[i].text}');
    }
    return buf.toString();
  }

  void _showSaveConfirmation() {
    final userMsgCount = _messages.where((m) => m.isUser && !m.isError).length;
    showModalBottomSheet(
      context: context,
      backgroundColor: _P.surface,
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
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _P.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (_isSummarizing) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(color: _P.teal),
                const SizedBox(height: 16),
                Text(
                  '${ref.read(activeVoiceProvider).name} is writing up your conversation...',
                  style: const TextStyle(color: _P.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _P.tealLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.note_add_rounded, size: 26, color: _P.teal),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Save as journal entry?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _P.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$userMsgCount messages · ${ref.read(activeVoiceProvider).name}',
                  style: const TextStyle(fontSize: 13, color: _P.textSecondary),
                ),
                const SizedBox(height: 22),
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
                      backgroundColor: _P.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save as Journal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: _P.textSecondary)),
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
      final result = await ref.read(geminiServiceProvider)
          .summarizeConversation(_gatherMessagesAsText());
      if (mounted) {
        setState(() { _isSummarizing = false; _savedAsJournal = true; });
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
          const SnackBar(
            content: Text('Could not summarize conversation'),
            backgroundColor: _P.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: Column(
          children: [
            _isSelectionMode ? _buildSelectionBar() : _buildAppBar(),
            Expanded(child: _buildMessagesList()),
            if (_isTyping) _buildTypingIndicator(),
            if (!_isSelectionMode) _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ── app bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        color: _P.surface,
        border: Border(bottom: BorderSide(color: _P.border, width: 1)),
      ),
      child: Row(
        children: [
          // Back arrow (journal mode only)
          if (widget.journalMode && Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_rounded, color: _P.textPrimary, size: 22),
            ),
            const SizedBox(width: 10),
          ],

          // Avatar
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_P.teal, _P.tealDark],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x261FB8A0), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),

          // Name + online
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.watch(activeVoiceProvider).name,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: _P.textPrimary, letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: _P.online, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('Online', style: TextStyle(fontSize: 11, color: _P.textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          // Right actions
          if (widget.journalMode)
            _JournalSaveButton(
              saved: _savedAsJournal,
              canSave: _canSaveAsJournal && !_savedAsJournal && !_isSummarizing,
              onTap: _showSaveConfirmation,
            )
          else ...[
            // Private toggle
            GestureDetector(
              onTap: () {
                ref.read(chatSessionProvider.notifier).togglePrivate();
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isPrivate ? _P.tealLight : _P.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _isPrivate ? _P.teal.withOpacity(0.4) : _P.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 13,
                      color: _isPrivate ? _P.teal : _P.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isPrivate ? 'Private' : 'Saved',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _isPrivate ? _P.teal : _P.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Journal save icon
            GestureDetector(
              onTap: _canSaveAsJournal && !_savedAsJournal && !_isSummarizing
                  ? _showSaveConfirmation : null,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _savedAsJournal
                      ? _P.tealLight
                      : _canSaveAsJournal ? _P.surfaceAlt : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _savedAsJournal ? Icons.check_circle_rounded : Icons.note_add_rounded,
                  size: 20,
                  color: _savedAsJournal
                      ? _P.teal
                      : _canSaveAsJournal ? _P.textPrimary : _P.textHint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── selection bar ──────────────────────────────────────────────────────────

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: const BoxDecoration(
        color: _P.surface,
        border: Border(bottom: BorderSide(color: _P.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _exitSelectionMode,
            color: _P.textPrimary,
            iconSize: 22,
          ),
          Text(
            '${_selectedIndices.length} selected',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _P.textPrimary),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectedIndices.isEmpty ? null : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _P.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Messages'),
                  content: Text(
                    'Delete ${_selectedIndices.length} message${_selectedIndices.length == 1 ? '' : 's'}? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: _P.error, foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await _deleteSelectedMessages();
            },
            icon: Icon(Icons.delete_outline_rounded, size: 20,
                color: _selectedIndices.isEmpty ? _P.textHint : _P.error),
            label: Text('Delete',
                style: TextStyle(
                  color: _selectedIndices.isEmpty ? _P.textHint : _P.error,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  // ── messages list ──────────────────────────────────────────────────────────

  Widget _buildMessagesList() {
    if (_isLoadingHistory) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _P.teal, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('Loading conversation…', style: TextStyle(color: _P.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message    = _messages[index];
        final showAvatar = index == 0 || _messages[index - 1].isUser != message.isUser;
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onLongPress: () {
            if (!_isSelectionMode) setState(() => _isSelectionMode = true);
            _toggleSelection(index);
          },
          onTap: _isSelectionMode ? () => _toggleSelection(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: isSelected ? _P.tealLight : Colors.transparent,
            child: Row(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 4),
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 20,
                      color: isSelected ? _P.teal : _P.textHint,
                    ),
                  ),
                Expanded(
                  child: _AnimatedMessageEntry(
                    key: ValueKey('${message.timestamp.microsecondsSinceEpoch}-${message.isUser}'),
                    isUser: message.isUser,
                    child: _MessageBubble(
                      message: message,
                      showAvatar: showAvatar,
                      voiceName: ref.read(activeVoiceProvider).name,
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

  // ── typing indicator ───────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          _AiAvatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _P.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: _P.border),
              boxShadow: const [BoxShadow(color: _P.shadow, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(controller: _typingController, delay: 0.0),
                const SizedBox(width: 5),
                _TypingDot(controller: _typingController, delay: 0.2),
                const SizedBox(width: 5),
                _TypingDot(controller: _typingController, delay: 0.4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── input area ─────────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    const pillRadius = BorderRadius.all(Radius.circular(26));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      // Explicit white container — never inherits dark scaffold color
      color: _P.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text field ──
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: pillRadius,
                boxShadow: _isInputFocused
                    ? [const BoxShadow(color: Color(0x281FB8A0), blurRadius: 12, offset: Offset(0, 3))]
                    : [const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              // Theme override: force Brightness.light so that the dark app
              // theme never bleeds fillColor or text color into this widget.
              child: Theme(
                data: ThemeData(
                  brightness: Brightness.light,
                  colorScheme: const ColorScheme.light(
                    primary: _P.teal,
                    onSurface: _P.textPrimary,
                  ),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: _P.inputBg,
                    hintStyle: TextStyle(color: _P.textHint, fontSize: 15),
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: pillRadius,
                      borderSide: BorderSide(color: _P.border, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: pillRadius,
                      borderSide: BorderSide(color: _P.border, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: pillRadius,
                      borderSide: BorderSide(color: _P.borderFocus, width: 1.5),
                    ),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _inputFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  // Always dark text on white — never depends on theme brightness
                  style: const TextStyle(
                    color: _P.textPrimary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                  cursorColor: _P.teal,
                  decoration: const InputDecoration(hintText: 'Message…'),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

// ── Send / Mic button ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: _canSend
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_P.teal, _P.tealDark],
                    )
                  : null,
              color: _canSend ? null : _P.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _canSend ? _P.teal : _P.border,
              ),
              boxShadow: _canSend
                  ? [const BoxShadow(color: Color(0x301FB8A0), blurRadius: 10, offset: Offset(0, 4))]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _canSend
                    ? _sendMessage
                    : () => Navigator.of(context).pushNamed(
                          AppRoutes.voiceChat,
                          arguments: widget.journalMode ? {'journalMode': true} : null,
                        ),
                borderRadius: BorderRadius.circular(22),
                child: Center(
                  child: Icon(
                    _canSend ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                    color: _canSend ? Colors.white : _P.textSecondary,
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

// ─── Reusable AI avatar ────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  final double size;
  const _AiAvatar({this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.teal, _P.tealDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [BoxShadow(color: Color(0x201FB8A0), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size * 0.46),
    );
  }
}

// ─── Journal save button ───────────────────────────────────────────────────────

class _JournalSaveButton extends StatelessWidget {
  final bool saved;
  final bool canSave;
  final VoidCallback onTap;
  const _JournalSaveButton({required this.saved, required this.canSave, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canSave ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: canSave && !saved
              ? const LinearGradient(colors: [_P.teal, _P.tealDark])
              : null,
          color: saved ? _P.tealLight : canSave ? null : _P.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: saved ? _P.teal : canSave ? Colors.transparent : _P.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? Icons.check_rounded : Icons.save_rounded,
              size: 14,
              color: saved ? _P.teal : canSave ? Colors.white : _P.textHint,
            ),
            const SizedBox(width: 5),
            Text(
              saved ? 'Saved' : 'Save',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: saved ? _P.teal : canSave ? Colors.white : _P.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool showAvatar;
  final String voiceName;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.voiceName,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left:  isUser ? 52 : 0,
        right: isUser ? 0  : 52,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser)
            showAvatar
                ? Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 2),
                    child: _AiAvatar(size: 28),
                  )
                : const SizedBox(width: 36),

          // Bubble
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_P.teal, _P.tealDark],
                        )
                      : null,
                  color: isUser ? null : message.isError ? _P.errorBg : _P.surface,
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(16),
                    topRight:    const Radius.circular(16),
                    bottomLeft:  Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4  : 16),
                  ),
                  border: Border.all(
                    color: isUser
                        ? _P.teal.withOpacity(0.3)
                        : message.isError
                            ? _P.error.withOpacity(0.25)
                            : _P.border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? const Color(0x201FB8A0)
                          : const Color(0x08000000),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender label for AI
                    if (!isUser && showAvatar) ...[
                      Text(
                        voiceName,
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _P.teal, letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: isUser
                            ? Colors.white
                            : message.isError ? _P.error : _P.textPrimary,
                        height: 1.5,
                        fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? Colors.white.withOpacity(0.65)
                            : _P.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // User avatar
          if (isUser)
            showAvatar
                ? Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryLight, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 14),
                    ),
                  )
                : const SizedBox(width: 36),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

// ─── Typing dot ────────────────────────────────────────────────────────────────

class _TypingDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _TypingDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = ((controller.value + delay) % 1.0);
        final opacity = 0.25 + 0.75 * (v < 0.5 ? v * 2 : (1 - v) * 2);
        final scale   = 0.85 + 0.15 * (v < 0.5 ? v * 2 : (1 - v) * 2);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: _P.teal.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ─── Animated message entry ────────────────────────────────────────────────────

class _AnimatedMessageEntry extends StatelessWidget {
  final Widget child;
  final bool isUser;

  const _AnimatedMessageEntry({super.key, required this.child, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(
            (1 - v) * (isUser ? 14.0 : -14.0),
            (1 - v) * 6.0,
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _ChatMessage {
  final String?   firestoreId;
  final String    text;
  final bool      isUser;
  final DateTime  timestamp;
  final bool      isError;

  const _ChatMessage({
    this.firestoreId,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}