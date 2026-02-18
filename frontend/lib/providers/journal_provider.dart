import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/journal_model.dart';
import '../services/firestore_service.dart';
import 'service_providers.dart';

/// Stream of all journals
final journalsProvider = StreamProvider<List<JournalModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getJournals();
});

/// Single journal provider
final journalProvider =
    FutureProvider.family<JournalModel?, String>((ref, journalId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getJournal(journalId);
});

/// Journal editor state
class JournalEditorState {
  final String? journalId;
  final String content;
  final String? moodId;
  final String? aiInsight;
  final bool isSaving;
  final bool isGeneratingInsight;
  final bool hasChanges;
  final String? error;

  JournalEditorState({
    this.journalId,
    this.content = '',
    this.moodId,
    this.aiInsight,
    this.isSaving = false,
    this.isGeneratingInsight = false,
    this.hasChanges = false,
    this.error,
  });

  JournalEditorState copyWith({
    String? journalId,
    String? content,
    String? moodId,
    String? aiInsight,
    bool? isSaving,
    bool? isGeneratingInsight,
    bool? hasChanges,
    String? error,
  }) {
    return JournalEditorState(
      journalId: journalId ?? this.journalId,
      content: content ?? this.content,
      moodId: moodId ?? this.moodId,
      aiInsight: aiInsight ?? this.aiInsight,
      isSaving: isSaving ?? this.isSaving,
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
      hasChanges: hasChanges ?? this.hasChanges,
      error: error,
    );
  }
}

class JournalEditorNotifier extends StateNotifier<JournalEditorState> {
  final FirestoreService _firestoreService;

  JournalEditorNotifier(this._firestoreService) : super(JournalEditorState());

  /// Load existing journal for editing
  Future<void> loadJournal(String journalId) async {
    final journal = await _firestoreService.getJournal(journalId);
    if (journal != null) {
      state = JournalEditorState(
        journalId: journal.id,
        content: journal.content,
        moodId: journal.moodId,
        aiInsight: journal.aiInsight,
      );
    }
  }

  /// Update content
  void updateContent(String content) {
    state = state.copyWith(content: content, hasChanges: true);
  }

  /// Set mood
  void setMood(String? moodId) {
    state = state.copyWith(moodId: moodId, hasChanges: true);
  }

  /// Save journal
  Future<bool> save() async {
    if (state.content.trim().isEmpty) {
      state = state.copyWith(error: 'Please write something in your journal');
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      if (state.journalId != null) {
        // Update existing journal
        await _firestoreService.updateJournal(
          id: state.journalId!,
          content: state.content,
          moodId: state.moodId,
        );
      } else {
        // Create new journal
        final journal = await _firestoreService.createJournal(
          content: state.content,
          moodId: state.moodId,
        );
        state = state.copyWith(journalId: journal.id);
      }

      state = state.copyWith(isSaving: false, hasChanges: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  /// Generate AI insight - Phase 2
  Future<void> generateInsight() async {
    // TODO: Implement in Phase 2 with API service
    state = state.copyWith(error: 'AI insights coming soon!');
  }

  /// Delete journal
  Future<bool> delete() async {
    if (state.journalId == null) return true;

    try {
      await _firestoreService.deleteJournal(state.journalId!);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = JournalEditorState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final journalEditorProvider =
    StateNotifierProvider<JournalEditorNotifier, JournalEditorState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return JournalEditorNotifier(firestoreService);
});
