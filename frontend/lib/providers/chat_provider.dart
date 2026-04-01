import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import 'service_providers.dart';

/// A message typed on the home screen quick-chat, to be auto-sent when Chat tab opens
final pendingChatMessageProvider = StateProvider<String?>((ref) => null);

/// Stream of all conversations for the current user
final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getConversations();
});

/// Chat session state — tracks the active conversation and private mode
class ChatSessionState {
  final String? conversationId;
  final bool isPrivate;

  const ChatSessionState({this.conversationId, this.isPrivate = false});

  ChatSessionState copyWith({String? conversationId, bool? isPrivate}) {
    return ChatSessionState(
      conversationId: conversationId ?? this.conversationId,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}

class ChatSessionNotifier extends StateNotifier<ChatSessionState> {
  final FirestoreService _firestoreService;

  ChatSessionNotifier(this._firestoreService)
      : super(const ChatSessionState());

  /// Create a new conversation in Firestore (non-private mode only)
  Future<String?> createConversation({String? title}) async {
    if (state.isPrivate) return null;
    try {
      final conversation =
          await _firestoreService.createConversation(title: title);
      state = state.copyWith(conversationId: conversation.id);
      return conversation.id;
    } catch (e) {
      debugPrint('ChatSessionNotifier: createConversation failed: $e');
      return null;
    }
  }

  /// Resume an existing conversation
  void resumeConversation(String conversationId) {
    state = ChatSessionState(conversationId: conversationId, isPrivate: false);
  }

  /// Toggle private chat mode
  void togglePrivate() {
    state = ChatSessionState(
      conversationId: state.isPrivate ? state.conversationId : null,
      isPrivate: !state.isPrivate,
    );
  }

  void setPrivate(bool value) {
    if (value == state.isPrivate) return;
    state = ChatSessionState(
      conversationId: value ? null : state.conversationId,
      isPrivate: value,
    );
  }

  /// Persist a message to Firestore (non-private mode only)
  Future<void> persistMessage({
    required String role,
    required String content,
  }) async {
    if (state.isPrivate || state.conversationId == null) return;
    try {
      await _firestoreService.addMessage(
        conversationId: state.conversationId!,
        role: role,
        content: content,
      );
    } catch (e) {
      debugPrint('ChatSessionNotifier: persistMessage failed: $e');
    }
  }

  /// Update the conversation title (auto-generated from first message)
  Future<void> updateTitle(String title) async {
    if (state.isPrivate || state.conversationId == null) return;
    try {
      await _firestoreService.updateConversationTitle(
        state.conversationId!,
        title,
      );
    } catch (e) {
      debugPrint('ChatSessionNotifier: updateTitle failed: $e');
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    try {
      await _firestoreService.deleteConversation(id);
      if (state.conversationId == id) {
        state = const ChatSessionState();
      }
    } catch (e) {
      debugPrint('ChatSessionNotifier: deleteConversation failed: $e');
    }
  }

  /// Delete specific messages from the active conversation
  Future<void> deleteMessages(List<String> messageIds) async {
    if (state.isPrivate || state.conversationId == null) return;
    try {
      await _firestoreService.deleteMessages(
        conversationId: state.conversationId!,
        messageIds: messageIds,
      );
    } catch (e) {
      debugPrint('ChatSessionNotifier: deleteMessages failed: $e');
    }
  }

  /// Save a context summary for the conversation
  Future<void> saveContextSummary(String summary) async {
    if (state.isPrivate || state.conversationId == null) return;
    try {
      await _firestoreService.updateConversationContextSummary(
        state.conversationId!,
        summary,
      );
    } catch (e) {
      debugPrint('ChatSessionNotifier: saveContextSummary failed: $e');
    }
  }

  /// Reset to a fresh state (new chat)
  void reset() {
    state = ChatSessionState(isPrivate: state.isPrivate);
  }
}

final chatSessionProvider =
    StateNotifierProvider<ChatSessionNotifier, ChatSessionState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ChatSessionNotifier(firestoreService);
});
