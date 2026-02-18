import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/mood_model.dart';
import '../../providers/mood_provider.dart';

class MoodHistoryScreen extends ConsumerWidget {
  const MoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodsAsync = ref.watch(moodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood History'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart section
            const Text(
              'Mood Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            moodsAsync.when(
              data: (moods) => _MoodChart(moods: moods),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(
                height: 200,
                child: Center(child: Text('Failed to load mood data')),
              ),
            ),

            const SizedBox(height: 24),

            // Recent entries
            const Text(
              'Recent Entries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            moodsAsync.when(
              data: (moods) => _MoodList(moods: moods.take(10).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Failed to load')),
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
      return Card(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'No mood data yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    // Get last 7 days of data
    final last7Days = moods.take(7).toList().reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < last7Days.length) {
                        final date = last7Days[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('E').format(date),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
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
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No mood entries yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Column(
      children: moods.map((mood) => _MoodListItem(mood: mood)).toList(),
    );
  }
}

class _MoodListItem extends StatelessWidget {
  final MoodModel mood;

  const _MoodListItem({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(
          mood.emoji,
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(
          mood.label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy • h:mm a').format(mood.date),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: mood.note != null
            ? const Icon(Icons.note, color: AppColors.textSecondary, size: 18)
            : null,
      ),
    );
  }
}
