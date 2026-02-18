import 'package:cloud_firestore/cloud_firestore.dart';

class JournalModel {
  final String id;
  final String content;
  final String? moodId;
  final String? aiInsight;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalModel({
    required this.id,
    required this.content,
    this.moodId,
    this.aiInsight,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalModel(
      id: doc.id,
      content: data['content'] ?? '',
      moodId: data['moodId'],
      aiInsight: data['aiInsight'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'moodId': moodId,
      'aiInsight': aiInsight,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  JournalModel copyWith({
    String? id,
    String? content,
    String? moodId,
    String? aiInsight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalModel(
      id: id ?? this.id,
      content: content ?? this.content,
      moodId: moodId ?? this.moodId,
      aiInsight: aiInsight ?? this.aiInsight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get a preview of the content (first 100 characters)
  String get preview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  /// Get formatted date string
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
