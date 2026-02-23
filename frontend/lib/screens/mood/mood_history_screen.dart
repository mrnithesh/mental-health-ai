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
      appBar: AppBar(title: const Text('Mood History')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mood Trend', style: tt.titleMedium),
            const SizedBox(height: 12),
            moodsAsync.when(
              data: (moods) => _MoodChart(moods: moods),
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(
                height: 220,
                child: Center(child: Text('Failed to load mood data')),
              ),
            ),
            const SizedBox(height: 28),
            Text('Recent Entries', style: tt.titleMedium),
            const SizedBox(height: 12),
            moodsAsync.when(
              data: (moods) => _MoodList(moods: moods.take(10).toList()),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Failed to load')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChart extends StatelessWidget {
  final List<MoodModel> moods;
  const _MoodChart({required this.moods});

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Center(
          child: Text(
            'No mood data yet',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ),
      );
    }

    final last7Days = moods.take(7).toList().reversed.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < last7Days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('E').format(last7Days[index].date),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
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
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (last7Days.length - 1).toDouble(),
            minY: 0,
            maxY: 6,
            lineBarsData: [
              LineChartBarData(
                spots: last7Days.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value.score.toDouble(),
                  );
                }).toList(),
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.primary,
                      strokeWidth: 2,
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
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.0),
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
}

class _MoodList extends StatelessWidget {
  final List<MoodModel> moods;
  const _MoodList({required this.moods});

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Center(
          child: Text('No mood entries yet',
              style: TextStyle(color: AppColors.textTertiary)),
        ),
      );
    }

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          // Colored mood indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _moodColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(mood.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood.label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy  •  h:mm a').format(mood.date),
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (mood.note != null)
            Icon(Icons.sticky_note_2_outlined,
                color: AppColors.textTertiary, size: 16),
        ],
      ),
    );
  }
}
