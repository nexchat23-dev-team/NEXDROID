import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'cloudinary_storage_service.dart';
import 'vercel_blob_service.dart';

/// Storage API Gateway Client for NEX-APP
/// Communicates with the standalone Vercel Storage API microservice.
/// Fully shields the mobile APK from holding raw storage master tokens.
class StorageApiService {
  StorageApiService._();
  static final StorageApiService instance = StorageApiService._();

  // Production Vercel Storage API endpoint (or custom domain)
  // Fallbacks to direct client SDK if standalone API is not yet deployed
  static const String _defaultBaseUrl = 'https://nex-storage-api.vercel.app';
  String _baseUrl = _defaultBaseUrl;

  void setBaseUrl(String url) {
    if (url.trim().isNotEmpty) {
      _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    }
  }

  String get baseUrl => _baseUrl;

  /// API 1: Upload Media (Status Post, Reel, Video, Voice note)
  /// Primary route: Cloudinary Multi-Vault (1-25) via Vercel Storage API.
  Future<String?> uploadMedia({
    required Uint8List bytes,
    required String fileName,
    String category = 'status', // 'status' | 'reel' | 'chat_media'
    String fileType = 'image', // 'image' | 'video' | 'audio'
    String userId = 'anonymous',
  }) async {
    final base64Data = base64Encode(bytes);

    // 1. Attempt upload via standalone Vercel Storage API
    try {
      final uri = Uri.parse('$_baseUrl/api/storage/media');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'file': 'data:$fileType/jpeg;base64,$base64Data',
              'fileName': fileName,
              'fileType': fileType,
              'category': category,
              'userId': userId,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          if (kDebugMode) {
            debugPrint('[StorageApiService] Media uploaded via API Gateway (Vault #${data['vaultId']})');
          }
          return data['url'] as String;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageApiService] Gateway upload note: $e. Using local vault fallback.');
      }
    }

    // 2. Resilient Fallback to embedded Cloudinary service
    try {
      final uploadRes = await CloudinaryStorageService.instance.uploadMedia(
        bytes: bytes,
        fileName: fileName,
        folder: category == 'status' ? 'nex-status-posts' : 'nex-media',
        resourceType: fileType,
      );
      return uploadRes.secureUrl;
    } catch (fallbackErr) {
      if (kDebugMode) debugPrint('[StorageApiService] Fallback failed: $fallbackErr');
      return null;
    }
  }

  /// API 2: Upload Profile Picture / Avatar & General Photos
  /// Primary route: Vercel Blob via Vercel Storage API.
  Future<String?> uploadProfilePicture({
    required Uint8List bytes,
    required String userId,
    String fileName = 'avatar.jpg',
    String type = 'avatar',
  }) async {
    final base64Data = base64Encode(bytes);

    // 1. Attempt upload via standalone Vercel Storage API
    try {
      final uri = Uri.parse('$_baseUrl/api/storage/profile');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'file': 'data:image/jpeg;base64,$base64Data',
              'fileName': fileName,
              'userId': userId,
              'type': type,
              'mimeType': 'image/jpeg',
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          if (kDebugMode) {
            debugPrint('[StorageApiService] Profile uploaded via API Gateway: ${data['url']}');
          }
          return data['url'] as String;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageApiService] Profile Gateway note: $e. Using local blob fallback.');
      }
    }

    // 2. Resilient Fallback to embedded VercelBlobService
    try {
      final fallbackUrl = await VercelBlobService.instance.uploadAvatarBytes(
        bytes,
        userId,
        fileName: fileName,
      );
      return fallbackUrl;
    } catch (fallbackErr) {
      if (kDebugMode) debugPrint('[StorageApiService] Profile fallback error: $fallbackErr');
      return null;
    }
  }

  /// Health Check
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/storage/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
