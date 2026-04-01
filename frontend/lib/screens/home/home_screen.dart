import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/nickname_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/glass_card.dart';
import '../journal/journal_editor_screen.dart' show JournalEditorArgs;
import '../main_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool? _geminiAvailable;
  String? _dailyPrompt;
  bool _loadingPrompt = true;
  int? _selectedMood;
  bool _moodSaved = false;
  int _streakDays = 0;
  List<bool> _weekActivity = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGemini();
      _loadDailyPrompt();
      _loadStreak();
      _loadTodayMood();
    });
  }

  Future<void> _checkGemini() async {
    try {
      final gemini = ref.read(geminiServiceProvider);
      final ok = await gemini.isAvailable();
      if (mounted) setState(() => _geminiAvailable = ok);
    } catch (e) {
      if (mounted) setState(() => _geminiAvailable = false);
    }
  }

  Future<void> _loadDailyPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = 'daily_prompt_${today.year}_${today.month}_${today.day}';
      final cached = prefs.getString(dateKey);

      if (cached != null) {
        if (mounted) setState(() { _dailyPrompt = cached; _loadingPrompt = false; });
        return;
      }

      final gemini = ref.read(geminiServiceProvider);
      final prompt = await gemini.generateDailyPrompt();
      await prefs.setString(dateKey, prompt);
      if (mounted) setState(() { _dailyPrompt = prompt; _loadingPrompt = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _dailyPrompt = 'What moment today are you most grateful for?';
          _loadingPrompt = false;
        });
      }
    }
  }

  Future<void> _loadTodayMood() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final mood = await firestoreService.getTodaysMood();
      if (mounted && mood != null) {
        setState(() {
          _selectedMood = mood.score;
          _moodSaved = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStreak() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final moods = await firestoreService.getMoodsInRange(weekStart, weekEnd);
      final moodDays = moods.map((m) => m.date.weekday).toSet();

      final weekActivity = List.filled(7, false);
      for (final day in moodDays) {
        if (day >= 1 && day <= 7) weekActivity[day - 1] = true;
      }

      int streak = 0;
      for (int i = now.weekday - 1; i >= 0; i--) {
        if (weekActivity[i]) {
          streak++;
        } else {
          break;
        }
      }

      if (mounted) {
        setState(() {
          _weekActivity = weekActivity;
          _streakDays = streak;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMood(int score) async {
    setState(() { _selectedMood = score; _moodSaved = true; });

    const emojis = {1: '😢', 2: '😕', 3: '😐', 4: '🙂', 5: '😄'};
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveMood(
        score: score,
        emoji: emojis[score] ?? '😐',
      );
      _loadStreak();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mood saved!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Talk about it',
          textColor: Colors.white,
          onPressed: () => _navigateToTab(1),
        ),
      ),
    );
  }

  void _navigateToTab(int index) {
    MainShellState.of(context)?.switchTab(index);
  }

  String get _userName => ref.watch(nicknameProvider);

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
              AnimatedListItem(index: 0, child: _buildGreeting(tt)),
              const SizedBox(height: 20),
              AnimatedListItem(index: 1, child: _buildHeroCard(tt)),
              const SizedBox(height: 20),
              AnimatedListItem(index: 2, child: _buildDailyPrompt(tt)),
              const SizedBox(height: 20),
              AnimatedListItem(index: 3, child: _buildMoodCheckin(tt)),
              const SizedBox(height: 20),
              AnimatedListItem(index: 4, child: _buildStreakTracker(tt)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(TextTheme tt) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: tt.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                _userName,
                style: tt.headlineMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    if (_geminiAvailable == null) {
      return const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final ok = _geminiAvailable!;
    return GestureDetector(
      onTap: ok ? null : () {
        setState(() => _geminiAvailable = null);
        _checkGemini();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              ok ? 'AI Ready' : 'Offline',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: ok ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(TextTheme tt) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6A3E), Color(0xFF1B4D2B)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D6A3E).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk to Amigo',
                        style: tt.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'I\'m here whenever you need',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _HeroButton(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Start Chat',
                    onTap: () => _navigateToTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroButton(
                    icon: Icons.mic_rounded,
                    label: 'Start Voice',
                    onTap: () => _navigateToTab(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyPrompt(TextTheme tt) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: const Color(0xFF3A9B5A).withValues(alpha: 0.08),
      border: Border.all(
        color: const Color(0xFF4A7C59).withValues(alpha: 0.25),
        width: 1.5,
      ),
      child: InkWell(
        onTap: _dailyPrompt != null
            ? () => Navigator.pushNamed(
                  context,
                  AppRoutes.journalEditor,
                  arguments: JournalEditorArgs(prefillTitle: _dailyPrompt),
                )
            : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A9B5A), Color(0xFF2E8B57)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Prompt',
                    style: tt.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_loadingPrompt)
                    const SizedBox(
                      height: 14, width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3A9B5A),
                      ),
                    )
                  else
                    Text(
                      _dailyPrompt ?? '',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (!_loadingPrompt)
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF4A7C59)),
          ],
        ),
      ),
    );
  }

  // ── Mood check-in ──────────────────────────────────────────────────────────
  // After the user taps an emoji:
  //   • The 5-emoji picker row collapses via AnimatedSize (height → 0)
  //   • A compact summary pill fades + slides in to take the minimal space
  //   • The streak card below animates upward naturally because the Column
  //     shrinks — no manual offset needed; AnimatedSize handles the reflow.
  // Tapping the pencil icon on the pill reopens the picker.

  Widget _buildMoodCheckin(TextTheme tt) {
    const moods = [
      (emoji: '😊', label: 'Great',  score: 5, color: AppColors.moodExcellent),
      (emoji: '🙂', label: 'Good',   score: 4, color: AppColors.moodGood),
      (emoji: '😐', label: 'Okay',   score: 3, color: AppColors.moodNeutral),
      (emoji: '😔', label: 'Low',    score: 2, color: AppColors.moodBad),
      (emoji: '😢', label: 'Rough',  score: 1, color: AppColors.moodTerrible),
    ];

    final selectedMood = _selectedMood != null
        ? moods.firstWhere((m) => m.score == _selectedMood, orElse: () => moods[2])
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Align(
                  key: ValueKey(_moodSaved),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _moodSaved ? 'Today\'s Mood' : 'How are you feeling?',
                    style: tt.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.moodHistory),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A9B5A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4A7C59).withValues(alpha: 0.25)),
                ),
                child: Text(
                  'See trends',
                  style: tt.labelSmall?.copyWith(
                    color: const Color(0xFF3A9B5A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Emoji picker — AnimatedSize collapses it to zero height ─────────
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _moodSaved
              ? const SizedBox(width: double.infinity) // zero-height placeholder
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: moods.map((mood) {
                    final isSelected = _selectedMood == mood.score;
                    return GestureDetector(
                      onTap: () => _saveMood(mood.score),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isSelected
                                    ? [mood.color, mood.color.withValues(alpha: 0.7)]
                                    : [mood.color.withValues(alpha: 0.12), mood.color.withValues(alpha: 0.06)],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isSelected ? mood.color : mood.color.withValues(alpha: 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(mood.emoji, style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mood.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? mood.color : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),

        // ── Compact summary pill — slides down and fades in after selection ──
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: (_moodSaved && selectedMood != null)
              ? TweenAnimationBuilder<double>(
                  // Re-trigger on each new selection by keying on score
                  key: ValueKey(_selectedMood),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 10),
                      child: child,
                    ),
                  ),
                  child: GestureDetector(
                    // Tap edit icon → reopen picker
                    onTap: () => setState(() {
                      _moodSaved = false;
                      _selectedMood = null;
                    }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedMood.color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedMood.color.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(selectedMood.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Text(
                            'Feeling ${selectedMood.label.toLowerCase()} today',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selectedMood.color,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.edit_rounded,
                            size: 15,
                            color: selectedMood.color.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildStreakTracker(TextTheme tt) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: const Color(0xFF2D6A3E).withValues(alpha: 0.08),
      border: Border.all(
        color: const Color(0xFF4A7C59).withValues(alpha: 0.25),
        width: 1.5,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Streak',
                  style: tt.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _streakDays > 0
                        ? [const Color(0xFFE8A838).withValues(alpha: 0.2), const Color(0xFFE8A838).withValues(alpha: 0.1)]
                        : [AppColors.surfaceVariant, AppColors.surfaceVariant.withValues(alpha: 0.5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _streakDays > 0
                        ? const Color(0xFFE8A838).withValues(alpha: 0.3)
                        : AppColors.surfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _streakDays > 0 ? '🔥' : '💤',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _streakDays > 0
                          ? '$_streakDays day${_streakDays == 1 ? '' : 's'}'
                          : 'Start today!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _streakDays > 0
                            ? const Color(0xFFE8A838)
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isActive = _weekActivity[i];
              final isToday = i == today - 1;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isActive
                            ? [const Color(0xFF3A9B5A), const Color(0xFF2D6A3E)]
                            : isToday
                                ? [const Color(0xFF3A9B5A).withValues(alpha: 0.2), const Color(0xFF3A9B5A).withValues(alpha: 0.1)]
                                : [AppColors.surfaceVariant, AppColors.surfaceVariant.withValues(alpha: 0.5)],
                      ),
                      border: isToday && !isActive
                          ? Border.all(
                              color: const Color(0xFF3A9B5A).withValues(alpha: 0.5),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF3A9B5A).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? const Color(0xFF3A9B5A) : AppColors.textTertiary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}