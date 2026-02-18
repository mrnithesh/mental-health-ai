import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mood_model.dart';
import '../services/firestore_service.dart';
import 'service_providers.dart';

/// Stream of all moods
final moodsProvider = StreamProvider<List<MoodModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getMoods();
});

/// Today's mood provider
final todaysMoodProvider = FutureProvider<MoodModel?>((ref) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getTodaysMood();
});

/// Mood tracker state
class MoodTrackerState {
  final int selectedScore;
  final String? note;
  final bool isSaving;
  final bool hasSaved;
  final String? error;

  MoodTrackerState({
    this.selectedScore = 3,
    this.note,
    this.isSaving = false,
    this.hasSaved = false,
    this.error,
  });

  MoodTrackerState copyWith({
    int? selectedScore,
    String? note,
    bool? isSaving,
    bool? hasSaved,
    String? error,
  }) {
    return MoodTrackerState(
      selectedScore: selectedScore ?? this.selectedScore,
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      hasSaved: hasSaved ?? this.hasSaved,
      error: error,
    );
  }

  String get emoji {
    switch (selectedScore) {
      case 1:
        return '😢';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  String get label {
    switch (selectedScore) {
      case 1:
        return 'Terrible';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return 'Okay';
    }
  }
}

class MoodTrackerNotifier extends StateNotifier<MoodTrackerState> {
  final FirestoreService _firestoreService;

  MoodTrackerNotifier(this._firestoreService) : super(MoodTrackerState());

  /// Initialize with today's mood if exists
  Future<void> initialize() async {
    final todaysMood = await _firestoreService.getTodaysMood();
    if (todaysMood != null) {
      state = MoodTrackerState(
        selectedScore: todaysMood.score,
        note: todaysMood.note,
        hasSaved: true,
      );
    }
  }

  /// Update selected score
  void setScore(int score) {
    state = state.copyWith(selectedScore: score, hasSaved: false);
  }

  /// Update note
  void setNote(String? note) {
    state = state.copyWith(note: note, hasSaved: false);
  }

  /// Save mood
  Future<bool> save() async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      await _firestoreService.saveMood(
        score: state.selectedScore,
        emoji: state.emoji,
        note: state.note,
      );

      state = state.copyWith(isSaving: false, hasSaved: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = MoodTrackerState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final moodTrackerProvider =
    StateNotifierProvider<MoodTrackerNotifier, MoodTrackerState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return MoodTrackerNotifier(firestoreService);
});

// Phase 2: Mood Analysis with AI
// final moodAnalysisProvider = ...
