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
    String? authorName,
    String? authorPic,
    String? publishingIdentity,
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid ?? currentUserId ?? 'anonymous';

    String resolvedAuthorName = authorName?.trim() ?? '';
    String resolvedAuthorPic = authorPic?.trim() ?? '';
    String resolvedIdentity = publishingIdentity ?? 'general';

    // Query creator identity from Firestore if not provided explicitly
    if (resolvedAuthorName.isEmpty || resolvedAuthorPic.isEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final udata = doc.data() ?? {};
          final bool useCustom = udata['useCustomReelsAvatar'] == true;
          final String customAvatar = udata['reelsAvatar']?.toString().trim() ?? '';
          final String creatorName = udata['reelsCreatorName']?.toString().trim() ?? '';

          if (resolvedAuthorName.isEmpty) {
            if (useCustom && creatorName.isNotEmpty) {
              resolvedAuthorName = creatorName;
              resolvedIdentity = 'custom';
            } else {
              resolvedAuthorName = udata['username']?.toString().trim() ??
                  udata['name']?.toString().trim() ??
                  '';
            }
          }

          if (resolvedAuthorPic.isEmpty) {
            if (useCustom && customAvatar.isNotEmpty) {
              resolvedAuthorPic = customAvatar;
            } else {
              resolvedAuthorPic = udata['photo_url']?.toString().trim() ??
                  udata['profilePicUrl']?.toString().trim() ??
                  udata['profilePic']?.toString().trim() ??
                  '';
            }
          }
        }
      } catch (e) {
        debugPrint('[ReelService] Notice fetching user creator identity: $e');
      }
    }

    // Comprehensive fallbacks
    if (resolvedAuthorName.isEmpty || resolvedAuthorName == '@') {
      final authDisplayName = user?.displayName?.trim();
      final emailPrefix = user?.email?.split('@').first.trim();
      if (authDisplayName != null && authDisplayName.isNotEmpty && authDisplayName != '@') {
        resolvedAuthorName = authDisplayName;
      } else if (emailPrefix != null && emailPrefix.isNotEmpty) {
        resolvedAuthorName = emailPrefix;
      } else {
        resolvedAuthorName = 'Operative';
      }
    }

    if (resolvedAuthorPic.isEmpty) {
      resolvedAuthorPic = user?.photoURL?.trim() ?? '';
    }

    final now = DateTime.now().toUtc();
    final soundTitle = soundTrackTitle ?? 'Original Audio — @$resolvedAuthorName';

    final data = <String, dynamic>{
      'user_id': uid,
      'authorId': uid,
      'authorName': resolvedAuthorName,
      'username': resolvedAuthorName,
      'authorPic': resolvedAuthorPic,
      'publishingIdentity': resolvedIdentity,
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
    debugPrint('[ReelService] Reel record created: ${docRef.id} by @$resolvedAuthorName');
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

        // Resolve robust username
        final rawAuthor = data['authorName']?.toString().trim();
        final rawUser = data['username']?.toString().trim();
        String resolvedName = 'Operative';
        if (rawAuthor != null && rawAuthor.isNotEmpty && rawAuthor != '@') {
          resolvedName = rawAuthor;
        } else if (rawUser != null && rawUser.isNotEmpty && rawUser != '@') {
          resolvedName = rawUser;
        }

        data['username'] = resolvedName;
        data['authorName'] = resolvedName;
        data['authorPic'] = data['authorPic']?.toString().trim() ?? data['author_pic']?.toString().trim() ?? '';
        data['avatar'] = resolvedName.isNotEmpty ? resolvedName[0].toUpperCase() : 'O';
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

  /// Get Creator Profile from Firestore (with NEXCHAT compatibility)
  Future<Map<String, dynamic>> getCreatorProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return Map<String, dynamic>.from(doc.data()!);
      }
    } catch (e) {
      debugPrint('[ReelService] Error loading creator profile for $uid: $e');
    }
    return {};
  }

  /// Save Creator Profile & Avatar Settings (1:1 with NEXCHAT schema)
  Future<void> saveCreatorProfile({
    required String uid,
    required bool useCustomReelsAvatar,
    required String reelsAvatar,
    required String reelsCreatorName,
    required String reelsCreatorBio,
  }) async {
    final payload = <String, dynamic>{
      'useCustomReelsAvatar': useCustomReelsAvatar,
      'reelsAvatar': reelsAvatar,
      'reelsCreatorName': reelsCreatorName,
      'reelsCreatorBio': reelsCreatorBio,
    };
    await _firestore.collection('users').doc(uid).set(payload, SetOptions(merge: true));
    debugPrint('[ReelService] Saved creator profile for $uid');
  }

  /// Uploads custom reels avatar via Cloudinary Multi-Vault
  Future<String> uploadCustomReelsAvatar(File file) async {
    return await CloudinaryStorageService.instance.uploadImage(
      file: file,
      folder: 'nexchat-reels-avatars',
    );
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
        'userId': authorId,
        'user_id': authorId,
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
