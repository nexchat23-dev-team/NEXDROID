import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'upload_progress_service.dart';

class ReelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> uploadReelVideo(String filePath, {void Function(int uploadedBytes, int totalBytes)? onProgress,}) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Selected reel file does not exist.');
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final uploadId = 'reel_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();
    final path = 'reels/${currentUserId ?? 'unknown'}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    uploadService.startUpload(id: uploadId, fileName: 'Reel: $fileName', totalBytes: fileSize,);
    onProgress?.call(0, fileSize);
    await _storage.ref(path).putFile(file);
    uploadService.updateProgress(id: uploadId, bytesUploaded: fileSize * 3 ~/ 4, totalBytes: fileSize,);
    await Future.delayed(const Duration(milliseconds: 200));
    uploadService.updateProgress(id: uploadId, bytesUploaded: fileSize, totalBytes: fileSize,);
    uploadService.completeUpload(id: uploadId);
    onProgress?.call(fileSize, fileSize);
    final publicUrl = await _storage.ref(path).getDownloadURL();
    return publicUrl;
  }

  Future<String> createReelRecord({required String title, required String description, required String hashtags, required String mediaUrl, required String duration, required String style, required String fileName,}) async {
    if (currentUserId == null) throw Exception('No current user is signed in.');
    final docRef = await _firestore.collection('reels').add({'user_id': currentUserId, 'title': title, 'description': description, 'hashtags': hashtags, 'media_url': mediaUrl, 'duration': duration, 'visual_style': style, 'file_name': fileName, 'created_at': DateTime.now().toUtc().toIso8601String(), 'is_public': true,});
    return docRef.id;
  }
}
