import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'cloudinary_storage_service.dart';
import 'storage_api_service.dart';
import 'upload_progress_service.dart';

class ReelService {
  static final ReelService _instance = ReelService._internal();
  static ReelService get instance => _instance;
  factory ReelService() => _instance;
  ReelService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Uploads video clip to Cloudinary 15-Vault Pool with failover and fallback to Storage
  Future<String> uploadReelVideo(
    String filePath, {
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Selected reel file does not exist.');
    }
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final uploadId = 'reel_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();

    uploadService.startUpload(
      id: uploadId,
      fileName: 'Reel: $fileName',
      totalBytes: fileSize,
    );
    onProgress?.call(0, fileSize);

    // Tier 0: Standalone Storage API Gateway (Cloudinary 34-Vault via HTTPS)
    if (fileSize <= 6 * 1024 * 1024) {
      try {
        debugPrint('[ReelService] Attempting Storage API Gateway upload for reel: $fileName');
        final bytes = await file.readAsBytes();
        final gatewayUrl = await StorageApiService.instance.uploadMedia(
          bytes: bytes,
          fileName: fileName,
          category: 'reel',
          fileType: 'video',
          userId: currentUserId ?? 'anonymous',
        );
        if (gatewayUrl != null && gatewayUrl.isNotEmpty) {
          uploadService.completeUpload(id: uploadId);
          onProgress?.call(fileSize, fileSize);
          debugPrint('[ReelService] Storage API Gateway upload successful: $gatewayUrl');
          return gatewayUrl;
        }
      } catch (e) {
        debugPrint('[ReelService] Storage API Gateway notice: $e');
      }
    }

    // 1. Try direct Multi-Vault Cloudinary Pipeline
    try {
      debugPrint('[ReelService] Initiating Cloudinary Multi-Vault upload for $fileName...');
      final cdnUrl = await CloudinaryStorageService.instance.uploadVideo(
        file: file,
        folder: 'nexchat-reels',
        onProgress: (progress) {
          final bytesUploaded = (fileSize * progress).round();
          uploadService.updateProgress(
            id: uploadId,
            bytesUploaded: bytesUploaded,
            totalBytes: fileSize,
          );
          onProgress?.call(bytesUploaded, fileSize);
        },
      );

      uploadService.completeUpload(id: uploadId);
      onProgress?.call(fileSize, fileSize);
      debugPrint('[ReelService] Cloudinary upload successful: $cdnUrl');
      return cdnUrl;
    } catch (e) {
      debugPrint('[ReelService] Cloudinary upload failed, trying Firebase Storage fallback: $e');
    }

    // 2. Secondary fallback: Firebase Storage
    try {
      final path = 'reels/${currentUserId ?? 'unknown'}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: fileSize ~/ 3,
        totalBytes: fileSize,
      );
      await _storage.ref(path).putFile(file);
      uploadService.completeUpload(id: uploadId);
      onProgress?.call(fileSize, fileSize);
      final publicUrl = await _storage.ref(path).getDownloadURL();
      return publicUrl;
    } catch (e) {
      uploadService.failUpload(id: uploadId, error: 'Reel upload failed: $e');
      rethrow;
    }
  }

  /// Creates a unified reel record in Firestore compatible with both NEXCHAT and NEX-APP
  Future<String> createReelRecord({
    required String title,
    required String description,
    required String hashtags,
    required String mediaUrl,
    required String duration,
    required String style,
    required String fileName,
    String? thumbnailUrl,
    String? soundTrackTitle,
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid ?? currentUserId ?? 'anonymous';
    final authorName = user?.displayName ?? user?.email?.split('@').first ?? 'NEX Creator';
    final authorPic = user?.photoURL ?? '';

    final now = DateTime.now().toUtc();
    final soundTitle = soundTrackTitle ?? 'Original Audio — @$authorName';

    final data = <String, dynamic>{
      'user_id': uid,
      'authorId': uid,
      'authorName': authorName,
      'authorPic': authorPic,
      'title': title,
      'caption': title.isNotEmpty && description.isNotEmpty ? '$title\n$description' : (title.isNotEmpty ? title : description),
      'description': description,
      'hashtags': hashtags,
      'media_url': mediaUrl,
      'videoUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl ?? '',
      'soundTrackTitle': soundTitle,
      'soundTrack': soundTitle,
      'duration': duration,
      'visual_style': style,
      'file_name': fileName,
      'likes': <String>[],
      'likesCount': 0,
      'commentsCount': 0,
      'sharesCount': 0,
      'bookmarksCount': 0,
      'is_public': true,
      'created_at': now.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('reels').add(data);
    debugPrint('[ReelService] Reel record created: ${docRef.id}');
    return docRef.id;
  }

  /// Stream of all reels from Firestore in real-time
  Stream<List<Map<String, dynamic>>> getReelsStream() {
    return _firestore
        .collection('reels')
        .snapshots()
        .map((snapshot) {
      final reels = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        // Normalize fields for UI
        final media = data['videoUrl']?.toString() ?? data['media_url']?.toString() ?? '';
        if (media.isEmpty) continue; // Skip reels without media

        data['videoUrl'] = media;
        data['media_url'] = media;
        data['username'] = data['authorName']?.toString() ?? data['username']?.toString() ?? 'nex_creator';
        data['avatar'] = (data['username'] as String).isNotEmpty ? (data['username'] as String)[0].toUpperCase() : 'N';
        data['title'] = data['title']?.toString() ?? data['caption']?.toString() ?? 'NEX Reel';
        data['description'] = data['description']?.toString() ?? data['caption']?.toString() ?? '';
        data['hashtags'] = data['hashtags']?.toString() ?? '#NEXReels';
        data['soundTrack'] = data['soundTrackTitle']?.toString() ?? data['soundTrack']?.toString() ?? 'Original Audio';
        data['likes'] = (data['likesCount'] as num?)?.toInt() ?? ((data['likes'] is List) ? (data['likes'] as List).length : 0);
        data['comments'] = (data['commentsCount'] as num?)?.toInt() ?? 0;
        data['shares'] = (data['sharesCount'] as num?)?.toInt() ?? 0;
        data['saves'] = (data['bookmarksCount'] as num?)?.toInt() ?? 0;
        data['duration'] = data['duration']?.toString() ?? '0:30';

        final currentUid = currentUserId;
        final rawLikes = data['likes'];
        if (currentUid != null && rawLikes is List) {
          data['liked'] = rawLikes.contains(currentUid);
        } else {
          data['liked'] = false;
        }

        reels.add(data);
      }
      return reels;
    });
  }

  /// Toggle like on a reel
  Future<void> toggleLikeReel(String reelId, String userId, bool currentlyLiked) async {
    try {
      final docRef = _firestore.collection('reels').doc(reelId);
      if (currentlyLiked) {
        await docRef.set({
          'likes': FieldValue.arrayRemove([userId]),
          'likesCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'likes': FieldValue.arrayUnion([userId]),
          'likesCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[ReelService] Error toggling like: $e');
    }
  }

  /// Add comment to reel
  Future<void> addComment(
    String reelId,
    String text, {
    required String authorId,
    required String authorName,
    String? authorPic,
  }) async {
    try {
      final commentDoc = {
        'authorId': authorId,
        'authorName': authorName,
        'authorPic': authorPic ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .add(commentDoc);

      await _firestore.collection('reels').doc(reelId).set({
        'commentsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ReelService] Error posting comment: $e');
    }
  }

  /// Real-time stream of comments for a specific reel
  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsStream(String reelId) {
    return _firestore
        .collection('reels')
        .doc(reelId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}
