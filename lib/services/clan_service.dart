import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ClanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data;
  }

  Future<String> createClan({
    required String name,
    required String description,
    String? motto,
    String? bannerUrl,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final ref = await _firestore.collection('clans').add({
        'name': name,
        'description': description,
        'motto': motto,
        'bannerUrl': bannerUrl,
        'founderId': currentUserId,
        'admins': [currentUserId],
        'members': [currentUserId],
        'level': 1,
        'experience': 0,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'isActive': true,
      });

      return ref.id;
    } catch (e) {
      debugPrint('Error creating clan: $e');
      rethrow;
    }
  }

  Future<void> requestJoinClan(String clanId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await _firestore.collection('clanJoinRequests').add({
        'clanId': clanId,
        'userId': currentUserId,
        'status': 'pending',
        'requestedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error requesting to join clan: $e');
      rethrow;
    }
  }

  Future<void> approveJoinRequest(String requestId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final requestDoc = await _firestore.collection('clanJoinRequests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final clanId = requestDoc['clanId']?.toString();
      final userId = requestDoc['userId']?.toString();
      if (clanId == null || userId == null) {
        throw Exception('Invalid request data');
      }

      final clanDoc = await _firestore.collection('clans').doc(clanId).get();
      if (!clanDoc.exists) {
        throw Exception('Clan not found');
      }

      final members = List<String>.from(clanDoc['members'] ?? []);
      if (!members.contains(userId)) {
        members.add(userId);
        await _firestore.collection('clans').doc(clanId).update({'members': members});
      }

      await _firestore.collection('clanJoinRequests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': DateTime.now().toUtc().toIso8601String(),
        'approvedBy': currentUserId,
      });
    } catch (e) {
      debugPrint('Error approving join request: $e');
      rethrow;
    }
  }

  Future<void> leaveClan(String clanId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final clanDoc = await _firestore.collection('clans').doc(clanId).get();
      if (!clanDoc.exists) {
        throw Exception('Clan not found');
      }

      final members = List<String>.from(clanDoc['members'] ?? []);
      final admins = List<String>.from(clanDoc['admins'] ?? []);
      final founderId = clanDoc['founderId']?.toString();

      if (!members.contains(currentUserId)) throw Exception('Not a member');

      members.remove(currentUserId);
      admins.remove(currentUserId);

      if (members.isEmpty) {
        await _firestore.collection('clans').doc(clanId).delete();
        return;
      }

      String newFounderId = founderId ?? members.first;
      if (currentUserId == founderId) {
        newFounderId = members.first;
        if (!admins.contains(newFounderId)) {
          admins.add(newFounderId);
        }
      }

      await _firestore.collection('clans').doc(clanId).update({
        'members': members,
        'admins': admins,
        'founderId': newFounderId,
      });
    } catch (e) {
      debugPrint('Error leaving clan: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getClans() {
    try {
      return _firestore
          .collection('clans')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => _addIdToData(doc))
                .toList();
          })
          .handleError((e) {debugPrint('Error getting clans: $e');});
    } catch (e) {
      debugPrint('Error setting up clans stream: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getUserClans() {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      return _firestore
          .collection('clans')
          .where('members', arrayContains: currentUserId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => _addIdToData(doc))
                .toList();
          })
          .handleError((e) {debugPrint('Error getting user clans: $e');});
    } catch (e) {
      debugPrint('Error setting up user clans stream: $e');
      rethrow;
    }
  }

  Future<void> sendClanMessage({
    required String clanId,
    required String text,
    String type = 'text',
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await _firestore.collection('clanMessages').add({
        'clanId': clanId,
        'senderId': currentUserId,
        'text': text,
        'type': type,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending clan message: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getClanMessages(String clanId) {
    try {
      return _firestore
          .collection('clanMessages')
          .where('clanId', isEqualTo: clanId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => _addIdToData(doc))
                .toList();
          })
          .handleError((e) {debugPrint('Error getting clan messages: $e');});
    } catch (e) {
      debugPrint('Error setting up clan messages stream: $e');
      rethrow;
    }
  }

  Future<String> createClanEvent({
    required String clanId,
    required String title,
    required DateTime eventDate,
    String? description,
    String? location,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final ref = await _firestore.collection('clanEvents').add({
        'clanId': clanId,
        'title': title,
        'description': description,
        'eventDate': eventDate.toUtc().toIso8601String(),
        'location': location,
        'createdBy': currentUserId,
        'attendees': [currentUserId],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      return ref.id;
    } catch (e) {
      debugPrint('Error creating clan event: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getClanEvents(String clanId) {
    try {
      return _firestore
          .collection('clanEvents')
          .where('clanId', isEqualTo: clanId)
          .orderBy('eventDate', descending: false)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => _addIdToData(doc))
                .toList();
          })
          .handleError((e) {debugPrint('Error getting clan events: $e');});
    } catch (e) {
      debugPrint('Error setting up clan events stream: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getClanJoinRequests(String clanId) {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      return _firestore
          .collection('clanJoinRequests')
          .where('clanId', isEqualTo: clanId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => _addIdToData(doc))
                .toList();
          })
          .handleError((e) {debugPrint('Error getting clan join requests: $e');});
    } catch (e) {
      debugPrint('Error setting up clan join requests stream: $e');
      rethrow;
    }
  }
}
