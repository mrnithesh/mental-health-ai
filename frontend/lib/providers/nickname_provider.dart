import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import 'service_providers.dart';

final nicknameProvider =
    StateNotifierProvider<NicknameNotifier, String>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final geminiService = ref.watch(geminiServiceProvider);
  final notifier = NicknameNotifier(firestoreService, geminiService);

  // Listen to auth state changes and reload nickname when user changes
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      notifier.reload();
    } else {
      notifier.reset();
    }
  });

  return notifier;
});

class NicknameNotifier extends StateNotifier<String> {
  final FirestoreService _firestoreService;
  final GeminiService _geminiService;

  NicknameNotifier(this._firestoreService, this._geminiService)
      : super('Friend') {
    _load();
  }

  Future<void> _load() async {
    try {
      final nickname = await _firestoreService.getNickname();
      if (nickname.isNotEmpty && mounted) {
        state = nickname;
        _geminiService.setUserName(nickname);
        return;
      }
    } catch (e) {
      debugPrint('NicknameNotifier: load failed: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    final fallback = user?.displayName ?? 'Friend';
    if (mounted) {
      state = fallback;
      _geminiService.setUserName(fallback);
    }
  }

  void reload() => _load();

  void reset() {
    state = 'Friend';
    _geminiService.setUserName('Friend');
  }

  Future<void> setNickname(String nickname) async {
    if (nickname.trim().isEmpty) return;
    final trimmed = nickname.trim();
    state = trimmed;
    _geminiService.setUserName(trimmed);
    try {
      await _firestoreService.setNickname(trimmed);
    } catch (e) {
      debugPrint('NicknameNotifier: save failed: $e');
    }
  }
}
