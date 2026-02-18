// Phase 2: Voice Chat with Gemini Live API
// This file is disabled until voice chat feature is implemented

// Placeholder export to prevent import errors
class GeminiLiveService {
  // Placeholder - will be implemented in Phase 2
}

enum GeminiConnectionState {
  disconnected,
  connecting,
  connected,
  listening,
  processing,
  speaking,
  error,
}

class TranscriptEvent {
  final String role;
  final String text;
  final bool isFinal;

  TranscriptEvent({
    required this.role,
    required this.text,
    required this.isFinal,
  });
}
