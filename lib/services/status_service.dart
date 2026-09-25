import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'cloudinary_storage_service.dart';
import 'firebase_service.dart';
import 'storage_api_service.dart';
import 'upload_progress_service.dart';
import 'vercel_blob_service.dart';

class StatusService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtime = FirebaseService.realtime;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Fast status publisher with Firestore primary and RTDB dual-sync
  Future<String> postStatus({
    required String text,
    String? mediaUrl,
    String mediaType = 'text',
    Duration expiresIn = const Duration(hours: 24),
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final now = DateTime.now().toUtc();
    final nowMs = now.millisecondsSinceEpoch;
    final expiresAt = now.add(expiresIn);
    final expiresAtMs = expiresAt.millisecondsSinceEpoch;

    final username = user.displayName ?? user.email?.split('@').first ?? 'NEX User';
    final profilePic = user.photoURL ?? '';

    final firestorePayload = {
      'userId': user.uid,
      'username': username,
      'profilePic': profilePic,
      'content': text,
      'text': text,
      'type': mediaType,
      'mediaType': mediaType,
      'imageUrl': mediaUrl ?? '',
      'mediaUrl': mediaUrl ?? '',
      'expiresAt': Timestamp.fromDate(expiresAt),
      'expiresAtIso': expiresAt.toIso8601String(),
      'expiresAtMs': expiresAtMs,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': nowMs,
      'timestamp': FieldValue.serverTimestamp(),
      'views': 0,
      'isActive': true,
    };

    // 1. Write to Firestore 'statuses' collection (identical to NEXCHAT)
    final firestoreRef = await _firestore.collection('statuses').add(firestorePayload);

    // 2. Dual-sync to Realtime Database
    try {
      final rtdbPayload = {
        'id': firestoreRef.id,
        'userId': user.uid,
        'username': username,
        'profilePic': profilePic,
        'text': text,
        'content': text,
        'mediaUrl': mediaUrl ?? '',
        'imageUrl': mediaUrl ?? '',
        'mediaType': mediaType,
        'expiresAt': expiresAt.toIso8601String(),
        'expiresAtMs': expiresAtMs,
        'createdAt': now.toIso8601String(),
        'views': 0,
        'isActive': true,
      };
      await _realtime.ref('statuses/${firestoreRef.id}').set(
        FirebaseService.sanitizeRealtimeData(rtdbPayload),
      );
    } catch (e) {
      debugPrint('[StatusService] RTDB sync notice: $e');
    }

    return firestoreRef.id;
  }

  /// High-speed multi-tier status media uploader:
  /// 1. Multi-Vault Cloudinary Pool (folder: nexchat-status)
  /// 2. Vercel Blob Status Vaults 1-5 (namespace: nexapp/status/)
  /// 3. Firebase Storage fallback
  Future<String> uploadStatusMedia(String filePath, String mediaType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Selected status media file does not exist');
    }

    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final uploadId = 'status_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();

    uploadService.startUpload(
      id: uploadId,
      fileName: 'Status: $fileName',
      totalBytes: fileSize,
    );

    // Tier 0: Standalone Storage API Gateway (Cloudinary 34-Vault via HTTPS)
    if (fileSize <= 6 * 1024 * 1024) {
      try {
        debugPrint('[StatusService] Attempting Storage API Gateway upload for status: $fileName');
        final bytes = await file.readAsBytes();
        final gatewayUrl = await StorageApiService.instance.uploadMedia(
          bytes: bytes,
          fileName: fileName,
          category: 'status',
          fileType: mediaType == 'video' ? 'video' : 'image',
          userId: user.uid,
        );
        if (gatewayUrl != null && gatewayUrl.isNotEmpty) {
          uploadService.completeUpload(id: uploadId);
          debugPrint('[StatusService] Storage API Gateway upload success: $gatewayUrl');
          return gatewayUrl;
        }
      } catch (e) {
        debugPrint('[StatusService] Storage API Gateway notice: $e');
      }
    }

    // Tier 1: Cloudinary Multi-Vault Storage Pool
    try {
      debugPrint('[StatusService] Attempting direct Cloudinary upload for status: $fileName');
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize ~/ 3,
        totalBytes: fileSize,
      );

      String cdnUrl;
      if (mediaType == 'video') {
        cdnUrl = await CloudinaryStorageService.instance.uploadVideo(
          file: file,
          folder: 'nexchat-status',
          onProgress: (p) {
            uploadService.updateProgress(
              id: uploadId,
              bytesUploaded: (fileSize * p).round(),
              totalBytes: fileSize,
            );
          },
        );
      } else {
        cdnUrl = await CloudinaryStorageService.instance.uploadImage(
          file: file,
          folder: 'nexchat-status',
        );
      }

      if (cdnUrl.isNotEmpty) {
        uploadService.completeUpload(id: uploadId);
        debugPrint('[StatusService] Cloudinary status upload success: $cdnUrl');
        return cdnUrl;
      }
    } catch (e) {
      debugPrint('[StatusService] Cloudinary tier notice, trying Vercel Blob: $e');
    }

    // Tier 2: Vercel Blob Ephemeral Status Vaults (Vaults 1-5)
    try {
      debugPrint('[StatusService] Attempting Vercel Blob status vault upload...');
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize ~/ 2,
        totalBytes: fileSize,
      );

      final blobUrl = await VercelBlobService.instance.uploadStatusMedia(
        file: file,
        uid: user.uid,
        mediaType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
      );

      if (blobUrl != null && blobUrl.isNotEmpty) {
        uploadService.completeUpload(id: uploadId);
        debugPrint('[StatusService] Vercel Blob status upload success: $blobUrl');
        return blobUrl;
      }
    } catch (e) {
      debugPrint('[StatusService] Vercel Blob tier notice, trying Storage: $e');
    }

    // Tier 3: Firebase Storage Fallback
    try {
      final folder = mediaType == 'video' ? 'status_videos' : 'status_images';
      final path = '$folder/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize * 3 ~/ 4,
        totalBytes: fileSize,
      );

      await _storage.ref(path).putFile(file);
      uploadService.completeUpload(id: uploadId);
      final publicUrl = await _storage.ref(path).getDownloadURL();
      debugPrint('[StatusService] Firebase Storage status upload success: $publicUrl');
      return publicUrl;
    } catch (e) {
      uploadService.failUpload(id: uploadId, error: 'Status upload failed: $e');
      rethrow;
    }
  }

  /// Real-time stream of non-expired statuses from Firestore unified with RTDB
  Stream<List<Map<String, dynamic>>> getStatuses() {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _firestore
        .collection('statuses')
        .snapshots()
        .map((snapshot) {
      final list = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;

        final isActive = data['isActive'] != false;
        if (!isActive) continue;

        // Check expiration (24h)
        final expiresAtMs = (data['expiresAtMs'] as num?)?.toInt();
        if (expiresAtMs != null && expiresAtMs < nowMs) {
          continue; // Expired
        }

        // Normalize mediaUrl / imageUrl
        final media = data['mediaUrl']?.toString() ?? data['imageUrl']?.toString() ?? '';
        data['mediaUrl'] = media;
        data['imageUrl'] = media;
        data['text'] = data['text']?.toString() ?? data['content']?.toString() ?? '';
        data['content'] = data['text'];
        data['username'] = data['username']?.toString() ?? 'NEX User';
        data['profilePic'] = data['profilePic']?.toString() ?? '';

        list.add(data);
      }

      // Sort newest first
      list.sort((a, b) {
        final aTime = (a['createdAtMs'] as num?)?.toInt() ?? 0;
        final bTime = (b['createdAtMs'] as num?)?.toInt() ?? 0;
        return bTime.compareTo(aTime);
      });

      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getUserStatuses() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return getStatuses().map((statuses) {
      return statuses.where((s) => s['userId'] == user.uid).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getMyStatuses() {
    return getUserStatuses();
  }

  Future<void> viewStatus(String statusId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('statuses').doc(statusId).update({
        'views': FieldValue.increment(1),
      });
      await _realtime.ref('statusViews/$statusId/${user.uid}').set({
        'userId': user.uid,
        'viewedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[StatusService] View count notice: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getStatusViewers(String statusId) {
    try {
      return _realtime.ref('statusViews/$statusId').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          return val.values.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
        return <Map<String, dynamic>>[];
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<void> deleteStatus(String statusId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('statuses').doc(statusId).update({
        'isActive': false,
      });
      await _realtime.ref('statuses/$statusId').update({'isActive': false});
    } catch (e) {
      debugPrint('[StatusService] Delete status error: $e');
      rethrow;
    }
  }

  Future<void> reactToStatus(String statusId, String reaction) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _realtime.ref('statusReactions/$statusId/${user.uid}').set({
        'userId': user.uid,
        'reaction': reaction,
        'reactedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[StatusService] React error: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getStatusReactions(String statusId) {
    try {
      return _realtime.ref('statusReactions/$statusId').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          return val.values.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
        return <Map<String, dynamic>>[];
      });
    } catch (_) {
      return const Stream.empty();
    }
  }
}
