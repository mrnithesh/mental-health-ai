import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/constants.dart';

class MoodModel {
  final String id;
  final DateTime date;
  final int score; // 1-5
  final String emoji;
  final String? note;

  MoodModel({
    required this.id,
    required this.date,
    required this.score,
    required this.emoji,
    this.note,
  });

  factory MoodModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoodModel(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      score: data['score'] ?? 3,
      emoji: data['emoji'] ?? '😐',
      note: data['note'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'score': score,
      'emoji': emoji,
      'note': note,
    };
  }

  MoodModel copyWith({
    String? id,
    DateTime? date,
    int? score,
    String? emoji,
    String? note,
  }) {
    return MoodModel(
      id: id ?? this.id,
      date: date ?? this.date,
      score: score ?? this.score,
      emoji: emoji ?? this.emoji,
      note: note ?? this.note,
    );
  }

  /// Get the label for this mood score
  String get label => MoodEmojis.scoreToLabel[score] ?? 'Unknown';

  /// Get formatted date string
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Check if this mood is from today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class MoodAnalysis {
  final DateTime startDate;
  final DateTime endDate;
  final double averageScore;
  final int totalEntries;
  final String trend; // 'improving', 'declining', 'stable'
  final String? aiInsight;

  MoodAnalysis({
    required this.startDate,
    required this.endDate,
    required this.averageScore,
    required this.totalEntries,
    required this.trend,
    this.aiInsight,
  });

  factory MoodAnalysis.fromJson(Map<String, dynamic> json) {
    return MoodAnalysis(
      startDate: DateTime.parse(json['period']['start']),
      endDate: DateTime.parse(json['period']['end']),
      averageScore: (json['summary']['average_score'] as num).toDouble(),
      totalEntries: json['summary']['total_entries'],
      trend: json['summary']['trend'],
      aiInsight: json['ai_insight'],
    );
  }
}
