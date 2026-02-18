import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/conversation_model.dart';
import '../models/journal_model.dart';
import '../models/mood_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference get _userDoc {
    if (_uid == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_uid);
  }

  // ============ Conversations ============

  CollectionReference get _conversationsCollection =>
      _userDoc.collection('conversations');

  /// Get all conversations
  Stream<List<ConversationModel>> getConversations() {
    return _conversationsCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConversationModel.fromFirestore(doc))
            .toList());
  }

  /// Get a single conversation
  Future<ConversationModel?> getConversation(String id) async {
    final doc = await _conversationsCollection.doc(id).get();
    if (!doc.exists) return null;
    return ConversationModel.fromFirestore(doc);
  }

  /// Create a new conversation
  Future<ConversationModel> createConversation({String? title}) async {
    final now = DateTime.now();
    final docRef = _conversationsCollection.doc();
    
    final conversation = ConversationModel(
      id: docRef.id,
      title: title ?? 'New Conversation',
      messageCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    
    await docRef.set(conversation.toFirestore());
    return conversation;
  }

  /// Update conversation title
  Future<void> updateConversationTitle(String id, String title) async {
    await _conversationsCollection.doc(id).update({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    // Delete all messages first
    final messages = await _conversationsCollection
        .doc(id)
        .collection('messages')
        .get();
    
    for (final doc in messages.docs) {
      await doc.reference.delete();
    }
    
    await _conversationsCollection.doc(id).delete();
  }

  // ============ Messages ============

  CollectionReference _messagesCollection(String conversationId) =>
      _conversationsCollection.doc(conversationId).collection('messages');

  /// Get messages for a conversation
  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _messagesCollection(conversationId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  /// Add a message to a conversation
  Future<MessageModel> addMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    final docRef = _messagesCollection(conversationId).doc();
    final now = DateTime.now();
    
    final message = MessageModel(
      id: docRef.id,
      role: role,
      content: content,
      createdAt: now,
    );
    
    await docRef.set(message.toFirestore());
    
    // Update conversation
    await _conversationsCollection.doc(conversationId).update({
      'messageCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    return message;
  }

  // ============ Journals ============

  CollectionReference get _journalsCollection => _userDoc.collection('journals');

  /// Get all journals
  Stream<List<JournalModel>> getJournals() {
    return _journalsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JournalModel.fromFirestore(doc)).toList());
  }

  /// Get a single journal
  Future<JournalModel?> getJournal(String id) async {
    final doc = await _journalsCollection.doc(id).get();
    if (!doc.exists) return null;
    return JournalModel.fromFirestore(doc);
  }

  /// Create a new journal entry
  Future<JournalModel> createJournal({
    required String content,
    String? moodId,
  }) async {
    final now = DateTime.now();
    final docRef = _journalsCollection.doc();
    
    final journal = JournalModel(
      id: docRef.id,
      content: content,
      moodId: moodId,
      createdAt: now,
      updatedAt: now,
    );
    
    await docRef.set(journal.toFirestore());
    return journal;
  }

  /// Update a journal entry
  Future<void> updateJournal({
    required String id,
    String? content,
    String? moodId,
    String? aiInsight,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (content != null) updates['content'] = content;
    if (moodId != null) updates['moodId'] = moodId;
    if (aiInsight != null) updates['aiInsight'] = aiInsight;
    
    await _journalsCollection.doc(id).update(updates);
  }

  /// Delete a journal entry
  Future<void> deleteJournal(String id) async {
    await _journalsCollection.doc(id).delete();
  }

  // ============ Moods ============

  CollectionReference get _moodsCollection => _userDoc.collection('moods');

  /// Get all moods
  Stream<List<MoodModel>> getMoods() {
    return _moodsCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MoodModel.fromFirestore(doc)).toList());
  }

  /// Get moods for a date range
  Future<List<MoodModel>> getMoodsInRange(DateTime start, DateTime end) async {
    final snapshot = await _moodsCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date')
        .get();
    
    return snapshot.docs.map((doc) => MoodModel.fromFirestore(doc)).toList();
  }

  /// Get today's mood
  Future<MoodModel?> getTodaysMood() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final snapshot = await _moodsCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    return MoodModel.fromFirestore(snapshot.docs.first);
  }

  /// Create or update today's mood
  Future<MoodModel> saveMood({
    required int score,
    required String emoji,
    String? note,
  }) async {
    final existingMood = await getTodaysMood();
    
    if (existingMood != null) {
      // Update existing mood
      await _moodsCollection.doc(existingMood.id).update({
        'score': score,
        'emoji': emoji,
        'note': note,
      });
      return existingMood.copyWith(score: score, emoji: emoji, note: note);
    } else {
      // Create new mood
      final docRef = _moodsCollection.doc();
      final mood = MoodModel(
        id: docRef.id,
        date: DateTime.now(),
        score: score,
        emoji: emoji,
        note: note,
      );
      
      await docRef.set(mood.toFirestore());
      return mood;
    }
  }

  /// Delete a mood entry
  Future<void> deleteMood(String id) async {
    await _moodsCollection.doc(id).delete();
  }
}
