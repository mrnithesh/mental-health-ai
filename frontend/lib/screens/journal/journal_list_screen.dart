import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/journal_model.dart';
import '../../providers/journal_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/animated_list_item.dart';
import 'journal_editor_screen.dart' show JournalEditorArgs;

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        ref.read(journalSearchProvider.notifier).state = '';
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  Future<void> _deleteJournal(JournalModel journal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this journal entry? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteJournal(journal.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Entry deleted'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showNewEntrySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _NewEntrySheet(
        onFreeWrite: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(context, AppRoutes.journalEditor);
        },
        onTemplate: (templateId) {
          Navigator.pop(ctx);
          Navigator.pushNamed(
            context,
            AppRoutes.journalEditor,
            arguments: JournalEditorArgs(templateId: templateId),
          );
        },
        onChatJournal: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(
            context,
            AppRoutes.chat,
            arguments: {'journalMode': true},
          );
        },
        onVoiceJournal: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(
            context,
            AppRoutes.voiceChat,
            arguments: {'journalMode': true},
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(filteredJournalsProvider);
    final tt = Theme.of(context).textTheme;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Journal', style: tt.headlineMedium?.copyWith(color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Your thoughts, your space',
                            style: tt.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderButton(
                      icon: _searchOpen
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      onTap: _toggleSearch,
                    ),
                    const SizedBox(width: 8),
                    _HeaderButton(
                      icon: Icons.add_rounded,
                      filled: true,
                      onTap: () => _showNewEntrySheet(context),
                    ),
                  ],
                ),
              ),

              // Search bar
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _searchOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          style: TextStyle(color: AppColors.textPrimary),
                          onChanged: (v) =>
                              ref.read(journalSearchProvider.notifier).state = v,
                          decoration: InputDecoration(
                            hintText: 'Search entries...',
                            hintStyle: TextStyle(color: AppColors.textTertiary),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: AppColors.surfaceVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: AppColors.surfaceVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 12),

              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: ref.watch(journalFilterProvider) == 'all',
                      onTap: () => ref.read(journalFilterProvider.notifier).state = 'all',
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Highlights',
                      icon: Icons.star_rounded,
                      isSelected: ref.watch(journalFilterProvider) == 'highlights',
                      onTap: () => ref.read(journalFilterProvider.notifier).state = 'highlights',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Journal list
              Expanded(
                child: journalsAsync.when(
                  data: (journals) {
                    if (journals.isEmpty) {
                      if (ref.watch(journalSearchProvider).isNotEmpty) {
                        return _buildNoResults(tt);
                      }
                      if (ref.watch(journalFilterProvider) == 'highlights') {
                        return _buildEmptyHighlights(tt);
                      }
                      return const _EmptyState();
                    }
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: journals.length,
                      itemBuilder: (context, index) {
                        final journal = journals[index];
                        return AnimatedListItem(
                          index: index,
                          child: Dismissible(
                            key: ValueKey(journal.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              _deleteJournal(journal);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                              ),
                            ),
                            child: _JournalCard(
                              journal: journal,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.journalEditor,
                                arguments: journal.id,
                              ),
                              onToggleHighlight: () {
                                ref.read(firestoreServiceProvider).updateJournal(
                                  id: journal.id,
                                  isHighlight: !journal.isHighlight,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load journals',
                            style: tt.titleSmall?.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ref.refresh(journalsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHighlights(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline_rounded,
              size: 48, color: AppColors.accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No highlights yet',
              style: tt.titleSmall?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Star the entries that matter most.\nThey\'ll live here.',
            style: tt.bodySmall?.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('No matching entries', style: tt.titleSmall?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: tt.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header button
// ---------------------------------------------------------------------------

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          color: filled ? Colors.white : AppColors.primary,
          size: 20,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Start Journaling',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Write down your thoughts and feelings.\nNILAA can reflect on them with you.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.journalEditor),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Write First Entry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Journal card
// ---------------------------------------------------------------------------

class _JournalCard extends StatelessWidget {
  final JournalModel journal;
  final VoidCallback onTap;
  final VoidCallback onToggleHighlight;

  const _JournalCard({
    required this.journal,
    required this.onTap,
    required this.onToggleHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');
    final moodEmoji = _moodEmoji(journal.moodId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.surfaceVariant,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: journal.isHighlight
                          ? AppColors.accent
                          : journal.aiInsight != null
                              ? AppColors.secondary
                              : AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.md),
                        bottomLeft: Radius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              if (moodEmoji != null) ...[
                                Text(moodEmoji, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  journal.displayTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: onToggleHighlight,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    journal.isHighlight
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 18,
                                    color: journal.isHighlight
                                        ? AppColors.accent
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Content preview (AI summary if available)
                          if (journal.summary != null &&
                              journal.summary!.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 11, color: AppColors.textTertiary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    journal.summary!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else if (journal.title.isNotEmpty)
                            Text(
                              journal.preview,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 10),
                          // Meta row
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(journal.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeFormat.format(journal.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${journal.wordCount} words',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const Spacer(),
                              if (journal.tags.contains('chat-journal'))
                                _OriginBadge(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: 'From Chat',
                                  color: AppColors.primary,
                                ),
                              if (journal.tags.contains('voice-journal'))
                                _OriginBadge(
                                  icon: Icons.mic_rounded,
                                  label: 'From Voice',
                                  color: AppColors.secondary,
                                ),
                              if (journal.aiInsight != null)
                                _OriginBadge(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'Insight',
                                  color: AppColors.secondary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _moodEmoji(String? moodId) {
    if (moodId == null || moodId.isEmpty) return null;
    final score = int.tryParse(moodId);
    if (score == null) return null;
    return MoodEmojis.scoreToEmoji[score];
  }
}

// ---------------------------------------------------------------------------
// New entry bottom sheet with template picker
// ---------------------------------------------------------------------------

class _NewEntrySheet extends StatelessWidget {
  final VoidCallback onFreeWrite;
  final ValueChanged<String> onTemplate;
  final VoidCallback onChatJournal;
  final VoidCallback onVoiceJournal;

  const _NewEntrySheet({
    required this.onFreeWrite,
    required this.onTemplate,
    required this.onChatJournal,
    required this.onVoiceJournal,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'New Entry',
                style: tt.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              _SheetOption(
                icon: Icons.edit_rounded,
                iconColor: AppColors.primary,
                title: 'Free Write',
                subtitle: 'Write anything on your mind',
                onTap: onFreeWrite,
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.surfaceVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Guided by NILAA',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.surfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              ...JournalTemplate.all.map((template) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SheetOption(
                      icon: null,
                      emoji: template.icon,
                      iconColor: AppColors.secondary,
                      title: template.name,
                      subtitle:
                          '${template.description} -- ${template.prompts.length} prompts',
                      onTap: () => onTemplate(template.id),
                    ),
                  )),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.surfaceVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'From a Conversation',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.surfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _SheetOption(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: AppColors.primary,
                title: 'Chat & Journal',
                subtitle: 'Text with NILAA, then save it as a journal',
                onTap: onChatJournal,
              ),
              const SizedBox(height: 8),
              _SheetOption(
                icon: Icons.mic_rounded,
                iconColor: AppColors.secondary,
                title: 'Voice & Journal',
                subtitle: 'Talk to NILAA by voice, then save it',
                onTap: onVoiceJournal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    this.icon,
    this.emoji,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 22))
              else if (icon != null)
                Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Origin badge (From Chat / From Voice / Insight)
// ---------------------------------------------------------------------------

class _OriginBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _OriginBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: isSelected ? AppColors.primary : AppColors.textTertiary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
