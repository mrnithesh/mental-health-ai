import 'package:cloud_firestore/cloud_firestore.dart';

class JournalModel {
  final String id;
  final String title;
  final String content;
  final String? moodId;
  final String? aiInsight;
  final String? summary;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalModel({
    required this.id,
    this.title = '',
    required this.content,
    this.moodId,
    this.aiInsight,
    this.summary,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      moodId: data['moodId'],
      aiInsight: data['aiInsight'],
      summary: data['summary'],
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'moodId': moodId,
      'aiInsight': aiInsight,
      'summary': summary,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  JournalModel copyWith({
    String? id,
    String? title,
    String? content,
    String? moodId,
    String? aiInsight,
    String? summary,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      moodId: moodId ?? this.moodId,
      aiInsight: aiInsight ?? this.aiInsight,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (content.length <= 40) return content;
    return '${content.substring(0, 40)}...';
  }

  String get preview {
    if (content.length <= 120) return content;
    return '${content.substring(0, 120)}...';
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }
}
