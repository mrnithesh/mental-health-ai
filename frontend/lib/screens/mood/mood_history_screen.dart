import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Could not load mood data',
                  style: TextStyle(color: AppColors.textSecondary)),
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
                Text('Last 7 Days',
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

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_up_rounded,
            label: 'Avg Mood',
            value: avgScore > 0 ? avgScore.toStringAsFixed(1) : '--',
            color: _colorForScore(avgScore.round()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.calendar_month_rounded,
            label: 'This Week',
            value: '${last7.length}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.bar_chart_rounded,
            label: 'Total',
            value: '$totalEntries',
            color: AppColors.secondary,
          ),
        ),
      ],
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

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon, required this.label,
    required this.value, required this.color,
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
          Text(value, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _MoodChart extends StatelessWidget {
  final List<MoodModel> moods;
  const _MoodChart({required this.moods});

  @override
  Widget build(BuildContext context) {
    final last7Days = moods.take(7).toList().reversed.toList();

    if (last7Days.length < 2) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Center(
          child: Text('Need at least 2 entries to show a chart',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
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
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < last7Days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('E').format(last7Days[index].date),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary),
                        ),
                      );
                    }
                    return const SizedBox();
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
                    if (emoji == null) return const SizedBox();
                    return Text(emoji, style: const TextStyle(fontSize: 14));
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (last7Days.length - 1).toDouble(),
            minY: 0.5,
            maxY: 5.5,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((spot) {
                  final mood = last7Days[spot.x.toInt()];
                  return LineTooltipItem(
                    '${mood.emoji} ${mood.label}\n${DateFormat('MMM d').format(mood.date)}',
                    TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: last7Days.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), e.value.score.toDouble())).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final score = spot.y.toInt();
                    return FlDotCirclePainter(
                      radius: 5,
                      color: _colorForScore(score),
                      strokeWidth: 2.5,
                      strokeColor: AppColors.surface,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
