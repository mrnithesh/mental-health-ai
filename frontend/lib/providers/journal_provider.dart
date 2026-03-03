import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
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
final filteredJournalsProvider =
    Provider<AsyncValue<List<JournalModel>>>((ref) {
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

// ---------------------------------------------------------------------------
// Editor state
// ---------------------------------------------------------------------------

class JournalEditorState {
  final String? journalId;
  final String title;
  final String content;
  final String? moodId;
  final String? aiInsight;
  final String? summary;
  final List<String> tags;
  final bool isSaving;
  final bool isGeneratingInsight;
  final bool hasChanges;
  final String? error;

  // Mood auto-detection
  final String? suggestedMoodId;
  final bool isDetectingMood;

  // Guided template mode
  final String? templateId;
  final int templateStep;
  final List<String> templateResponses;

  JournalEditorState({
    this.journalId,
    this.title = '',
    this.content = '',
    this.moodId,
    this.aiInsight,
    this.summary,
    this.tags = const [],
    this.isSaving = false,
    this.isGeneratingInsight = false,
    this.hasChanges = false,
    this.error,
    this.suggestedMoodId,
    this.isDetectingMood = false,
    this.templateId,
    this.templateStep = 0,
    this.templateResponses = const [],
  });

  bool get isTemplateMode => templateId != null;

  JournalTemplate? get template =>
      templateId != null ? JournalTemplate.byId(templateId!) : null;

  String? get currentPrompt {
    final t = template;
    if (t == null || templateStep >= t.prompts.length) return null;
    return t.prompts[templateStep];
  }

  bool get isLastTemplateStep {
    final t = template;
    if (t == null) return true;
    return templateStep >= t.prompts.length - 1;
  }

  JournalEditorState copyWith({
    String? journalId,
    String? title,
    String? content,
    String? moodId,
    String? aiInsight,
    String? summary,
    List<String>? tags,
    bool? isSaving,
    bool? isGeneratingInsight,
    bool? hasChanges,
    String? error,
    String? suggestedMoodId,
    bool? isDetectingMood,
    String? templateId,
    int? templateStep,
    List<String>? templateResponses,
  }) {
    return JournalEditorState(
      journalId: journalId ?? this.journalId,
      title: title ?? this.title,
      content: content ?? this.content,
      moodId: moodId ?? this.moodId,
      aiInsight: aiInsight ?? this.aiInsight,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      isSaving: isSaving ?? this.isSaving,
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
      hasChanges: hasChanges ?? this.hasChanges,
      error: error,
      suggestedMoodId: suggestedMoodId ?? this.suggestedMoodId,
      isDetectingMood: isDetectingMood ?? this.isDetectingMood,
      templateId: templateId ?? this.templateId,
      templateStep: templateStep ?? this.templateStep,
      templateResponses: templateResponses ?? this.templateResponses,
    );
  }
}

// ---------------------------------------------------------------------------
// Editor notifier
// ---------------------------------------------------------------------------

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
        summary: journal.summary,
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

  // -- Mood auto-detection --

  Future<void> autoDetectMood() async {
    if (state.content.trim().isEmpty) return;

    state = state.copyWith(isDetectingMood: true);
    try {
      final score = await _geminiService.detectMood(state.content);
      if (score != null) {
        state = state.copyWith(
          suggestedMoodId: score.toString(),
          isDetectingMood: false,
        );
      } else {
        state = state.copyWith(isDetectingMood: false);
      }
    } catch (_) {
      state = state.copyWith(isDetectingMood: false);
    }
  }

  void acceptSuggestedMood() {
    if (state.suggestedMoodId != null) {
      state = state.copyWith(
        moodId: state.suggestedMoodId,
        suggestedMoodId: '',
        hasChanges: true,
      );
    }
  }

  void dismissSuggestedMood() {
    state = state.copyWith(suggestedMoodId: '');
  }

  // -- Save with auto-summary --

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

      // Auto-generate summary in background for long entries
      if (state.content.length > 200 &&
          (state.summary == null || state.summary!.isEmpty)) {
        _generateSummaryInBackground();
      }

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<void> _generateSummaryInBackground() async {
    try {
      final summaryText =
          await _geminiService.generateJournalSummary(state.content);
      if (summaryText.isNotEmpty && state.journalId != null) {
        await _firestoreService.updateJournal(
          id: state.journalId!,
          summary: summaryText,
        );
        state = state.copyWith(summary: summaryText);
      }
    } catch (e) {
      debugPrint('Auto-summary failed: $e');
    }
  }

  // -- AI insight --

  Future<void> generateInsight() async {
    if (state.content.trim().isEmpty) {
      state = state.copyWith(
          error: 'Write something first so NILAA can reflect on it');
      return;
    }

    state = state.copyWith(isGeneratingInsight: true, error: null);

    try {
      final insight =
          await _geminiService.generateJournalInsight(state.content);
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

  // -- Guided templates --

  void startTemplate(String templateId) {
    final t = JournalTemplate.byId(templateId);
    if (t == null) return;
    state = JournalEditorState(
      templateId: templateId,
      templateStep: 0,
      templateResponses: List.filled(t.prompts.length, ''),
      tags: [templateId],
    );
  }

  void updateTemplateResponse(String text) {
    final responses = List<String>.from(state.templateResponses);
    if (state.templateStep < responses.length) {
      responses[state.templateStep] = text;
    }
    state = state.copyWith(templateResponses: responses, hasChanges: true);
  }

  void nextTemplateStep() {
    final t = state.template;
    if (t == null) return;

    if (state.templateStep < t.prompts.length - 1) {
      state = state.copyWith(templateStep: state.templateStep + 1);
    } else {
      _finishTemplate();
    }
  }

  void previousTemplateStep() {
    if (state.templateStep > 0) {
      state = state.copyWith(templateStep: state.templateStep - 1);
    }
  }

  void _finishTemplate() {
    final t = state.template;
    if (t == null) return;

    final buffer = StringBuffer();
    for (int i = 0; i < t.prompts.length; i++) {
      final response = i < state.templateResponses.length
          ? state.templateResponses[i].trim()
          : '';
      if (response.isNotEmpty) {
        buffer.writeln('## ${t.prompts[i]}');
        buffer.writeln(response);
        buffer.writeln();
      }
    }

    state = JournalEditorState(
      title: t.name,
      content: buffer.toString().trim(),
      tags: [t.id],
      hasChanges: true,
    );
  }

  void prefill({String? title, String? content, List<String>? tags}) {
    state = JournalEditorState(
      title: title ?? '',
      content: content ?? '',
      tags: tags ?? [],
      hasChanges: content?.isNotEmpty == true,
    );
  }

  // -- Delete / Reset / Error --

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
