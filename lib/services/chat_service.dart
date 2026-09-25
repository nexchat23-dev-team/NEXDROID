import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth_service.dart';
import 'cloudinary_storage_service.dart';
import 'firebase_service.dart';
import 'upload_progress_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  static String getDirectConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'direct_${sorted[0]}_${sorted[1]}';
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(DateTime.now().millisecondsSinceEpoch + i) % chars.length];
    }
    return code;
  }

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String type = 'text',
    String? audioUrl,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? audioDuration,
    String? replyTo,
    String? replyText,
    String? replySender,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      debugPrint('Error: No current user in sendMessage');
      return;
    }

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_$uid';

    final messageData = <String, dynamic>{
      'id': messageId,
      'conversationId': conversationId,
      'senderId': uid,
      'text': text,
      'type': type,
      'createdAt': nowIso,
      'timestamp': nowIso,
    };
    if (audioUrl != null) messageData['audioUrl'] = audioUrl;
    if (imageUrl != null) messageData['imageUrl'] = imageUrl;
    if (fileUrl != null) messageData['fileUrl'] = fileUrl;
    if (fileName != null) messageData['fileName'] = fileName;
    if (fileSize != null) messageData['fileSize'] = fileSize;
    if (audioDuration != null) messageData['audioDuration'] = audioDuration;
    if (replyTo != null) messageData['replyTo'] = replyTo;
    if (replyText != null) messageData['replyText'] = replyText;
    if (replySender != null) messageData['replySender'] = replySender;

    // 1. Write to Realtime Database immediately for instant delivery & offline support
    try {
      await FirebaseService.realtime
          .ref('messages/$conversationId/$messageId')
          .set(messageData);
    } catch (e) {
      debugPrint('[ChatService] RTDB sendMessage note: $e');
    }

    // 2. Write to Firestore in background
    try {
      final firestorePayload = Map<String, dynamic>.from(messageData);
      firestorePayload['createdAt'] = Timestamp.fromDate(now);
      await _firestore
          .collection('messages')
          .doc(messageId)
          .set(firestorePayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[ChatService] Firestore sendMessage note: $e');
    }

    // 3. Update last message
    String preview = text.isNotEmpty ? text : 'New message';
    if (type == 'image') {
      preview = '[Photo]';
    } else if (type == 'audio') {
      preview = '[Voice note]';
    } else if (type == 'file' || type == 'document') {
      preview = '[File] ${fileName ?? 'Document'}';
    }
    await updateLastMessage(conversationId, preview);
  }

  Future<String> uploadAudioMessage(String conversationId, String filePath) async {
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final uploadId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();

    uploadService.startUpload(
      id: uploadId,
      fileName: 'Audio: $fileName',
      totalBytes: fileSize,
    );

    // 1. Try Cloudinary Multi-Vault Storage first
    try {
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize ~/ 2,
        totalBytes: fileSize,
      );
      final cdnUrl = await CloudinaryStorageService.instance.uploadAudio(
        file: file,
        folder: 'nexchat-audio',
      );
      if (cdnUrl.isNotEmpty) {
        uploadService.completeUpload(id: uploadId);
        return cdnUrl;
      }
    } catch (e) {
      debugPrint('[ChatService] Cloudinary audio notice: $e');
    }

    // 2. Secondary fallback: Firebase Storage
    try {
      final path = 'audio_messages/$conversationId/$fileName';
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize * 3 ~/ 4,
        totalBytes: fileSize,
      );
      await _storage.ref(path).putFile(file);
      uploadService.completeUpload(id: uploadId);
      final url = await _storage.ref(path).getDownloadURL();
      return url;
    } catch (e) {
      uploadService.failUpload(id: uploadId, error: 'Audio upload failed: $e');
      rethrow;
    }
  }

  Future<String> uploadImageMessage(String conversationId, String filePath) async {
    final file = File(filePath);
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final fileSize = await file.length();
    final uploadId = 'img_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();

    uploadService.startUpload(
      id: uploadId,
      fileName: 'Photo: $fileName',
      totalBytes: fileSize,
    );

    // 1. Try Cloudinary Multi-Vault Storage first
    try {
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize ~/ 2,
        totalBytes: fileSize,
      );
      final cdnUrl = await CloudinaryStorageService.instance.uploadImage(
        file: file,
        folder: 'nexchat-chat-images',
      );
      if (cdnUrl.isNotEmpty) {
        uploadService.completeUpload(id: uploadId);
        return cdnUrl;
      }
    } catch (e) {
      debugPrint('[ChatService] Cloudinary image notice: $e');
    }

    // 2. Secondary fallback: Firebase Storage
    try {
      final path = 'chat_images/$conversationId/$fileName';
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize * 3 ~/ 4,
        totalBytes: fileSize,
      );
      await _storage.ref(path).putFile(file);
      uploadService.completeUpload(id: uploadId);
      final url = await _storage.ref(path).getDownloadURL();
      return url;
    } catch (e) {
      uploadService.failUpload(id: uploadId, error: 'Image upload failed: $e');
      rethrow;
    }
  }

  Future<String> uploadFileMessage(String conversationId, String filePath, String originalName) async {
    final file = File(filePath);
    final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}_$originalName';
    final fileSize = await file.length();
    final uploadId = 'file_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();

    uploadService.startUpload(
      id: uploadId,
      fileName: originalName,
      totalBytes: fileSize,
    );

    // 1. Try Cloudinary Multi-Vault Storage first
    try {
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize ~/ 2,
        totalBytes: fileSize,
      );
      final res = await CloudinaryStorageService.instance.uploadMedia(
        file: file,
        fileName: originalName,
        resourceType: 'auto',
        folder: 'nexchat-documents',
      );
      if (res.secureUrl.isNotEmpty) {
        uploadService.completeUpload(id: uploadId);
        return res.secureUrl;
      }
    } catch (e) {
      debugPrint('[ChatService] Cloudinary document notice: $e');
    }

    // 2. Secondary fallback: Firebase Storage
    try {
      final path = 'chat_files/$conversationId/$fileName';
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize * 3 ~/ 4,
        totalBytes: fileSize,
      );
      await _storage.ref(path).putFile(file);
      uploadService.completeUpload(id: uploadId);
      final url = await _storage.ref(path).getDownloadURL();
      return url;
    } catch (e) {
      uploadService.failUpload(id: uploadId, error: 'Document upload failed: $e');
      rethrow;
    }
  }

  Future<void> setTypingStatus(String conversationId, bool isTyping) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      if (isTyping) {
        await FirebaseService.realtime
            .ref('typing/$conversationId/$uid')
            .set(true);
      } else {
        await FirebaseService.realtime
            .ref('typing/$conversationId/$uid')
            .remove();
      }
    } catch (_) {}
  }

  Stream<List<String>> getTypingUsersStream(String conversationId) {
    final uid = currentUserId;
    return FirebaseService.realtime
        .ref('typing/$conversationId')
        .onValue
        .map((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        final typing = <String>[];
        val.forEach((k, v) {
          if (v == true && k.toString() != uid) {
            typing.add(k.toString());
          }
        });
        return typing;
      }
      return <String>[];
    });
  }

  Future<void> toggleReaction(String conversationId, String messageId, String emoji) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final ref = FirebaseService.realtime.ref('messages/$conversationId/$messageId/reactions/$uid');
      final snap = await ref.get();
      if (snap.exists && snap.value == emoji) {
        await ref.remove();
      } else {
        await ref.set(emoji);
      }
    } catch (_) {}

    try {
      final docRef = _firestore.collection('messages').doc(messageId);
      final snap = await docRef.get();
      if (snap.exists) {
        final currentReactions = Map<String, dynamic>.from(snap.data()?['reactions'] ?? {});
        if (currentReactions[uid] == emoji) {
          currentReactions.remove(uid);
        } else {
          currentReactions[uid] = emoji;
        }
        await docRef.update({'reactions': currentReactions});
      }
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    if (currentUserId == null || conversationId.isEmpty) {
      return const Stream.empty();
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> messagesMap = {};

    void emitMerged() {
      if (controller.isClosed) return;
      final sorted = messagesMap.values.toList();
      // Sort descending: newest first so reverse ListView renders properly
      sorted.sort((a, b) {
        final aTime = a['timestamp']?.toString() ?? a['createdAt']?.toString() ?? '';
        final bTime = b['timestamp']?.toString() ?? b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
      controller.add(sorted);
    }

    // 1. Realtime Database listener
    StreamSubscription<DatabaseEvent>? rtdbSub;
    try {
      rtdbSub = FirebaseService.realtime
          .ref('messages/$conversationId')
          .onValue
          .listen((event) {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          data.forEach((k, v) {
            if (v is Map) {
              final msg = Map<String, dynamic>.from(v);
              final id = msg['id']?.toString() ?? k.toString();
              msg['id'] = id;
              messagesMap[id] = msg;
            }
          });
          emitMerged();
        }
      }, onError: (e) {
        debugPrint('[ChatService] RTDB messages stream note: $e');
      });
    } catch (e) {
      debugPrint('[ChatService] RTDB stream error: $e');
    }

    // 2. Firestore listener
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    try {
      firestoreSub = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = _addIdToData(doc);
          final id = doc.id;
          final existing = messagesMap[id];
          messagesMap[id] = {
            ...existing ?? {},
            ...data,
            'id': id,
          };
        }
        emitMerged();
      }, onError: (e) {
        debugPrint('[ChatService] Firestore messages stream note: $e');
      });
    } catch (e) {
      debugPrint('[ChatService] Firestore stream init note: $e');
    }

    controller.onCancel = () {
      rtdbSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  Future<String> createConversation({
    required List<String> participantIds,
    String? groupName,
    bool isGroup = false,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('No current user signed in.');
    }

    final convId = isGroup
        ? 'group_${DateTime.now().millisecondsSinceEpoch}_$uid'
        : (participantIds.length == 2
            ? getDirectConversationId(participantIds[0], participantIds[1])
            : 'conv_${DateTime.now().millisecondsSinceEpoch}_$uid');

    final inviteCode = isGroup ? _generateInviteCode() : null;
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    final convData = <String, dynamic>{
      'id': convId,
      'createdBy': uid,
      'participants': participantIds,
      'isGroup': isGroup,
      'groupName': groupName,
      'admins': isGroup ? [uid] : <String>[],
      'createdAt': nowIso,
      'lastMessage': null,
      'lastMessageTime': nowIso,
      'autoJoinEnabled': false,
      if (inviteCode != null) 'inviteCode': inviteCode,
      if (inviteCode != null) 'inviteLink': 'nex://group/$inviteCode',
    };

    // Save to Realtime Database
    try {
      await FirebaseService.realtime.ref('conversations/$convId').set(convData);
    } catch (e) {
      debugPrint('[ChatService] RTDB createConversation note: $e');
    }

    // Save to Firestore
    try {
      final firestorePayload = Map<String, dynamic>.from(convData);
      firestorePayload['createdAt'] = Timestamp.fromDate(now);
      await _firestore
          .collection('conversations')
          .doc(convId)
          .set(firestorePayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[ChatService] Firestore createConversation note: $e');
    }

    return convId;
  }

  Future<String> createOrGetDirectConversation(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('No current user signed in.');
    }

    final convId = getDirectConversationId(uid, otherUserId);
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    String? myName;
    String? otherName;
    try {
      final myProfile = await FirebaseService.getUserProfile(uid);
      final otherProfile = await FirebaseService.getUserProfile(otherUserId);
      myName = AuthService.resolveDisplayName(
        name: myProfile?['displayName'] ?? myProfile?['display_name'] ?? myProfile?['name'],
        username: myProfile?['username'],
        email: myProfile?['email'] ?? _auth.currentUser?.email,
      );
      otherName = AuthService.resolveDisplayName(
        name: otherProfile?['displayName'] ?? otherProfile?['display_name'] ?? otherProfile?['name'],
        username: otherProfile?['username'],
        email: otherProfile?['email'],
      );
    } catch (_) {}

    final convData = <String, dynamic>{
      'id': convId,
      'createdBy': uid,
      'participants': [uid, otherUserId],
      'participantNames': {
        if (myName != null) uid: myName,
        if (otherName != null) otherUserId: otherName,
      },
      'isGroup': false,
      'groupName': null,
      'admins': <String>[],
      'createdAt': nowIso,
      'lastMessageTime': nowIso,
      'autoJoinEnabled': false,
    };

    // Synchronize to Realtime Database immediately
    try {
      final snap = await FirebaseService.realtime.ref('conversations/$convId').get().timeout(const Duration(seconds: 2));
      if (!snap.exists) {
        await FirebaseService.realtime.ref('conversations/$convId').set(convData);
      }
    } catch (e) {
      debugPrint('[ChatService] RTDB direct conv check note: $e');
      // If get failed, attempt background set
      unawaited(FirebaseService.realtime.ref('conversations/$convId').update(convData).catchError((_) {}));
    }

    // Synchronize to Firestore in background
    try {
      final firestorePayload = Map<String, dynamic>.from(convData);
      firestorePayload['createdAt'] = Timestamp.fromDate(now);
      await _firestore
          .collection('conversations')
          .doc(convId)
          .set(firestorePayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[ChatService] Firestore direct conv note: $e');
    }

    return convId;
  }

  Stream<List<Map<String, dynamic>>> getConversations() {
    final uid = currentUserId;
    if (uid == null) {
      return const Stream.empty();
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> conversationsMap = {};

    void emitMerged() {
      if (controller.isClosed) return;
      final sorted = conversationsMap.values.toList();
      sorted.sort((a, b) {
        final aTime = a['lastMessageTime']?.toString() ?? a['createdAt']?.toString() ?? '';
        final bTime = b['lastMessageTime']?.toString() ?? b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
      controller.add(sorted);
    }

    // 1. Realtime Database stream
    StreamSubscription<DatabaseEvent>? rtdbSub;
    try {
      rtdbSub = FirebaseService.realtime.ref('conversations').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          data.forEach((k, v) {
            if (v is Map) {
              final conv = Map<String, dynamic>.from(v);
              final id = conv['id']?.toString() ?? k.toString();
              conv['id'] = id;
              final participants = List<dynamic>.from(conv['participants'] ?? const []);
              if (participants.contains(uid)) {
                conversationsMap[id] = conv;
              }
            }
          });
          emitMerged();
        }
      }, onError: (e) {
        debugPrint('[ChatService] RTDB conversations stream note: $e');
      });
    } catch (e) {
      debugPrint('[ChatService] RTDB conversations listener error: $e');
    }

    // 2. Firestore stream
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    try {
      firestoreSub = _firestore
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = _addIdToData(doc);
          final id = doc.id;
          final existing = conversationsMap[id];
          conversationsMap[id] = {
            ...existing ?? {},
            ...data,
            'id': id,
          };
        }
        emitMerged();
      }, onError: (e) {
        debugPrint('[ChatService] Firestore conversations stream note: $e');
      });
    } catch (e) {
      debugPrint('[ChatService] Firestore conversations init note: $e');
    }

    controller.onCancel = () {
      rtdbSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> updateLastMessage(String conversationId, String text) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updateData = {
      'lastMessage': text,
      'lastMessageTime': nowIso,
    };

    try {
      await FirebaseService.realtime.ref('conversations/$conversationId').update(updateData);
    } catch (e) {
      debugPrint('[ChatService] RTDB updateLastMessage note: $e');
    }

    try {
      await _firestore.collection('conversations').doc(conversationId).set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] Firestore updateLastMessage note: $e');
    }
  }

  Future<void> addMember(String conversationId, String userId) async {
    try {
      final doc = await getConversation(conversationId);
      final participants = List<String>.from(doc['participants'] ?? []);
      if (!participants.contains(userId)) {
        participants.add(userId);
        await FirebaseService.realtime.ref('conversations/$conversationId').update({
          'participants': participants,
        });
        try {
          await _firestore.collection('conversations').doc(conversationId).update({
            'participants': participants,
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error adding member: $e');
      rethrow;
    }
  }

  Future<void> removeMember(String conversationId, String userId) async {
    try {
      final doc = await getConversation(conversationId);
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(userId)) {
        participants.remove(userId);
        await FirebaseService.realtime.ref('conversations/$conversationId').update({
          'participants': participants,
        });
        try {
          await _firestore.collection('conversations').doc(conversationId).update({
            'participants': participants,
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    // 1. Try RTDB
    try {
      final snap = await FirebaseService.realtime.ref('conversations/$conversationId').get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        data['id'] = conversationId;
        return data;
      }
    } catch (e) {
      debugPrint('[ChatService] RTDB getConversation note: $e');
    }

    // 2. Try Firestore
    try {
      final doc = await _firestore.collection('conversations').doc(conversationId).get().timeout(const Duration(seconds: 3));
      if (doc.exists && doc.data() != null) {
        return _addIdToData(doc);
      }
    } catch (e) {
      debugPrint('[ChatService] Firestore getConversation note: $e');
    }

    // 3. Fallback for deterministic direct conversation IDs
    if (conversationId.startsWith('direct_')) {
      final parts = conversationId.replaceFirst('direct_', '').split('_');
      if (parts.length == 2) {
        return {
          'id': conversationId,
          'participants': parts,
          'isGroup': false,
          'groupName': null,
          'admins': <String>[],
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
    }

    return {'id': conversationId, 'participants': <String>[]};
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    try {
      await FirebaseService.realtime.ref('messages/$conversationId/$messageId').remove();
    } catch (e) {
      debugPrint('[ChatService] RTDB deleteMessage note: $e');
    }

    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e) {
      debugPrint('[ChatService] Firestore deleteMessage note: $e');
    }
  }

  Future<void> archiveConversation(String conversationId) async {
    final uid = currentUserId;
    await FirebaseService.realtime.ref('conversations/$conversationId').update({'archived': true}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'archived': true}).catchError((_) {});
    if (uid != null) {
      await FirebaseService.realtime.ref('conversations/$conversationId/archivedBy/$uid').set(true).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({
        'archivedBy.$uid': true,
      }).catchError((_) {});
    }
  }

  Future<void> unarchiveConversation(String conversationId) async {
    final uid = currentUserId;
    await FirebaseService.realtime.ref('conversations/$conversationId').update({'archived': false}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'archived': false}).catchError((_) {});
    if (uid != null) {
      await FirebaseService.realtime.ref('conversations/$conversationId/archivedBy/$uid').set(false).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({
        'archivedBy.$uid': false,
      }).catchError((_) {});
    }
  }

  Future<void> pinConversation(String conversationId) async {
    final uid = currentUserId;
    await FirebaseService.realtime.ref('conversations/$conversationId').update({'pinned': true}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'pinned': true}).catchError((_) {});
    if (uid != null) {
      await FirebaseService.realtime.ref('conversations/$conversationId/pinnedBy/$uid').set(true).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({
        'pinnedBy.$uid': true,
      }).catchError((_) {});
    }
  }

  Future<void> unpinConversation(String conversationId) async {
    final uid = currentUserId;
    await FirebaseService.realtime.ref('conversations/$conversationId').update({'pinned': false}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'pinned': false}).catchError((_) {});
    if (uid != null) {
      await FirebaseService.realtime.ref('conversations/$conversationId/pinnedBy/$uid').set(false).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({
        'pinnedBy.$uid': false,
      }).catchError((_) {});
    }
  }

  Future<void> muteConversation(String conversationId) async {
    final uid = currentUserId;
    await FirebaseService.realtime.ref('conversations/$conversationId').update({'muted': true}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'muted': true}).catchError((_) {});
    if (uid != null) {
      final muteId = '${uid}_$conversationId';
      await FirebaseService.realtime.ref('muted_chats/$muteId').set({'userId': uid, 'conversationId': conversationId}).catchError((_) {});
      await _firestore.collection('mutedChats').doc(muteId).set({'userId': uid, 'conversationId': conversationId}).catchError((_) {});
    }
  }

  Future<void> unmuteConversation(String conversationId) async {
    final uid = currentUserId;
    await FirebaseService.realtime.ref('conversations/$conversationId').update({'muted': false}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'muted': false}).catchError((_) {});
    if (uid != null) {
      final muteId = '${uid}_$conversationId';
      await FirebaseService.realtime.ref('muted_chats/$muteId').remove().catchError((_) {});
      await _firestore.collection('mutedChats').doc(muteId).delete().catchError((_) {});
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await FirebaseService.realtime.ref('conversations/$conversationId/unreadCounts/$uid').set(0).catchError((_) {});
      await FirebaseService.realtime.ref('conversations/$conversationId').update({'unreadCount': 0}).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': 0,
        'unreadCounts.$uid': 0,
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> markConversationAsUnread(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await FirebaseService.realtime.ref('conversations/$conversationId/unreadCounts/$uid').set(1).catchError((_) {});
      await FirebaseService.realtime.ref('conversations/$conversationId').update({'unreadCount': 1}).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': 1,
        'unreadCounts.$uid': 1,
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> muteChatForDuration(String conversationId, Duration duration) async {
    final uid = currentUserId;
    if (uid == null) return;
    final until = DateTime.now().toUtc().add(duration).toIso8601String();
    final muteId = '${uid}_$conversationId';
    final payload = {
      'userId': uid,
      'conversationId': conversationId,
      'mutedUntil': until,
      'mutedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await FirebaseService.realtime.ref('muted_chats/$muteId').set(payload).catchError((_) {});
    await _firestore.collection('mutedChats').doc(muteId).set(payload).catchError((_) {});
    await muteConversation(conversationId);
  }

  Future<bool> isChatMuted(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final muteId = '${uid}_$conversationId';
    try {
      final snap = await FirebaseService.realtime.ref('muted_chats/$muteId').get().timeout(const Duration(seconds: 2));
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final untilStr = data['mutedUntil'] as String?;
        if (untilStr != null) {
          final until = DateTime.tryParse(untilStr);
          if (until != null && DateTime.now().toUtc().isAfter(until)) {
            await unmuteConversation(conversationId);
            return false;
          }
        }
        return true;
      }
    } catch (_) {}
    try {
      final doc = await _firestore.collection('mutedChats').doc(muteId).get().timeout(const Duration(seconds: 2));
      return doc.exists;
    } catch (_) {}
    return false;
  }

  Future<void> blockUser(String userId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');
    final blockId = '${uid}_$userId';
    final payload = {
      'blockerId': uid,
      'blockedId': userId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await FirebaseService.realtime.ref('blocked_users/$blockId').set(payload).catchError((_) {});
    await _firestore.collection('blockedUsers').doc(blockId).set({
      'blockerId': uid,
      'blockedId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
    // Also update current user doc blocked list
    await _firestore.collection('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayUnion([userId])
    }).catchError((_) {});
  }

  Future<void> unblockUser(String userId) async {
    final uid = currentUserId;
    if (uid == null) return;
    final blockId = '${uid}_$userId';
    await FirebaseService.realtime.ref('blocked_users/$blockId').remove().catchError((_) {});
    await _firestore.collection('blockedUsers').doc(blockId).delete().catchError((_) {});
    await _firestore.collection('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayRemove([userId])
    }).catchError((_) {});
  }

  Future<bool> isUserBlocked(String userId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final blockId = '${uid}_$userId';
    try {
      final snap = await FirebaseService.realtime.ref('blocked_users/$blockId').get().timeout(const Duration(seconds: 2));
      if (snap.exists) return true;
    } catch (_) {}
    try {
      final doc = await _firestore.collection('blockedUsers').doc(blockId).get().timeout(const Duration(seconds: 2));
      return doc.exists;
    } catch (_) {}
    return false;
  }

  Stream<List<String>> getBlockedUserIdsStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();
    return FirebaseService.realtime
        .ref('blocked_users')
        .orderByChild('blockerId')
        .equalTo(uid)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <String>[];
      final list = <String>[];
      data.forEach((k, v) {
        if (v is Map && v['blockedId'] != null) {
          list.add(v['blockedId'].toString());
        }
      });
      return list;
    });
  }

  Future<void> reportUser({
    required String targetUserId,
    required String reason,
    String? conversationId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');
    final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}_$uid';
    final payload = {
      'id': reportId,
      'reportedBy': uid,
      'reporterId': uid,
      'targetUserId': targetUserId,
      'conversationId': conversationId,
      'reason': reason,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await FirebaseService.realtime.ref('user_reports/$reportId').set(payload).catchError((_) {});
    await _firestore.collection('reports').doc(reportId).set({
      ...payload,
      'createdAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> reportGroup({
    required String conversationId,
    required String groupName,
    required String reason,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');
    final reportId = 'group_report_${DateTime.now().millisecondsSinceEpoch}_$uid';
    final payload = {
      'id': reportId,
      'reportedBy': uid,
      'reporterId': uid,
      'conversationId': conversationId,
      'groupName': groupName,
      'reason': reason,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await FirebaseService.realtime.ref('group_reports/$reportId').set(payload).catchError((_) {});
    await _firestore.collection('groupReports').doc(reportId).set({
      ...payload,
      'createdAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> setChatLock(String conversationId, bool isLocked) async {
    final uid = currentUserId;
    if (uid == null) return;
    final lockId = '${uid}_$conversationId';
    if (isLocked) {
      final payload = {
        'userId': uid,
        'conversationId': conversationId,
        'locked': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await FirebaseService.realtime.ref('chat_locks/$lockId').set(payload).catchError((_) {});
      await _firestore.collection('chatLocks').doc(lockId).set(payload).catchError((_) {});
    } else {
      await FirebaseService.realtime.ref('chat_locks/$lockId').remove().catchError((_) {});
      await _firestore.collection('chatLocks').doc(lockId).delete().catchError((_) {});
    }
  }

  Future<bool> isChatLocked(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final lockId = '${uid}_$conversationId';
    try {
      final snap = await FirebaseService.realtime.ref('chat_locks/$lockId').get().timeout(const Duration(seconds: 2));
      if (snap.exists) return true;
    } catch (_) {}
    try {
      final doc = await _firestore.collection('chatLocks').doc(lockId).get().timeout(const Duration(seconds: 2));
      return doc.exists;
    } catch (_) {}
    return false;
  }

  Future<void> setDisappearingMessages(String conversationId, String duration) async {
    await FirebaseService.realtime.ref('conversations/$conversationId').update({
      'disappearingMessages': duration,
    }).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({
      'disappearingMessages': duration,
    }).catchError((_) {});
  }

  Future<void> setMediaVisibility(String conversationId, String visibility) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).collection('chatSettings').doc(conversationId).set({
      'mediaVisibility': visibility,
    }, SetOptions(merge: true)).catchError((_) {});
  }

  Future<void> toggleFavourite(String conversationId, bool isFavourite) async {
    final uid = currentUserId;
    if (uid == null) return;
    final favId = '${uid}_$conversationId';
    if (isFavourite) {
      final payload = {
        'userId': uid,
        'conversationId': conversationId,
        'favourite': true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      await FirebaseService.realtime.ref('chat_favourites/$favId').set(payload).catchError((_) {});
      await _firestore.collection('chatFavourites').doc(favId).set(payload).catchError((_) {});
    } else {
      await FirebaseService.realtime.ref('chat_favourites/$favId').remove().catchError((_) {});
      await _firestore.collection('chatFavourites').doc(favId).delete().catchError((_) {});
    }
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await FirebaseService.realtime.ref('messages/$conversationId').remove().catchError((_) {});
      final msgs = await _firestore.collection('messages').where('conversationId', isEqualTo: conversationId).get();
      final batch = _firestore.batch();
      for (final doc in msgs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatService] clearConversationMessages note: $e');
    }
  }

  Future<Map<String, dynamic>> getConversationSettings(String conversationId) async {
    try {
      final doc = await getConversation(conversationId);
      return {
        'archived': doc['archived'] ?? false,
        'pinned': doc['pinned'] ?? false,
        'muted': doc['muted'] ?? false,
      };
    } catch (e) {
      return {};
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final doc = await getConversation(conversationId);
    final isGroup = doc['isGroup'] == true;
    final participants = List<String>.from(doc['participants'] ?? []);

    if (isGroup) {
      participants.remove(uid);
      if (participants.isEmpty) {
        await FirebaseService.realtime.ref('conversations/$conversationId').remove().catchError((_) {});
        await _firestore.collection('conversations').doc(conversationId).delete().catchError((_) {});
      } else {
        await FirebaseService.realtime.ref('conversations/$conversationId').update({'participants': participants}).catchError((_) {});
        await _firestore.collection('conversations').doc(conversationId).update({'participants': participants}).catchError((_) {});
      }
    } else {
      final deletedBy = List<String>.from(doc['deletedBy'] ?? []);
      if (!deletedBy.contains(uid)) {
        deletedBy.add(uid);
      }
      await FirebaseService.realtime.ref('conversations/$conversationId').update({'deletedBy': deletedBy}).catchError((_) {});
      await _firestore.collection('conversations').doc(conversationId).update({'deletedBy': deletedBy}).catchError((_) {});
    }
  }

  Future<String?> getGroupInviteLink(String conversationId) async {
    final data = await getConversation(conversationId);
    return data['inviteLink'] as String?;
  }

  Future<String?> getGroupInviteCode(String conversationId) async {
    final data = await getConversation(conversationId);
    return data['inviteCode'] as String?;
  }

  Future<Map<String, dynamic>?> findGroupByInviteCode(String inviteCode) async {
    try {
      final snap = await FirebaseService.realtime.ref('conversations').get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value is Map) {
        final all = Map<String, dynamic>.from(snap.value as Map);
        for (final entry in all.entries) {
          if (entry.value is Map) {
            final group = Map<String, dynamic>.from(entry.value as Map);
            if (group['inviteCode'] == inviteCode && group['isGroup'] == true) {
              return {
                'id': entry.key,
                'name': group['groupName'] ?? 'Group',
                'members': group['participants'] ?? [],
                'autoJoinEnabled': group['autoJoinEnabled'] as bool? ?? false,
              };
            }
          }
        }
      }
    } catch (_) {}

    try {
      final query = await _firestore
          .collection('conversations')
          .where('inviteCode', isEqualTo: inviteCode)
          .where('isGroup', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));
      
      if (query.docs.isNotEmpty) {
        final data = _addIdToData(query.docs.first);
        return {
          'id': data['id'],
          'name': data['groupName'] ?? 'Group',
          'members': data['participants'] ?? [],
          'autoJoinEnabled': data['autoJoinEnabled'] as bool? ?? false,
        };
      }
    } catch (_) {}

    return null;
  }

  Future<String> regenerateGroupInviteCode(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final doc = await getConversation(conversationId);
    final admins = List<String>.from(doc['admins'] ?? []);
    if (!admins.contains(uid)) {
      throw Exception('Only admins can regenerate invite codes');
    }

    final newCode = _generateInviteCode();
    final updates = {
      'inviteCode': newCode,
      'inviteLink': 'nex://group/$newCode',
    };

    await FirebaseService.realtime.ref('conversations/$conversationId').update(updates).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update(updates).catchError((_) {});

    return newCode;
  }

  Future<bool> getAutoJoinSetting(String conversationId) async {
    final data = await getConversation(conversationId);
    return data['autoJoinEnabled'] as bool? ?? false;
  }

  Future<void> setAutoJoinSetting(String conversationId, bool enabled) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final doc = await getConversation(conversationId);
    final admins = List<String>.from(doc['admins'] ?? []);
    if (!admins.contains(uid)) {
      throw Exception('Only admins can change group settings');
    }

    await FirebaseService.realtime.ref('conversations/$conversationId').update({'autoJoinEnabled': enabled}).catchError((_) {});
    await _firestore.collection('conversations').doc(conversationId).update({'autoJoinEnabled': enabled}).catchError((_) {});
  }

  Future<String> requestToJoinGroup(String conversationId, String? displayName) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final reqId = '${conversationId}_$uid';
    final payload = {
      'id': reqId,
      'conversationId': conversationId,
      'userId': uid,
      'userEmail': displayName ?? '',
      'status': 'pending',
      'requestedAt': DateTime.now().toUtc().toIso8601String(),
    };

    await FirebaseService.realtime.ref('join_requests/$reqId').set(payload).catchError((_) {});
    await _firestore.collection('joinRequests').doc(reqId).set(payload).catchError((_) {});

    return uid;
  }

  Future<String?> joinGroupByInviteCode(String inviteCode) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final groupData = await findGroupByInviteCode(inviteCode);
    if (groupData == null) {
      throw Exception('Invalid invite code');
    }

    final conversationId = groupData['id'] as String;
    final autoJoinEnabled = groupData['autoJoinEnabled'] as bool? ?? false;
    final members = List<String>.from(groupData['members'] ?? []);
    
    if (members.contains(uid)) {
      return conversationId;
    }

    if (autoJoinEnabled) {
      await addMember(conversationId, uid);
      return conversationId;
    }

    await requestToJoinGroup(conversationId, '');
    return null;
  }

  Stream<List<Map<String, dynamic>>> getPendingJoinRequests(String conversationId) {
    return FirebaseService.realtime
        .ref('join_requests')
        .orderByChild('conversationId')
        .equalTo(conversationId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <Map<String, dynamic>>[];
      final list = <Map<String, dynamic>>[];
      data.forEach((k, v) {
        if (v is Map) {
          final item = Map<String, dynamic>.from(v);
          item['id'] = k.toString();
          if (item['status'] == 'pending') {
            list.add(item);
          }
        }
      });
      return list;
    });
  }

  Future<void> approveJoinRequest(String conversationId, String userId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final reqId = '${conversationId}_$userId';
    final updates = {
      'status': 'approved',
      'approvedAt': DateTime.now().toUtc().toIso8601String(),
      'approvedBy': uid,
    };

    await FirebaseService.realtime.ref('join_requests/$reqId').update(updates).catchError((_) {});
    await _firestore.collection('joinRequests').doc(reqId).update(updates).catchError((_) {});
    await addMember(conversationId, userId);
  }

  Future<void> rejectJoinRequest(String conversationId, String userId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');

    final reqId = '${conversationId}_$userId';
    final updates = {
      'status': 'rejected',
      'rejectedAt': DateTime.now().toUtc().toIso8601String(),
      'rejectedBy': uid,
    };

    await FirebaseService.realtime.ref('join_requests/$reqId').update(updates).catchError((_) {});
    await _firestore.collection('joinRequests').doc(reqId).update(updates).catchError((_) {});
  }

  Future<bool> hasPendingJoinRequest(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final reqId = '${conversationId}_$uid';
    try {
      final snap = await FirebaseService.realtime.ref('join_requests/$reqId').get().timeout(const Duration(seconds: 2));
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        return data['status'] == 'pending';
      }
    } catch (_) {}
    return false;
  }

  Future<void> addMessageReaction(String messageId, String reaction) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');
    
    final reactionId = '${messageId}_$uid';
    final payload = {
      'id': reactionId,
      'messageId': messageId,
      'userId': uid,
      'reaction': reaction,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    await FirebaseService.realtime.ref('message_reactions/$reactionId').set(payload).catchError((_) {});
    await _firestore.collection('messageReactions').doc(reactionId).set(payload).catchError((_) {});
  }

  Future<void> removeMessageReaction(String messageId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No current user');
    final reactionId = '${messageId}_$uid';
    await FirebaseService.realtime.ref('message_reactions/$reactionId').remove().catchError((_) {});
    await _firestore.collection('messageReactions').doc(reactionId).delete().catchError((_) {});
  }

  Stream<List<Map<String, dynamic>>> getMessageReactions(String messageId) {
    return FirebaseService.realtime
        .ref('message_reactions')
        .orderByChild('messageId')
        .equalTo(messageId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <Map<String, dynamic>>[];
      final list = <Map<String, dynamic>>[];
      data.forEach((k, v) {
        if (v is Map) {
          final item = Map<String, dynamic>.from(v);
          item['id'] = k.toString();
          list.add(item);
        }
      });
      return list;
    });
  }

  Future<void> markMessageAsRead(String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'readBy': FieldValue.arrayUnion([uid])
      });
    } catch (_) {}
  }
}
