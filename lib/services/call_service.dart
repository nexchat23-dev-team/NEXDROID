import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> initiateCall({
    required String receiverId,
    bool isVideo = false,
    String? groupId,
  }) async {
    try {
      final uid = currentUserId;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Check if receiver explicitly blocked calls (fail-safe)
      try {
        final receiverProfile = await FirebaseService.getUserProfile(receiverId);
        if (receiverProfile != null && receiverProfile['allowIncomingCalls'] == false) {
          throw Exception('This user is not accepting incoming calls.');
        }
      } catch (e) {
        debugPrint('[CallService] Note checking receiver profile: $e');
      }

      String? callerName;
      try {
        final myProfile = await FirebaseService.getUserProfile(uid);
        callerName = AuthService.resolveDisplayName(
          name: myProfile?['displayName'] ?? myProfile?['display_name'] ?? myProfile?['name'],
          username: myProfile?['username'],
          email: myProfile?['email'] ?? _auth.currentUser?.email,
        );
      } catch (_) {}

      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}_$uid';

      final callPayload = <String, dynamic>{
        'id': callId,
        'callId': callId,
        'callerId': uid,
        'callerName': callerName ?? 'Operative',
        'receiverId': receiverId,
        'groupId': groupId,
        'isVideo': isVideo,
        'status': 'pending',
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'endedAt': null,
        'connectedAt': null,
      };

      // 1. Write to Realtime Database: root and direct receiver channel
      try {
        await FirebaseService.realtime.ref('calls/$callId').set(callPayload);
        await FirebaseService.realtime.ref('user_calls/$receiverId/$callId').set(callPayload);
      } catch (e) {
        debugPrint('[CallService] RTDB initiateCall note: $e');
      }

      // 2. Write to Firestore: root, user inbox, and history
      try {
        await _firestore.collection('calls').doc(callId).set(callPayload);
        await _firestore
            .collection('users')
            .doc(receiverId)
            .collection('incoming_calls')
            .doc(callId)
            .set(callPayload);
        await _firestore.collection('callHistory').doc(callId).set({
          'callId': callId,
          'callerId': uid,
          'callerName': callerName ?? 'Operative',
          'receiverId': receiverId,
          'recipientId': receiverId,
          'groupId': groupId,
          'isVideo': isVideo,
          'status': 'pending',
          'timestamp': nowIso,
        });
      } catch (e) {
        debugPrint('[CallService] Firestore initiateCall note: $e');
      }

      // 3. Dispatch high-priority in-app & push notification
      try {
        await NotificationService().sendNotificationToUser(
          receiverId,
          isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
          '${callerName ?? "Operative"} is calling you...',
          {
            'type': 'incoming_call',
            'callId': callId,
            'isVideo': isVideo,
            'callerId': uid,
            'callerName': callerName ?? 'Operative',
          },
        );
      } catch (e) {
        debugPrint('[CallService] Push notification note: $e');
      }

      return callId;
    } catch (e) {
      debugPrint('Error initiating call: $e');
      rethrow;
    }
  }

  Future<void> updateCallStatus(String callId, String status) async {
    try {
      final uid = currentUserId;
      if (uid == null) return;

      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': nowIso,
      };

      if (status == 'active') {
        updates['connectedAt'] = nowIso;
      }
      if (status == 'ended' || status == 'rejected') {
        updates['endedAt'] = nowIso;
      }

      // 1. RTDB Update
      try {
        await FirebaseService.realtime.ref('calls/$callId').update(updates);
      } catch (e) {
        debugPrint('[CallService] RTDB updateCallStatus note: $e');
      }

      // 2. Firestore Update
      try {
        await _firestore.collection('calls').doc(callId).update(updates);
        await _firestore.collection('callHistory').doc(callId).update({
          'status': status,
          'timestamp': nowIso,
        });
      } catch (e) {
        debugPrint('[CallService] Firestore updateCallStatus note: $e');
      }
    } catch (e) {
      debugPrint('Error updating call status: $e');
    }
  }

  Future<void> acceptCall(String callId) async {
    await updateCallStatus(callId, 'active');
  }

  Future<void> rejectCall(String callId) async {
    await updateCallStatus(callId, 'rejected');
  }

  Future<void> endCall(String callId) async {
    try {
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();

      // RTDB End
      try {
        await FirebaseService.realtime.ref('calls/$callId').update({
          'status': 'ended',
          'endedAt': nowIso,
          'updatedAt': nowIso,
        });
      } catch (_) {}

      // Firestore End
      try {
        await _firestore.collection('calls').doc(callId).update({
          'status': 'ended',
          'endedAt': nowIso,
          'updatedAt': nowIso,
        });
        await _firestore.collection('callHistory').doc(callId).update({
          'status': 'ended',
          'timestamp': nowIso,
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getActiveCalls() {
    final uid = currentUserId;
    if (uid == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> map = {};

    void emit() {
      if (controller.isClosed) return;
      final activeList = map.values.where((c) {
        final callerId = c['callerId']?.toString();
        final receiverId = c['receiverId']?.toString();
        final status = (c['status'] as String?)?.toLowerCase();
        return (callerId == uid || receiverId == uid) && (status == 'pending' || status == 'active');
      }).toList();
      controller.add(activeList);
    }

    StreamSubscription<DatabaseEvent>? rtdbSub;
    try {
      rtdbSub = FirebaseService.realtime.ref('calls').onValue.listen((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          val.forEach((k, v) {
            if (v is Map) {
              final data = Map<String, dynamic>.from(v);
              data['id'] = k.toString();
              map[k.toString()] = data;
            }
          });
          emit();
        }
      }, onError: (_) {});
    } catch (_) {}

    StreamSubscription<QuerySnapshot>? firestoreSub;
    try {
      firestoreSub = _firestore.collection('calls').snapshots().listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          map[doc.id] = data;
        }
        emit();
      }, onError: (_) {});
    } catch (_) {}

    controller.onCancel = () {
      rtdbSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getIncomingCalls() {
    final uid = currentUserId;
    if (uid == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> callsMap = {};

    void emitFiltered() {
      if (controller.isClosed) return;
      final pendingCalls = callsMap.values.where((c) {
        final receiverId = c['receiverId']?.toString();
        final status = (c['status'] as String?)?.toLowerCase();
        return receiverId == uid && status == 'pending';
      }).toList();

      pendingCalls.sort((a, b) {
        final aTime = a['createdAt']?.toString() ?? '';
        final bTime = b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });

      controller.add(pendingCalls);
    }

    // 1. Direct RTDB user channel (Fastest direct incoming signal)
    StreamSubscription<DatabaseEvent>? userRtdbSub;
    try {
      userRtdbSub = FirebaseService.realtime.ref('user_calls/$uid').onValue.listen((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          val.forEach((k, v) {
            if (v is Map) {
              final data = Map<String, dynamic>.from(v);
              data['id'] = k.toString();
              callsMap[k.toString()] = data;
            }
          });
          emitFiltered();
        }
      }, onError: (_) {});
    } catch (_) {}

    // 2. Global RTDB listener
    StreamSubscription<DatabaseEvent>? rtdbSub;
    try {
      rtdbSub = FirebaseService.realtime.ref('calls').onValue.listen((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          val.forEach((k, v) {
            if (v is Map) {
              final data = Map<String, dynamic>.from(v);
              data['id'] = k.toString();
              callsMap[k.toString()] = data;
            }
          });
          emitFiltered();
        }
      }, onError: (_) {});
    } catch (_) {}

    // 3. Direct Firestore user incoming_calls listener
    StreamSubscription<QuerySnapshot>? userFirestoreSub;
    try {
      userFirestoreSub = _firestore
          .collection('users')
          .doc(uid)
          .collection('incoming_calls')
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          callsMap[doc.id] = data;
        }
        emitFiltered();
      }, onError: (_) {});
    } catch (_) {}

    // 4. Filtered Firestore queries
    StreamSubscription<QuerySnapshot>? firestoreSub;
    try {
      firestoreSub = _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          callsMap[doc.id] = data;
        }
        emitFiltered();
      }, onError: (_) {});
    } catch (_) {}

    controller.onCancel = () {
      userRtdbSub?.cancel();
      rtdbSub?.cancel();
      userFirestoreSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  Stream<Map<String, dynamic>> watchCall(String callId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    // 1. RTDB listener
    final rtdbSub = FirebaseService.realtime.ref('calls/$callId').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is Map && !controller.isClosed) {
        controller.add(Map<String, dynamic>.from(val));
      }
    }, onError: (_) {});

    // 2. Firestore listener
    final firestoreSub = _firestore.collection('calls').doc(callId).snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null && !controller.isClosed) {
        controller.add(Map<String, dynamic>.from(data));
      }
    }, onError: (_) {});

    controller.onCancel = () {
      rtdbSub.cancel();
      firestoreSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getCallHistory() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('callHistory')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) {
                final data = Map<String, dynamic>.from(doc.data());
                data['id'] = doc.id;
                return data;
              })
              .where((row) {
                final callerId = row['callerId']?.toString();
                final receiverId = row['receiverId']?.toString();
                final recipientId = row['recipientId']?.toString();
                return callerId == currentUserId || receiverId == currentUserId || recipientId == currentUserId;
              })
              .toList();
          list.sort((a, b) {
            final aTime = a['timestamp']?.toString() ?? '';
            final bTime = b['timestamp']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        })
        .handleError((e) {
          debugPrint('Error getting call history: $e');
          return <Map<String, dynamic>>[];
        });
  }

  Future<void> addIceCandidate(
      String callId, Map<String, dynamic> candidate) async {
    try {
      final uid = currentUserId;
      if (uid == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      final candData = {
        'callId': callId,
        'from': uid,
        'candidate': candidate,
        'timestamp': now,
      };

      // 1. RTDB
      try {
        await FirebaseService.realtime.ref('calls/$callId/iceCandidates').push().set(candData);
      } catch (_) {}

      // 2. Firestore
      try {
        await _firestore.collection('iceCandidates').add(candData);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error adding ICE candidate: $e');
    }
  }

  Future<void> setSDP(String callId, String type, String sdp) async {
    try {
      final uid = currentUserId;
      if (uid == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      final sdpData = {
        'call_id': callId,
        'from': uid,
        'type': type,
        'sdp': sdp,
        'timestamp': now,
      };

      // 1. RTDB
      try {
        await FirebaseService.realtime.ref('calls/$callId/sdp/$type').set(sdpData);
      } catch (_) {}

      // 2. Firestore
      try {
        await _firestore.collection('calls').doc(callId).collection('sdp').doc(type).set(sdpData);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error setting SDP: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getIceCandidates(String callId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> map = {};

    void emit() {
      if (!controller.isClosed) {
        controller.add(map.values.toList());
      }
    }

    // 1. RTDB
    final rtdbSub = FirebaseService.realtime.ref('calls/$callId/iceCandidates').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          if (v is Map) {
            map[k.toString()] = Map<String, dynamic>.from(v);
          }
        });
        emit();
      }
    }, onError: (_) {});

    // 2. Firestore
    final firestoreSub = _firestore
        .collection('iceCandidates')
        .where('callId', isEqualTo: callId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        map[doc.id] = Map<String, dynamic>.from(doc.data());
      }
      emit();
    }, onError: (_) {});

    controller.onCancel = () {
      rtdbSub.cancel();
      firestoreSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getSDP(String callId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> map = {};

    void emit() {
      if (!controller.isClosed) {
        controller.add(map.values.toList());
      }
    }

    // 1. RTDB
    final rtdbSub = FirebaseService.realtime.ref('calls/$callId/sdp').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          if (v is Map) {
            map[k.toString()] = Map<String, dynamic>.from(v);
          }
        });
        emit();
      }
    }, onError: (_) {});

    // 2. Firestore
    final firestoreSub = _firestore
        .collection('calls')
        .doc(callId)
        .collection('sdp')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        map[doc.id] = Map<String, dynamic>.from(doc.data());
      }
      emit();
    }, onError: (_) {});

    controller.onCancel = () {
      rtdbSub.cancel();
      firestoreSub.cancel();
    };

    return controller.stream;
  }

  Future<String> initiateGroupCall({
    required String groupId,
    bool isVideo = false,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toUtc();
      final groupCallRef = await _firestore.collection('groupCalls').add({
        'groupId': groupId,
        'initiatorId': currentUserId,
        'isVideo': isVideo,
        'status': 'pending',
        'participants': [currentUserId],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      return groupCallRef.id;
    } catch (e) {
      debugPrint('Error initiating group call: $e');
      rethrow;
    }
  }

  Future<void> joinGroupCall(String groupCallId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final groupCallDoc = await _firestore.collection('groupCalls').doc(groupCallId).get();
      if (!groupCallDoc.exists) {
        throw Exception('Group call not found');
      }

      final groupCallData = groupCallDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(groupCallData['participants'] ?? []);
      
      if (!participants.contains(currentUserId)) {
        participants.add(currentUserId!);
        await _firestore.collection('groupCalls').doc(groupCallId).update({'participants': participants});
        await _firestore.collection('groupCallParticipants').add({
          'group_call_id': groupCallId,
          'userId': currentUserId,
          'joinedAt': DateTime.now().toUtc().toIso8601String(),
          'status': 'connected',
        });
      }
    } catch (e) {
      debugPrint('Error joining group call: $e');
      rethrow;
    }
  }

  Future<void> leaveGroupCall(String groupCallId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final groupCallDoc = await _firestore.collection('groupCalls').doc(groupCallId).get();
      if (!groupCallDoc.exists) {
        throw Exception('Group call not found');
      }

      final groupCallData = groupCallDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(groupCallData['participants'] ?? []);
      final initiatorId = groupCallData['initiatorId'];

      participants.remove(currentUserId);

      if (participants.isEmpty) {
        await _firestore.collection('groupCalls').doc(groupCallId).update({
          'status': 'ended',
          'endTime': DateTime.now().toUtc().toIso8601String(),
          'participants': participants,
        });
      } else {
        await _firestore.collection('groupCalls').doc(groupCallId).update({'participants': participants});
        if (currentUserId == initiatorId && participants.isNotEmpty) {
          await _firestore.collection('groupCalls').doc(groupCallId).update({'initiatorId': participants.first});
        }
      }

      final participantDocs = await _firestore
          .collection('groupCallParticipants')
          .where('group_call_id', isEqualTo: groupCallId)
          .where('userId', isEqualTo: currentUserId)
          .get();
      
      for (final doc in participantDocs.docs) {
        await doc.reference.update({
          'leftAt': DateTime.now().toUtc().toIso8601String(),
          'status': 'disconnected',
        });
      }
    } catch (e) {
      debugPrint('Error leaving group call: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getActiveGroupCalls() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('groupCalls')
        .where('status', whereIn: ['pending', 'active'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = Map<String, dynamic>.from(doc.data());
                data['id'] = doc.id;
                return data;
              })
              .toList();
        })
        .handleError((e) {
          debugPrint('Error getting active group calls: $e');
        });
  }
}
