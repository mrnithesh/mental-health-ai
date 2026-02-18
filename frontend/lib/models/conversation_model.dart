import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String title;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationModel({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      title: data['title'] ?? 'New Conversation',
      messageCount: data['messageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'messageCount': messageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ConversationModel copyWith({
    String? id,
    String? title,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MessageModel {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      role: data['role'] ?? 'user',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
