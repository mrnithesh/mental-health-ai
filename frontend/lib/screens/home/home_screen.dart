import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/service_providers.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/glass_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool? _geminiAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGemini());
  }

  Future<void> _checkGemini() async {
    try {
      final gemini = ref.read(geminiServiceProvider);
      final ok = await gemini.isAvailable();
      if (mounted) setState(() => _geminiAvailable = ok);
    } catch (e) {
      debugPrint('Gemini check error: $e');
      if (mounted) setState(() => _geminiAvailable = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting + status
              AnimatedListItem(
                index: 0,
                child: _buildGreetingSection(tt),
              ),
              const SizedBox(height: 24),

              // Quick mood row
              AnimatedListItem(
                index: 1,
                child: _buildQuickMood(tt),
              ),
              const SizedBox(height: 24),

              // Daily insight
              AnimatedListItem(
                index: 2,
                child: _buildDailyInsight(tt),
              ),
              const SizedBox(height: 24),

              // Wellness tips
              AnimatedListItem(
                index: 3,
                child: _buildWellnessTips(tt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingSection(TextTheme tt) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good ${_getTimeOfDay()},',
                        style: tt.bodyMedium?.copyWith(
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('Friend',
                        style: tt.headlineMedium),
                  ],
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getGreetingMessage(),
            style: tt.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    if (_geminiAvailable == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final ok = _geminiAvailable!;
    return GestureDetector(
      onTap: ok
          ? null
          : () {
              setState(() => _geminiAvailable = null);
              _checkGemini();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (ok ? AppColors.success : AppColors.error).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              ok ? 'AI Ready' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ok ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMood(TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How are you feeling?', style: tt.titleMedium),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MoodChip(emoji: '😊', label: 'Great', color: AppColors.moodExcellent),
            _MoodChip(emoji: '🙂', label: 'Good', color: AppColors.moodGood),
            _MoodChip(emoji: '😐', label: 'Okay', color: AppColors.moodNeutral),
            _MoodChip(emoji: '😔', label: 'Low', color: AppColors.moodBad),
            _MoodChip(emoji: '😢', label: 'Rough', color: AppColors.moodTerrible),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyInsight(TextTheme tt) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.accent.withOpacity(0.08),
      border: Border.all(color: AppColors.accent.withOpacity(0.15)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Insight',
                    style: tt.titleSmall?.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Take a moment to breathe deeply. Inhale for 4 seconds, hold for 4, exhale for 4.',
                  style: tt.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessTips(TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wellness Corner', style: tt.titleMedium),
        const SizedBox(height: 12),
        _WellnessCard(
          icon: Icons.self_improvement_rounded,
          title: 'Mindful Breathing',
          subtitle: 'A 2-minute exercise to calm your mind',
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),
        _WellnessCard(
          icon: Icons.nature_people_rounded,
          title: 'Grounding Technique',
          subtitle: 'Name 5 things you can see around you',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 10),
        _WellnessCard(
          icon: Icons.favorite_rounded,
          title: 'Self-Compassion',
          subtitle: 'Write one thing you appreciate about yourself',
          color: AppColors.accent,
        ),
      ],
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Let's start the day with intention and kindness.";
    if (hour < 17) return 'Take a gentle pause and check in with yourself.';
    return 'Wind down and reflect on your day.';
  }
}

class _MoodChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _MoodChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _WellnessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _WellnessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }
}
