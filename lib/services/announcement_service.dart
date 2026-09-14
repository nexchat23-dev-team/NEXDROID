import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final AnnouncementService _instance = AnnouncementService._internal();

  factory AnnouncementService() {
    return _instance;
  }

  AnnouncementService._internal();

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data;
  }

  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _addIdToData(doc)).toList());
  }

  // Note: Creating announcements is admin-only via firestore rules
  Future<String> createAnnouncement({
    required String title,
    required String content,
    required String badge,
    bool pinned = false,
  }) async {
    try {
      final ref = await _firestore.collection('announcements').add({
        'title': title,
        'content': content,
        'badge': badge,
        'pinned': pinned,
        'author': 'SYSTEM', // Hardcoded as SYSTEM for now
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      rethrow;
    }
  }
}
