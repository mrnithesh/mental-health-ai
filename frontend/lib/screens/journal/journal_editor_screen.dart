import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/journal_provider.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  final String? journalId;

  const JournalEditorScreen({super.key, this.journalId});

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();
  bool _insightExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.journalId != null) {
        ref
            .read(journalEditorProvider.notifier)
            .loadJournal(widget.journalId!);
      } else {
        ref.read(journalEditorProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _syncControllers(JournalEditorState editorState) {
    if (_titleController.text != editorState.title) {
      _titleController.text = editorState.title;
      _titleController.selection = TextSelection.fromPosition(
        TextPosition(offset: editorState.title.length),
      );
    }
    if (_contentController.text != editorState.content) {
      _contentController.text = editorState.content;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: editorState.content.length),
      );
    }
  }

  Future<void> _save() async {
    final success = await ref.read(journalEditorProvider.notifier).save();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Journal saved'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Delete Entry'),
        content: const Text(
            'Are you sure you want to delete this entry? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(journalEditorProvider.notifier).delete();
      if (success && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(journalEditorProvider);
    final isEditing = widget.journalId != null;
    final tt = Theme.of(context).textTheme;

    _syncControllers(editorState);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDF5F0),
              AppColors.background,
              Color(0xFFF5F8F5),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom app bar
              _buildAppBar(editorState, isEditing, tt),

              // Gradient accent strip
              Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date
                      Text(
                        _formatDate(editorState.journalId != null
                            ? DateTime.now()
                            : DateTime.now()),
                        style: tt.bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 16),

                      // Title field
                      TextField(
                        controller: _titleController,
                        maxLength: AppConstants.journalTitleMaxLength,
                        textCapitalization: TextCapitalization.sentences,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Give it a title...',
                          hintStyle: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => ref
                            .read(journalEditorProvider.notifier)
                            .updateTitle(v),
                      ),
                      const SizedBox(height: 4),

                      // Mood picker
                      _MoodPicker(
                        selectedMoodId: editorState.moodId,
                        onSelect: (id) => ref
                            .read(journalEditorProvider.notifier)
                            .setMood(id),
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      Divider(
                        color: AppColors.surfaceVariant,
                        height: 1,
                      ),
                      const SizedBox(height: 16),

                      // Content field
                      TextField(
                        controller: _contentController,
                        focusNode: _contentFocus,
                        maxLines: null,
                        minLines: 10,
                        maxLength: AppConstants.journalContentMaxLength,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        style: tt.bodyLarge?.copyWith(
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write your thoughts...',
                          hintStyle: TextStyle(
                            color: AppColors.textTertiary.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => ref
                            .read(journalEditorProvider.notifier)
                            .updateContent(v),
                      ),

                      // AI Insight card
                      if (editorState.aiInsight != null &&
                          editorState.aiInsight!.isNotEmpty)
                        _InsightCard(
                          insight: editorState.aiInsight!,
                          expanded: _insightExpanded,
                          onToggle: () => setState(
                              () => _insightExpanded = !_insightExpanded),
                        ),
                    ],
                  ),
                ),
              ),

              // Error bar
              if (editorState.error != null) _ErrorBar(editorState: editorState, ref: ref),

              // Bottom toolbar
              _BottomToolbar(
                editorState: editorState,
                onGenerateInsight: () =>
                    ref.read(journalEditorProvider.notifier).generateInsight(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
      JournalEditorState editorState, bool isEditing, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            color: AppColors.textPrimary,
          ),
          Expanded(
            child: Text(
              isEditing ? 'Edit Entry' : 'New Entry',
              style: tt.titleMedium?.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
              color: AppColors.textSecondary,
              tooltip: 'Delete',
            ),
          _SaveButton(
            isSaving: editorState.isSaving,
            hasChanges: editorState.hasChanges,
            onSave: _save,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];

    if (dateOnly == today) {
      return 'Today, ${months[date.month - 1]} ${date.day}';
    }
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${months[date.month - 1]} ${date.day}';
    }
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ---------------------------------------------------------------------------
// Save button
// ---------------------------------------------------------------------------

class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final bool hasChanges;
  final VoidCallback onSave;

  const _SaveButton({
    required this.isSaving,
    required this.hasChanges,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: TextButton(
          onPressed: isSaving ? null : onSave,
          style: TextButton.styleFrom(
            foregroundColor: hasChanges ? AppColors.primary : AppColors.textTertiary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: hasChanges ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mood picker
// ---------------------------------------------------------------------------

class _MoodPicker extends StatelessWidget {
  final String? selectedMoodId;
  final ValueChanged<String> onSelect;

  const _MoodPicker({required this.selectedMoodId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MoodEmojis.scoreToEmoji.entries.map((entry) {
          final id = entry.key.toString();
          final isSelected = selectedMoodId == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.value, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      MoodEmojis.scoreToLabel[entry.key] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Insight card
// ---------------------------------------------------------------------------

class _InsightCard extends StatelessWidget {
  final String insight;
  final bool expanded;
  final VoidCallback onToggle;

  const _InsightCard({
    required this.insight,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'NILAA\'s Reflection',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Text(
                  insight,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error bar
// ---------------------------------------------------------------------------

class _ErrorBar extends StatelessWidget {
  final JournalEditorState editorState;
  final WidgetRef ref;

  const _ErrorBar({required this.editorState, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              editorState.error!,
              style:
                  const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () =>
                ref.read(journalEditorProvider.notifier).clearError(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom toolbar
// ---------------------------------------------------------------------------

class _BottomToolbar extends StatelessWidget {
  final JournalEditorState editorState;
  final VoidCallback onGenerateInsight;

  const _BottomToolbar({
    required this.editorState,
    required this.onGenerateInsight,
  });

  @override
  Widget build(BuildContext context) {
    final wordCount = editorState.content.trim().isEmpty
        ? 0
        : editorState.content.trim().split(RegExp(r'\s+')).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '$wordCount words',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(width: 12),
            Text(
              '${editorState.content.length} chars',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const Spacer(),
            // Ask NILAA button
            _AskNilaaButton(
              isGenerating: editorState.isGeneratingInsight,
              hasContent: editorState.content.trim().isNotEmpty,
              onTap: onGenerateInsight,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ask NILAA button
// ---------------------------------------------------------------------------

class _AskNilaaButton extends StatelessWidget {
  final bool isGenerating;
  final bool hasContent;
  final VoidCallback onTap;

  const _AskNilaaButton({
    required this.isGenerating,
    required this.hasContent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGenerating ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: hasContent && !isGenerating
              ? const LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondaryDark],
                )
              : null,
          color: hasContent && !isGenerating
              ? null
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGenerating)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              )
            else
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: hasContent ? Colors.white : AppColors.textTertiary,
              ),
            const SizedBox(width: 6),
            Text(
              isGenerating ? 'Reflecting...' : 'Ask NILAA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isGenerating
                    ? AppColors.secondary
                    : hasContent
                        ? Colors.white
                        : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
