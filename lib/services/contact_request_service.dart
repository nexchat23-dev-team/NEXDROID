import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class ContactRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> defaultPrivacy() {
    return {
      'allowIncomingMessages': true,
      'allowAnyUserMessage': true,
      'allowIncomingCalls': true,
    };
  }

  Future<Map<String, dynamic>> getPrivacy(String userId) async {
    final defaults = defaultPrivacy();
    if (userId.isEmpty) return defaults;

    // 1. Try Realtime Database first for speed and offline availability
    try {
      final snapshot = await FirebaseService.realtime.ref('users/$userId').get().timeout(const Duration(seconds: 3));
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return {
          ...defaults,
          if (data.containsKey('allowIncomingMessages')) 'allowIncomingMessages': data['allowIncomingMessages'] == true,
          if (data.containsKey('allowAnyUserMessage')) 'allowAnyUserMessage': data['allowAnyUserMessage'] == true,
          if (data.containsKey('allowIncomingCalls')) 'allowIncomingCalls': data['allowIncomingCalls'] == true,
        };
      }
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB getPrivacy note: $e');
    }

    // 2. Try Firestore as secondary source
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get().timeout(const Duration(seconds: 3));
      if (snapshot.exists && snapshot.data() != null) {
        final data = Map<String, dynamic>.from(snapshot.data()!);
        return {
          ...defaults,
          if (data.containsKey('allowIncomingMessages')) 'allowIncomingMessages': data['allowIncomingMessages'] == true,
          if (data.containsKey('allowAnyUserMessage')) 'allowAnyUserMessage': data['allowAnyUserMessage'] == true,
          if (data.containsKey('allowIncomingCalls')) 'allowIncomingCalls': data['allowIncomingCalls'] == true,
        };
      }
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore getPrivacy note: $e');
    }

    return defaults;
  }

  Future<void> updatePrivacy({
    required bool allowIncomingMessages,
    required bool allowAnyUserMessage,
    required bool allowIncomingCalls,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Please sign in first.');

    final updates = {
      'allowIncomingMessages': allowIncomingMessages,
      'allowAnyUserMessage': allowAnyUserMessage,
      'allowIncomingCalls': allowIncomingCalls,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Update Realtime Database
    try {
      await FirebaseService.realtime.ref('users/$uid').update(updates);
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB updatePrivacy error: $e');
    }

    // Update Firestore
    try {
      await _firestore.collection('users').doc(uid).set({
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore updatePrivacy error: $e');
    }
  }

  String _requestId(String fromId, String toId) => '${fromId}_$toId';

  Future<String?> getRequestStatus(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null || otherUserId.isEmpty) return null;

    final reqOut = _requestId(uid, otherUserId);
    final reqIn = _requestId(otherUserId, uid);

    // Check Realtime Database
    try {
      final outSnap = await FirebaseService.realtime.ref('message_requests/$reqOut').get().timeout(const Duration(seconds: 3));
      if (outSnap.exists && outSnap.value is Map) {
        final data = Map<String, dynamic>.from(outSnap.value as Map);
        return data['status']?.toString();
      }
      final inSnap = await FirebaseService.realtime.ref('message_requests/$reqIn').get().timeout(const Duration(seconds: 3));
      if (inSnap.exists && inSnap.value is Map) {
        final data = Map<String, dynamic>.from(inSnap.value as Map);
        return data['status']?.toString();
      }
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB getRequestStatus note: $e');
    }

    // Check Firestore
    try {
      final outgoing = await _firestore.collection('messageRequests').doc(reqOut).get().timeout(const Duration(seconds: 3));
      if (outgoing.exists) return outgoing.data()?['status']?.toString();

      final incoming = await _firestore.collection('messageRequests').doc(reqIn).get().timeout(const Duration(seconds: 3));
      if (incoming.exists) return incoming.data()?['status']?.toString();
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore getRequestStatus note: $e');
    }

    return null;
  }

  Future<void> sendMessageRequest({
    required String toUserId,
    String message = '',
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Please sign in first.');
    if (uid == toUserId) throw Exception('You cannot message yourself.');

    final privacy = await getPrivacy(toUserId);
    if (privacy['allowIncomingMessages'] != true) {
      throw Exception('This user is not accepting incoming messages.');
    }
    if (privacy['allowAnyUserMessage'] == true) {
      // Direct messaging accepted, no request needed
      return;
    }

    final requestId = _requestId(uid, toUserId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final requestPayload = {
      'id': requestId,
      'fromId': uid,
      'toId': toUserId,
      'status': 'pending',
      'message': message.trim(),
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };

    // Save to Realtime Database
    try {
      await FirebaseService.realtime.ref('message_requests/$requestId').set(requestPayload);
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB sendMessageRequest note: $e');
    }

    // Save to Firestore
    try {
      await _firestore.collection('messageRequests').doc(requestId).set({
        ...requestPayload,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore sendMessageRequest note: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> incomingRequests() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);

    // Return stream from Realtime Database
    return FirebaseService.realtime
        .ref('message_requests')
        .orderByChild('toId')
        .equalTo(uid)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <Map<String, dynamic>>[];
      final list = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        if (value is Map) {
          final item = Map<String, dynamic>.from(value);
          item['id'] = key.toString();
          if (item['status'] == 'pending') {
            list.add(item);
          }
        }
      });
      return list;
    });
  }

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Please sign in first.');

    final status = accept ? 'accepted' : 'rejected';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await FirebaseService.realtime.ref('message_requests/$requestId').update({
        'status': status,
        'updatedAt': nowIso,
      });
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB respondToRequest note: $e');
    }

    try {
      await _firestore.collection('messageRequests').doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore respondToRequest note: $e');
    }
  }

  Future<bool> canMessage(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null || otherUserId.isEmpty) return false;
    if (uid == otherUserId) return true;

    try {
      final privacy = await getPrivacy(otherUserId);
      if (privacy['allowIncomingMessages'] != true) return false;
      if (privacy['allowAnyUserMessage'] == true) return true;
      return await getRequestStatus(otherUserId) == 'accepted';
    } catch (e) {
      debugPrint('[ContactRequestService] canMessage check error: $e');
      // Default to allowing chat if privacy check fails to prevent user lock-out
      return true;
    }
  }

  Future<void> blockUser(String blockedUserId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Please sign in first.');

    final blockId = _requestId(uid, blockedUserId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final blockPayload = {
      'id': blockId,
      'blockerId': uid,
      'blockedId': blockedUserId,
      'createdAt': nowIso,
    };

    try {
      await FirebaseService.realtime.ref('blocked_users/$blockId').set(blockPayload);
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB blockUser note: $e');
    }

    try {
      await _firestore.collection('blockedUsers').doc(blockId).set({
        ...blockPayload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore blockUser note: $e');
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    final blockId = _requestId(uid, blockedUserId);

    try {
      await FirebaseService.realtime.ref('blocked_users/$blockId').remove();
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB unblockUser note: $e');
    }

    try {
      await _firestore.collection('blockedUsers').doc(blockId).delete();
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore unblockUser note: $e');
    }
  }

  Future<bool> isBlocked(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null || otherUserId.isEmpty) return false;

    final outId = _requestId(uid, otherUserId);
    final inId = _requestId(otherUserId, uid);

    try {
      // 1. Check Realtime Database
      final outSnap = await FirebaseService.realtime.ref('blocked_users/$outId').get().timeout(const Duration(seconds: 2));
      if (outSnap.exists) return true;
      final inSnap = await FirebaseService.realtime.ref('blocked_users/$inId').get().timeout(const Duration(seconds: 2));
      if (inSnap.exists) return true;
    } catch (e) {
      debugPrint('[ContactRequestService] RTDB isBlocked note: $e');
    }

    try {
      // 2. Check Firestore
      final outgoing = await _firestore.collection('blockedUsers').doc(outId).get().timeout(const Duration(seconds: 2));
      if (outgoing.exists) return true;
      final incoming = await _firestore.collection('blockedUsers').doc(inId).get().timeout(const Duration(seconds: 2));
      return incoming.exists;
    } catch (e) {
      debugPrint('[ContactRequestService] Firestore isBlocked note: $e');
    }

    return false;
  }
}
