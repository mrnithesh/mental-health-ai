import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/mood_provider.dart';

class MoodTrackerScreen extends ConsumerStatefulWidget {
  const MoodTrackerScreen({super.key});

  @override
  ConsumerState<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends ConsumerState<MoodTrackerScreen> {
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moodTrackerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    final success = await ref.read(moodTrackerProvider.notifier).save();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mood saved!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodTrackerProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How are you\nfeeling?',
                  style: tt.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // Emoji display
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    moodState.emoji,
                    key: ValueKey(moodState.selectedScore),
                    style: const TextStyle(fontSize: 72),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    moodState.label,
                    key: ValueKey(moodState.label),
                    style: tt.titleLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Mood selector
              _MoodSelector(
                selectedScore: moodState.selectedScore,
                onScoreChanged: (score) {
                  ref.read(moodTrackerProvider.notifier).setScore(score);
                },
              ),
              const SizedBox(height: 28),

              // Note input
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.surfaceVariant),
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 40),
                      child: Icon(Icons.edit_note_rounded,
                          color: AppColors.textTertiary, size: 20),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (value) {
                    ref.read(moodTrackerProvider.notifier).setNote(value);
                  },
                ),
              ),

              if (moodState.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    moodState.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],

              const Spacer(),

              ElevatedButton(
                onPressed: moodState.isSaving ? null : _saveMood,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: moodState.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(moodState.hasSaved ? 'Update Mood' : 'Save Mood'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final int selectedScore;
  final ValueChanged<int> onScoreChanged;

  const _MoodSelector({
    required this.selectedScore,
    required this.onScoreChanged,
  });

  static const _moods = [
    (1, '😢', 'Terrible', AppColors.moodTerrible),
    (2, '😕', 'Bad', AppColors.moodBad),
    (3, '😐', 'Okay', AppColors.moodNeutral),
    (4, '🙂', 'Good', AppColors.moodGood),
    (5, '😄', 'Excellent', AppColors.moodExcellent),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _moods.map((mood) {
        final (score, emoji, label, color) = mood;
        final isSelected = selectedScore == score;

        return GestureDetector(
          onTap: () => onScoreChanged(score),
          child: AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? color : AppColors.surfaceVariant,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Text(
                    emoji,
                    style: TextStyle(fontSize: isSelected ? 34 : 26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? color : AppColors.textTertiary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
