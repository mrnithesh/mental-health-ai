import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';
import 'service_providers.dart';

final voicePreferenceProvider =
    StateNotifierProvider<VoicePreferenceNotifier, String>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final geminiService = ref.watch(geminiServiceProvider);
  return VoicePreferenceNotifier(firestoreService, geminiService);
});

class VoicePreferenceNotifier extends StateNotifier<String> {
  final FirestoreService _firestoreService;
  final GeminiService _geminiService;

  VoicePreferenceNotifier(this._firestoreService, this._geminiService)
      : super(AmigoVoice.defaultVoiceId) {
    _load();
  }

  Future<void> _load() async {
    try {
      final voiceId = await _firestoreService.getPreferredVoice();
      if (mounted) {
        state = voiceId;
        _applyVoice(voiceId);
      }
    } catch (e) {
      debugPrint('VoicePreferenceNotifier: load failed: $e');
    }
  }

  Future<void> setVoice(String voiceId) async {
    state = voiceId;
    _applyVoice(voiceId);
    try {
      await _firestoreService.setPreferredVoice(voiceId);
    } catch (e) {
      debugPrint('VoicePreferenceNotifier: save failed: $e');
    }
  }

  void _applyVoice(String voiceId) {
    final voice = AmigoVoice.byId(voiceId);
    if (voice != null && voice.isAvailable && voice.voiceCode.isNotEmpty) {
      _geminiService.setVoice(
        voice.voiceCode,
        personality: voice.personality,
        voiceName: voice.name,
      );
    }
  }
}

/// Convenience provider to get the active AmigoVoice object
final activeVoiceProvider = Provider<AmigoVoice>((ref) {
  final voiceId = ref.watch(voicePreferenceProvider);
  return AmigoVoice.byId(voiceId) ?? AmigoVoice.defaultVoice;
});
