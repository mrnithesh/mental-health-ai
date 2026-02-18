import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.journalId != null) {
        ref.read(journalEditorProvider.notifier).loadJournal(widget.journalId!);
      } else {
        ref.read(journalEditorProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final success = await ref.read(journalEditorProvider.notifier).save();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal saved')),
      );
    }
  }

  Future<void> _generateInsight() async {
    await ref.read(journalEditorProvider.notifier).generateInsight();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Journal'),
        content: const Text(
            'Are you sure you want to delete this journal entry? This cannot be undone.'),
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
      final success = await ref.read(journalEditorProvider.notifier).delete();
      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(journalEditorProvider);
    final isEditing = widget.journalId != null;

    // Sync content controller with state
    if (_contentController.text != editorState.content) {
      _contentController.text = editorState.content;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: editorState.content.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Journal' : 'New Journal'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              tooltip: 'Delete',
            ),
          TextButton(
            onPressed: editorState.isSaving ? null : _save,
            child: editorState.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Content editor
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date display
                  Text(
                    _formatDate(DateTime.now()),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Journal content
                  TextField(
                    controller: _contentController,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 10,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Write your thoughts...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                    onChanged: (value) {
                      ref
                          .read(journalEditorProvider.notifier)
                          .updateContent(value);
                    },
                  ),

                  // AI Insight section - Phase 2
                  // if (editorState.aiInsight != null) ...[
                  //   const SizedBox(height: 24),
                  //   const Divider(),
                  //   const SizedBox(height: 16),
                  //   _InsightCard(insight: editorState.aiInsight!),
                  // ],
                ],
              ),
            ),
          ),

          // Error banner
          if (editorState.error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      editorState.error!,
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        ref.read(journalEditorProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Character count
                  Text(
                    '${editorState.content.length} characters',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // AI insight button - Phase 2
                  // OutlinedButton.icon(
                  //   onPressed: editorState.isGeneratingInsight ||
                  //           editorState.content.trim().isEmpty
                  //       ? null
                  //       : _generateInsight,
                  //   icon: const Icon(Icons.auto_awesome, size: 18),
                  //   label: const Text('Get AI Insight'),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _InsightCard extends StatelessWidget {
  final String insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Reflection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
