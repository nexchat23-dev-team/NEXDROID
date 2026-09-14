import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final ActivityService _instance = ActivityService._internal();

  factory ActivityService() {
    return _instance;
  }

  ActivityService._internal();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> logActivity({
    required String targetUserId,
    required String type, // e.g., 'like', 'comment', 'follow', 'game_session'
    required String title,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('activityFeed')
          .doc(targetUserId)
          .collection('events')
          .add({
        'actorId': currentUserId,
        'type': type,
        'title': title,
        'description': description,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Stream<QuerySnapshot> getUserActivityFeed() {
    if (currentUserId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('activityFeed')
        .doc(currentUserId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markActivityAsRead(String eventId) async {
    try {
      if (currentUserId == null) return;
      await _firestore
          .collection('activityFeed')
          .doc(currentUserId)
          .collection('events')
          .doc(eventId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking activity as read: $e');
    }
  }
  
  Future<void> clearActivityFeed() async {
    try {
      if (currentUserId == null) return;
      
      final batch = _firestore.batch();
      final docs = await _firestore
          .collection('activityFeed')
          .doc(currentUserId)
          .collection('events')
          .get();
          
      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing activity feed: $e');
    }
  }
}
