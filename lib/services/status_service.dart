import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_service.dart';
import 'upload_progress_service.dart';

class StatusService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _realtime = FirebaseService.realtime;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> postStatus({required String text, String? mediaUrl, String mediaType = 'text', Duration expiresIn = const Duration(hours: 24)}) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    final expiresAt = DateTime.now().add(expiresIn).toUtc().toIso8601String();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'userId': currentUserId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'expiresAt': expiresAt,
      'createdAt': createdAt,
      'views': 0,
      'isActive': true,
    };

    // 1. Write to Firestore primary
    final firestoreRef = await FirebaseService.firestore.collection('statuses').add({
      ...payload,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. Try RTDB optional
    try {
      final statusRef = _realtime.ref('statuses').child(firestoreRef.id);
      await statusRef.set(FirebaseService.sanitizeRealtimeData(payload));
    } catch (e) {
      debugPrint('[StatusService] RTDB write notice: $e');
    }

    return firestoreRef.id;
  }

  Future<String> uploadStatusMedia(String filePath, String mediaType) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final file = File(filePath);
      final fileName = file.uri.pathSegments.last;
      final fileSize = await file.length();
      final uploadId = 'status_${DateTime.now().millisecondsSinceEpoch}';
      final uploadService = UploadProgressService();
      final folder = mediaType == 'video'
          ? 'status_videos'
          : mediaType == 'audio'
              ? 'status_audio'
              : 'status_images';
      final path = '$folder/$currentUserId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      uploadService.startUpload(id: uploadId, fileName: 'Status: $fileName', totalBytes: fileSize,);
      uploadService.updateProgress(id: uploadId, bytesUploaded: fileSize ~/ 2, totalBytes: fileSize,);
      await _storage.ref(path).putFile(file);
      uploadService.updateProgress(id: uploadId, bytesUploaded: fileSize * 3 ~/ 4, totalBytes: fileSize,);
      uploadService.updateProgress(id: uploadId, bytesUploaded: fileSize, totalBytes: fileSize,);
      uploadService.completeUpload(id: uploadId);
      final publicUrl = await _storage.ref(path).getDownloadURL();
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading status media: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _mapSnapshotToList(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value == null) return [];
    if (value is Map) {
      return value.entries.where((entry) => entry.value != null).map((entry) {
        final data = Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>);
        data['id'] = entry.key;
        return data;
      }).toList();
    }
    return [];
  }

  Stream<List<Map<String, dynamic>>> getStatuses() {
    try {
      final now = DateTime.now().toUtc();
      return _realtime.ref('statuses').orderByChild('isActive').equalTo(true).onValue.map((event) {
        final statuses = _mapSnapshotToList(event)
            .where((status) {
              final expiresAt = DateTime.tryParse(status['expiresAt']?.toString() ?? '');
              return expiresAt == null || expiresAt.isAfter(now);
            })
            .toList();
        statuses.sort((a, b) {
          final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return statuses;
      }).handleError((e) {debugPrint('Error getting statuses: $e'); return <Map<String, dynamic>>[];});
    } catch (e) {
      debugPrint('Error setting up statuses stream: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getUserStatuses() {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      return _realtime.ref('statuses').orderByChild('userId').equalTo(currentUserId).onValue.map((event) {
        final statuses = _mapSnapshotToList(event)
            .where((status) => status['isActive'] == true)
            .toList();
        statuses.sort((a, b) {
          final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return statuses;
      }).handleError((e) {debugPrint('Error getting user statuses: $e'); return <Map<String, dynamic>>[];});
    } catch (e) {
      debugPrint('Error setting up user statuses stream: $e');
      rethrow;
    }
  }

  Future<void> viewStatus(String statusId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final statusRef = _realtime.ref('statuses/$statusId');
      final snapshot = await statusRef.get();
      final currentViews = snapshot.value is Map ? (snapshot.value as Map)['views'] as int? ?? 0 : 0;
      await statusRef.update({'views': currentViews + 1});
      await _realtime.ref('statusViews').push().set(
        FirebaseService.sanitizeRealtimeData({
          'statusId': statusId,
          'userId': currentUserId,
          'viewedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error viewing status: $e');
      rethrow;
    }
  }

  Future<void> deleteStatus(String statusId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final statusRef = _realtime.ref('statuses/$statusId');
      final statusSnapshot = await statusRef.get();
      final userId = statusSnapshot.value is Map ? (statusSnapshot.value as Map)['userId']?.toString() : null;
      if (userId != currentUserId) throw Exception('Not authorized');
      await statusRef.update({'isActive': false});
    } catch (e) {
      debugPrint('Error deleting status: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getStatusViewers(String statusId) {
    try {
      return _realtime.ref('statusViews').orderByChild('statusId').equalTo(statusId).onValue.map((event) {
        final viewers = _mapSnapshotToList(event);
        viewers.sort((a, b) {
          final aTime = DateTime.tryParse(a['viewedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['viewedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return viewers;
      }).handleError((e) {debugPrint('Error getting status viewers: $e'); return <Map<String, dynamic>>[];});
    } catch (e) {
      debugPrint('Error setting up status viewers stream: $e');
      rethrow;
    }
  }

  Future<void> reactToStatus(String statusId, String reaction) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      await _realtime.ref('statusReactions').push().set(
        FirebaseService.sanitizeRealtimeData({
          'statusId': statusId,
          'userId': currentUserId,
          'reaction': reaction,
          'reactedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error reacting to status: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getMyStatuses() {
    return getUserStatuses();
  }

  Future<void> updateStatus(String statusId, {String? text, String? mediaUrl, String? mediaType,}) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final statusRef = _realtime.ref('statuses/$statusId');
      final snapshot = await statusRef.get();
      final userId = snapshot.value is Map ? (snapshot.value as Map)['userId']?.toString() : null;
      if (userId != currentUserId) throw Exception('Not authorized');
      final updates = <String, dynamic>{};
      if (text != null) updates['text'] = text;
      if (mediaUrl != null) updates['mediaUrl'] = mediaUrl;
      if (mediaType != null) updates['mediaType'] = mediaType;
      updates['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await statusRef.update(updates);
    } catch (e) {
      debugPrint('Error updating status: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getStatusReactions(String statusId) {
    try {
      return _realtime.ref('statusReactions').orderByChild('statusId').equalTo(statusId).onValue.map((event) {
        final reactions = _mapSnapshotToList(event);
        reactions.sort((a, b) {
          final aTime = DateTime.tryParse(a['reactedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['reactedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return reactions;
      }).handleError((e) {debugPrint('Error getting status reactions: $e'); return <Map<String, dynamic>>[];});
    } catch (e) {
      debugPrint('Error setting up status reactions stream: $e');
      return const Stream.empty();
    }
  }
}
