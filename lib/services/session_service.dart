import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    data['id'] = doc.id;
    return data;
  }

  Future<String> createSession({required String title, required DateTime startTime, String? description, String? game, String? gameMode, int maxParticipants = 10, bool isPublic = true, String? squadId, String? clanId,}) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final docRef = await _firestore.collection('sessions').add({'title': title, 'description': description, 'game': game, 'gameMode': gameMode, 'startTime': startTime.toUtc().toIso8601String(), 'endTime': null, 'creatorId': currentUserId, 'participants': [currentUserId], 'maxParticipants': maxParticipants, 'isPublic': isPublic, 'status': 'scheduled', 'squadId': squadId, 'clanId': clanId, 'createdAt': DateTime.now().toUtc().toIso8601String(),});
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating session: $e');
      rethrow;
    }
  }

  Future<void> joinSession(String sessionId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');
      final session = sessionDoc.data()!;
      final participants = List<String>.from(session['participants'] ?? []);
      final maxParticipants = session['maxParticipants'] ?? 10;
      final status = session['status']?.toString() ?? 'scheduled';
      if (status != 'scheduled') throw Exception('Session is not open for joining');
      if (participants.contains(currentUserId)) throw Exception('Already joined');
      if (participants.length >= maxParticipants) throw Exception('Session is full');
      participants.add(currentUserId!);
      await _firestore.collection('sessions').doc(sessionId).update({'participants': participants});
    } catch (e) {
      debugPrint('Error joining session: $e');
      rethrow;
    }
  }

  Future<void> leaveSession(String sessionId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');
      final session = sessionDoc.data()!;
      final participants = List<String>.from(session['participants'] ?? []);
      final creatorId = session['creatorId']?.toString();
      if (!participants.contains(currentUserId)) throw Exception('Not a participant');
      participants.remove(currentUserId);
      if (participants.isEmpty) {
        await _firestore.collection('sessions').doc(sessionId).update({'participants': participants, 'status': 'cancelled',});
      } else {
        String newCreatorId = creatorId ?? participants.first;
        if (currentUserId == creatorId) newCreatorId = participants.first;
        await _firestore.collection('sessions').doc(sessionId).update({'participants': participants, 'creatorId': newCreatorId});
      }
    } catch (e) {
      debugPrint('Error leaving session: $e');
      rethrow;
    }
  }

  Future<void> startSession(String sessionId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');
      final session = sessionDoc.data()!;
      final creatorId = session['creatorId']?.toString();
      if (currentUserId != creatorId) throw Exception('Only creator can start session');
      await _firestore.collection('sessions').doc(sessionId).update({'status': 'active', 'startedAt': DateTime.now().toUtc().toIso8601String(),});
    } catch (e) {
      debugPrint('Error starting session: $e');
      rethrow;
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');
      final session = sessionDoc.data()!;
      final creatorId = session['creatorId']?.toString();
      if (currentUserId != creatorId) throw Exception('Only creator can end session');
      await _firestore.collection('sessions').doc(sessionId).update({'status': 'completed', 'endedAt': DateTime.now().toUtc().toIso8601String(),});
    } catch (e) {
      debugPrint('Error ending session: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getSessions({bool publicOnly = false}) {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('sessions');
      if (publicOnly) query = query.where('isPublic', isEqualTo: true);
      query = query.where('status', whereIn: ['scheduled', 'active']).orderBy('startTime', descending: false);
      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = _addIdToData(doc);
          return {'id': data['id']?.toString() ?? '', 'title': data['title'] ?? 'Unknown Session', 'game': data['game'] ?? 'Unknown Game', 'status': data['status'] ?? 'scheduled', 'participants': List<String>.from(data['participants'] ?? []), 'maxParticipants': data['maxParticipants'] ?? 10, 'startTime': data['startTime'], 'isPublic': data['isPublic'] ?? true,};
        }).toList();
      }).handleError((e) {debugPrint('Error getting sessions: $e');});
    } catch (e) {
      debugPrint('Error setting up sessions stream: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getUserSessions() {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      return _firestore.collection('sessions').where('participants', arrayContains: currentUserId).orderBy('startTime', descending: false).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = _addIdToData(doc);
          return {'id': data['id']?.toString() ?? '', 'title': data['title'] ?? 'Unknown Session', 'game': data['game'] ?? 'Unknown Game', 'status': data['status'] ?? 'scheduled', 'participants': List<String>.from(data['participants'] ?? []), 'maxParticipants': data['maxParticipants'] ?? 10, 'startTime': data['startTime'], 'isPublic': data['isPublic'] ?? true,};
        }).toList();
      }).handleError((e) {debugPrint('Error getting user sessions: $e');});
    } catch (e) {
      debugPrint('Error setting up user sessions stream: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPublicSessions() async {
    try {
      final snapshot = await _firestore.collection('sessions').where('isPublic', isEqualTo: true).where('status', whereIn: ['scheduled', 'active']).orderBy('startTime', descending: false).get();
      return snapshot.docs.map((doc) {
        final data = _addIdToData(doc);
        return {'id': data['id']?.toString() ?? '', 'title': data['title'] ?? 'Unknown Session', 'game': data['game'] ?? 'Unknown Game', 'status': data['status'] ?? 'scheduled', 'participants': List<String>.from(data['participants'] ?? []), 'maxParticipants': data['maxParticipants'] ?? 10, 'startTime': data['startTime'],};
      }).toList();
    } catch (e) {
      debugPrint('Error fetching public sessions: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    try {
      final doc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!doc.exists) return null;
      final data = _addIdToData(doc);
      return {'id': data['id']?.toString() ?? '', 'title': data['title'] ?? 'Unknown Session', 'game': data['game'] ?? 'Unknown Game', 'description': data['description'] ?? '', 'status': data['status'] ?? 'scheduled', 'participants': List<String>.from(data['participants'] ?? []), 'maxParticipants': data['maxParticipants'] ?? 10, 'isPublic': data['isPublic'] ?? true, 'startTime': data['startTime'], 'creatorId': data['creatorId'],};
    } catch (e) {
      debugPrint('Error getting session by ID: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchPublicSessions(String query) async {
    try {
      final searchQuery = query.toLowerCase().trim();
      final snapshot = await _firestore.collection('sessions').where('isPublic', isEqualTo: true).where('status', whereIn: ['scheduled', 'active']).orderBy('startTime', descending: false).get();
      final sessions = snapshot.docs.map((doc) {
        final data = _addIdToData(doc);
        return {'id': data['id']?.toString() ?? '', 'title': data['title'] ?? 'Unknown Session', 'game': data['game'] ?? 'Unknown Game', 'status': data['status'] ?? 'scheduled', 'participants': List<String>.from(data['participants'] ?? []), 'maxParticipants': data['maxParticipants'] ?? 10, 'startTime': data['startTime'],};
      }).where((session) {
        final title = (session['title'] as String).toLowerCase();
        final game = (session['game'] as String).toLowerCase();
        return title.contains(searchQuery) || game.contains(searchQuery);
      }).toList();
      return sessions;
    } catch (e) {
      debugPrint('Error searching public sessions: $e');
      rethrow;
    }
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update(updates);
    } catch (e) {
      debugPrint('Error updating session: $e');
      rethrow;
    }
  }

  Future<void> sendSessionMessage({required String sessionId, required String text, String type = 'text',}) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      await _firestore.collection('sessionMessages').add({'sessionId': sessionId, 'senderId': currentUserId, 'text': text, 'type': type, 'timestamp': DateTime.now().toUtc().toIso8601String(),});
    } catch (e) {
      debugPrint('Error sending session message: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getSessionMessages(String sessionId) {
    try {
      return _firestore.collection('sessionMessages').where('sessionId', isEqualTo: sessionId).orderBy('timestamp', descending: true).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => _addIdToData(doc)).toList();
      }).handleError((e) {debugPrint('Error getting session messages: $e');});
    } catch (e) {
      debugPrint('Error setting up session messages stream: $e');
      rethrow;
    }
  }

  Future<void> addParticipant(String sessionId, String userId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');
      final session = sessionDoc.data()!;
      final participants = List<String>.from(session['participants'] ?? []);
      final maxParticipants = session['maxParticipants'] ?? 10;
      final creatorId = session['creatorId']?.toString();
      if (currentUserId != creatorId) throw Exception('Only creator can add participants');
      if (participants.contains(userId)) throw Exception('User already a participant');
      if (participants.length >= maxParticipants) throw Exception('Session is full');
      participants.add(userId);
      await _firestore.collection('sessions').doc(sessionId).update({'participants': participants});
    } catch (e) {
      debugPrint('Error adding participant: $e');
      rethrow;
    }
  }

  Future<void> removeParticipant(String sessionId, String userId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');
      final session = sessionDoc.data()!;
      final participants = List<String>.from(session['participants'] ?? []);
      final creatorId = session['creatorId']?.toString();
      if (currentUserId != creatorId && currentUserId != userId) throw Exception('Only creator or the participant can remove');
      if (!participants.contains(userId)) throw Exception('User is not a participant');
      participants.remove(userId);
      if (participants.isEmpty) {
        await _firestore.collection('sessions').doc(sessionId).update({'participants': participants, 'status': 'cancelled',});
      } else {
        await _firestore.collection('sessions').doc(sessionId).update({'participants': participants});
      }
    } catch (e) {
      debugPrint('Error removing participant: $e');
      rethrow;
    }
  }
}
