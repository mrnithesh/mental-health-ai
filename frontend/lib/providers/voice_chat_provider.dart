// Phase 2: Voice Chat Provider
// This file is disabled until voice chat feature is implemented

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Voice chat state - placeholder for Phase 2
class VoiceChatState {
  final VoiceChatConnectionState connectionState;
  final bool isRecording;
  final String? error;

  VoiceChatState({
    this.connectionState = VoiceChatConnectionState.disconnected,
    this.isRecording = false,
    this.error,
  });
}

enum VoiceChatConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Placeholder provider - will be implemented in Phase 2
final voiceChatProvider = StateProvider<VoiceChatState>((ref) {
  return VoiceChatState();
});
