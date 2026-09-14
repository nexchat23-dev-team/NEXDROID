import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SquadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    data['id'] = doc.id;
    return data;
  }

  Future<String> createSquad({required String name, required String description, String? game, int maxMembers = 5,}) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final docRef = await _firestore.collection('squads').add({'name': name, 'description': description, 'game': game, 'leaderId': currentUserId, 'members': [currentUserId], 'maxMembers': maxMembers, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'isActive': true,});
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating squad: $e');
      rethrow;
    }
  }

  Future<void> joinSquad(String squadId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final squadDoc = await _firestore.collection('squads').doc(squadId).get();
      if (!squadDoc.exists) throw Exception('Squad not found');
      final squad = squadDoc.data()!;
      final members = List<String>.from(squad['members'] ?? []);
      final maxMembers = squad['maxMembers'] ?? 5;
      if (members.contains(currentUserId)) throw Exception('Already a member');
      if (members.length >= maxMembers) throw Exception('Squad is full');
      members.add(currentUserId!);
      await _firestore.collection('squads').doc(squadId).update({'members': members});
    } catch (e) {
      debugPrint('Error joining squad: $e');
      rethrow;
    }
  }

  Future<void> leaveSquad(String squadId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final squadDoc = await _firestore.collection('squads').doc(squadId).get();
      if (!squadDoc.exists) throw Exception('Squad not found');
      final squad = squadDoc.data()!;
      final members = List<String>.from(squad['members'] ?? []);
      final leaderId = squad['leaderId']?.toString();
      if (!members.contains(currentUserId)) throw Exception('Not a member');
      if (currentUserId == leaderId && members.length > 1) {
        members.remove(currentUserId);
        final newLeader = members.first;
        await _firestore.collection('squads').doc(squadId).update({'members': members, 'leaderId': newLeader});
      } else if (members.length == 1) {
        await _firestore.collection('squads').doc(squadId).delete();
      } else {
        members.remove(currentUserId);
        await _firestore.collection('squads').doc(squadId).update({'members': members});
      }
    } catch (e) {
      debugPrint('Error leaving squad: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getSquads() {
    try {
      return _firestore.collection('squads').where('isActive', isEqualTo: true).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => _addIdToData(doc)).toList();
      }).handleError((e) {debugPrint('Error getting squads: $e');});
    } catch (e) {
      debugPrint('Error setting up squads stream: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getUserSquads() {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      return _firestore.collection('squads').where('members', arrayContains: currentUserId).where('isActive', isEqualTo: true).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => _addIdToData(doc)).toList();
      }).handleError((e) {debugPrint('Error getting user squads: $e');});
    } catch (e) {
      debugPrint('Error setting up user squads stream: $e');
      rethrow;
    }
  }

  Future<void> sendSquadMessage({required String squadId, required String text, String type = 'text',}) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      await _firestore.collection('squadMessages').add({'squadId': squadId, 'senderId': currentUserId, 'text': text, 'type': type, 'timestamp': DateTime.now().toUtc().toIso8601String(),});
    } catch (e) {
      debugPrint('Error sending squad message: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getSquadMessages(String squadId) {
    try {
      return _firestore.collection('squadMessages').where('squadId', isEqualTo: squadId).orderBy('timestamp', descending: true).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => _addIdToData(doc)).toList();
      }).handleError((e) {debugPrint('Error getting squad messages: $e');});
    } catch (e) {
      debugPrint('Error setting up squad messages stream: $e');
      rethrow;
    }
  }

  Future<String> createSquadSession({required String squadId, required String title, required DateTime startTime, String? description, String? gameMode,}) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final docRef = await _firestore.collection('squadSessions').add({'squadId': squadId, 'title': title, 'description': description, 'gameMode': gameMode, 'startTime': startTime.toUtc().toIso8601String(), 'creatorId': currentUserId, 'participants': [currentUserId], 'status': 'scheduled', 'createdAt': DateTime.now().toUtc().toIso8601String(),});
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating squad session: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getSquadSessions(String squadId) {
    try {
      return _firestore.collection('squadSessions').where('squadId', isEqualTo: squadId).orderBy('startTime', descending: false).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => _addIdToData(doc)).toList();
      }).handleError((e) {debugPrint('Error getting squad sessions: $e');});
    } catch (e) {
      debugPrint('Error setting up squad sessions stream: $e');
      rethrow;
    }
  }
}
