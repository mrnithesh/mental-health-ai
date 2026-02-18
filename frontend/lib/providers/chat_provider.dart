// Phase 2: Chat Provider
// This file is disabled until AI chat feature is implemented

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chat state - placeholder for Phase 2
class ChatState {
  final String? conversationId;
  final bool isLoading;
  final String? error;

  ChatState({
    this.conversationId,
    this.isLoading = false,
    this.error,
  });
}

/// Placeholder provider - will be implemented in Phase 2
final chatProvider = StateProvider<ChatState>((ref) {
  return ChatState();
});
