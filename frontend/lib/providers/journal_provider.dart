import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/journal_model.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
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

/// Search query state
final journalSearchProvider = StateProvider<String>((ref) => '');

/// Filtered journals based on search query
final filteredJournalsProvider = Provider<AsyncValue<List<JournalModel>>>((ref) {
  final journalsAsync = ref.watch(journalsProvider);
  final query = ref.watch(journalSearchProvider).toLowerCase().trim();

  return journalsAsync.whenData((journals) {
    if (query.isEmpty) return journals;
    return journals.where((j) {
      return j.title.toLowerCase().contains(query) ||
          j.content.toLowerCase().contains(query) ||
          j.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
  });
});

/// Journal editor state
class JournalEditorState {
  final String? journalId;
  final String title;
  final String content;
  final String? moodId;
  final String? aiInsight;
  final List<String> tags;
  final bool isSaving;
  final bool isGeneratingInsight;
  final bool hasChanges;
  final String? error;

  JournalEditorState({
    this.journalId,
    this.title = '',
    this.content = '',
    this.moodId,
    this.aiInsight,
    this.tags = const [],
    this.isSaving = false,
    this.isGeneratingInsight = false,
    this.hasChanges = false,
    this.error,
  });

  JournalEditorState copyWith({
    String? journalId,
    String? title,
    String? content,
    String? moodId,
    String? aiInsight,
    List<String>? tags,
    bool? isSaving,
    bool? isGeneratingInsight,
    bool? hasChanges,
    String? error,
  }) {
    return JournalEditorState(
      journalId: journalId ?? this.journalId,
      title: title ?? this.title,
      content: content ?? this.content,
      moodId: moodId ?? this.moodId,
      aiInsight: aiInsight ?? this.aiInsight,
      tags: tags ?? this.tags,
      isSaving: isSaving ?? this.isSaving,
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
      hasChanges: hasChanges ?? this.hasChanges,
      error: error,
    );
  }
}

class JournalEditorNotifier extends StateNotifier<JournalEditorState> {
  final FirestoreService _firestoreService;
  final GeminiService _geminiService;

  JournalEditorNotifier(this._firestoreService, this._geminiService)
      : super(JournalEditorState());

  Future<void> loadJournal(String journalId) async {
    final journal = await _firestoreService.getJournal(journalId);
    if (journal != null) {
      state = JournalEditorState(
        journalId: journal.id,
        title: journal.title,
        content: journal.content,
        moodId: journal.moodId,
        aiInsight: journal.aiInsight,
        tags: journal.tags,
      );
    }
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title, hasChanges: true);
  }

  void updateContent(String content) {
    state = state.copyWith(content: content, hasChanges: true);
  }

  void setMood(String? moodId) {
    if (state.moodId == moodId) {
      state = state.copyWith(moodId: '', hasChanges: true);
      return;
    }
    state = state.copyWith(moodId: moodId, hasChanges: true);
  }

  void toggleTag(String tag) {
    final current = List<String>.from(state.tags);
    if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.add(tag);
    }
    state = state.copyWith(tags: current, hasChanges: true);
  }

  Future<bool> save() async {
    if (state.content.trim().isEmpty) {
      state = state.copyWith(error: 'Please write something in your journal');
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      if (state.journalId != null) {
        await _firestoreService.updateJournal(
          id: state.journalId!,
          title: state.title,
          content: state.content,
          moodId: state.moodId,
          tags: state.tags,
        );
      } else {
        final journal = await _firestoreService.createJournal(
          title: state.title,
          content: state.content,
          moodId: state.moodId,
          tags: state.tags,
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

  Future<void> generateInsight() async {
    if (state.content.trim().isEmpty) {
      state = state.copyWith(error: 'Write something first so NILAA can reflect on it');
      return;
    }

    state = state.copyWith(isGeneratingInsight: true, error: null);

    try {
      final insight = await _geminiService.generateJournalInsight(state.content);
      state = state.copyWith(
        aiInsight: insight,
        isGeneratingInsight: false,
        hasChanges: true,
      );

      if (state.journalId != null) {
        await _firestoreService.updateJournal(
          id: state.journalId!,
          aiInsight: insight,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isGeneratingInsight: false,
        error: 'Could not generate insight right now',
      );
    }
  }

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

  void reset() {
    state = JournalEditorState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final journalEditorProvider =
    StateNotifierProvider<JournalEditorNotifier, JournalEditorState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final geminiService = ref.watch(geminiServiceProvider);
  return JournalEditorNotifier(firestoreService, geminiService);
});
