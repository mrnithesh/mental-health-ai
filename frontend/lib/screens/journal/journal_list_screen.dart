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
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.journalEditor,
                      ),
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

              const SizedBox(height: 16),

              // Journal list
              Expanded(
                child: journalsAsync.when(
                  data: (journals) {
                    if (journals.isEmpty) {
                      if (ref.watch(journalSearchProvider).isNotEmpty) {
                        return _buildNoResults(tt);
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

  const _JournalCard({required this.journal, required this.onTap});

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
                      color: journal.aiInsight != null
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
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Content preview
                          if (journal.title.isNotEmpty)
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
                              if (journal.aiInsight != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          size: 11,
                                          color: AppColors.secondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Insight',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
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
