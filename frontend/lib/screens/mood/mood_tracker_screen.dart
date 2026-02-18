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
        const SnackBar(content: Text('Mood saved!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodTrackerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('How are you feeling?'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Emoji display
              Center(
                child: Text(
                  moodState.emoji,
                  style: const TextStyle(fontSize: 80),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  moodState.label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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
              const SizedBox(height: 32),

              // Note input
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (value) {
                  ref.read(moodTrackerProvider.notifier).setNote(value);
                },
              ),
              const SizedBox(height: 16),

              // Error display
              if (moodState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    moodState.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),

              const Spacer(),

              // Save button
              ElevatedButton(
                onPressed: moodState.isSaving ? null : _saveMood,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  emoji,
                  style: TextStyle(
                    fontSize: isSelected ? 36 : 28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? color : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
