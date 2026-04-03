import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/mood_model.dart';
import '../../providers/mood_provider.dart';
import '../../widgets/animated_list_item.dart';

class MoodHistoryScreen extends ConsumerWidget {
  const MoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodsAsync = ref.watch(moodsProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mood Trends',
            style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: moodsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Could not load mood data',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                error.toString().contains('permission')
                    ? 'Permission denied — try signing out and back in'
                    : 'Check your connection and try again',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => ref.refresh(moodsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        data: (moods) {
          if (moods.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mood_rounded, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('No mood entries yet',
                      style: tt.titleSmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Check in on the home screen to start tracking',
                      style: tt.bodySmall?.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MoodSummaryRow(moods: moods),
                const SizedBox(height: 24),
                Text('Last 7 calendar days',
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 14),
                _MoodChart(moods: moods),
                const SizedBox(height: 28),
                Text('Recent Entries',
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 14),
                _MoodList(moods: moods.take(15).toList()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MoodSummaryRow extends StatelessWidget {
  final List<MoodModel> moods;
  const _MoodSummaryRow({required this.moods});

  @override
  Widget build(BuildContext context) {
    final last7 = moods.where((m) {
      final age = DateTime.now().difference(m.date);
      return age.inDays < 7;
    }).toList();
    final avgScore = last7.isEmpty
        ? 0.0
        : last7.map((m) => m.score).reduce((a, b) => a + b) / last7.length;
    final totalEntries = moods.length;
    final nearest = avgScore > 0
        ? avgScore.round().clamp(1, 5).toInt()
        : 3;
    final moodColor =
        avgScore > 0 ? _colorForScore(nearest) : AppColors.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.trending_up_rounded,
              label: 'Avg Mood',
              color: moodColor,
              value: avgScore > 0
                  ? _AvgMoodValue(
                      emoji: MoodEmojis.scoreToEmoji[nearest] ?? '😐',
                      label: MoodEmojis.scoreToLabel[nearest] ?? 'Okay',
                      color: moodColor,
                    )
                  : Text(
                      '—',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              icon: Icons.calendar_month_rounded,
              label: 'This Week',
              color: AppColors.primary,
              value: Text(
                '${last7.length}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              icon: Icons.bar_chart_rounded,
              label: 'Total',
              color: AppColors.secondary,
              value: Text(
                '$totalEntries',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForScore(int score) {
    switch (score) {
      case 5: return AppColors.moodExcellent;
      case 4: return AppColors.moodGood;
      case 3: return AppColors.moodNeutral;
      case 2: return AppColors.moodBad;
      default: return AppColors.moodTerrible;
    }
  }
}

class _AvgMoodValue extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _AvgMoodValue({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 30, height: 1.1)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          value,
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// One bucket per calendar day (local), averaged if multiple logs that day.
class _ChartDay {
  final DateTime day;
  final double? avgScore;
  const _ChartDay({required this.day, this.avgScore});
}

List<_ChartDay> _last7CalendarDays(List<MoodModel> moods) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    final dayMoods = moods.where((m) {
      final md = m.date;
      return DateTime(md.year, md.month, md.day) == day;
    }).toList();
    if (dayMoods.isEmpty) return _ChartDay(day: day, avgScore: null);
    final sum = dayMoods.fold<double>(0, (a, m) => a + m.score);
    return _ChartDay(day: day, avgScore: sum / dayMoods.length);
  });
}

class _MoodChart extends StatelessWidget {
  final List<MoodModel> moods;
  const _MoodChart({required this.moods});

  @override
  Widget build(BuildContext context) {
    final chartDays = _last7CalendarDays(moods);
    final daysWithData = chartDays.where((d) => d.avgScore != null).length;

    if (daysWithData < 1) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'No mood check-ins in the last 7 days',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final dateFmt = DateFormat('MMM d');

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 5.5,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.surfaceVariant,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= 7 || (value - i).abs() > 0.01) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateFmt.format(chartDays[i].day),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    const emojis = {1: '😢', 2: '😕', 3: '😐', 4: '🙂', 5: '😊'};
                    final emoji = emojis[value.toInt()];
                    if (emoji == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(emoji, style: const TextStyle(fontSize: 14)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (i) {
              final d = chartDays[i];
              final has = d.avgScore != null;
              final score = d.avgScore?.clamp(1.0, 5.0);
              final y = has ? score! : 0.45;
              return BarChartGroupData(
                x: i,
                barsSpace: 6,
                barRods: [
                  BarChartRodData(
                    toY: y,
                    fromY: 0,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    color: has
                        ? _barColorForScore(d.avgScore!.round().clamp(1, 5))
                        : AppColors.surfaceVariant,
                    borderSide: has
                        ? BorderSide.none
                        : BorderSide(
                            color: AppColors.textTertiary.withValues(alpha: 0.5),
                          ),
                  ),
                ],
              );
            }),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final i = group.x;
                  if (i < 0 || i >= 7) return null;
                  final d = chartDays[i];
                  if (d.avgScore == null) {
                    return BarTooltipItem(
                      'No check-in\n${dateFmt.format(d.day)}',
                      TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  return BarTooltipItem(
                    '${d.avgScore!.toStringAsFixed(1)} avg mood\n${dateFmt.format(d.day)}',
                    TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _barColorForScore(int score) {
    switch (score) {
      case 5: return AppColors.moodExcellent;
      case 4: return AppColors.moodGood;
      case 3: return AppColors.moodNeutral;
      case 2: return AppColors.moodBad;
      default: return AppColors.moodTerrible;
    }
  }
}

class _MoodList extends StatelessWidget {
  final List<MoodModel> moods;
  const _MoodList({required this.moods});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: moods.asMap().entries.map((entry) {
        return AnimatedListItem(
          index: entry.key,
          child: _MoodListItem(mood: entry.value),
        );
      }).toList(),
    );
  }
}

class _MoodListItem extends StatelessWidget {
  final MoodModel mood;
  const _MoodListItem({required this.mood});

  Color get _moodColor {
    switch (mood.score) {
      case 5: return AppColors.moodExcellent;
      case 4: return AppColors.moodGood;
      case 3: return AppColors.moodNeutral;
      case 2: return AppColors.moodBad;
      default: return AppColors.moodTerrible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _moodColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _moodColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(mood.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mood.label,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                  DateFormat('EEEE, MMM d  ·  h:mm a').format(mood.date),
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (mood.note != null && mood.note!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.sticky_note_2_outlined,
                  color: AppColors.textTertiary, size: 16),
            ),
          const SizedBox(width: 8),
          Container(
            width: 4, height: 32,
            decoration: BoxDecoration(
              color: _moodColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
