import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VercelBlobService {
  static final VercelBlobService _instance = VercelBlobService._internal();
  static VercelBlobService get instance => _instance;
  factory VercelBlobService() => _instance;
  VercelBlobService._internal();

  // Isolated tokens configured from NEXCHAT environment
  static const String profileToken = 'vercel_blob_rw_1Z4MEej7ip5Jg9Wz_ggfb5Dc875zyDAesscTkLSCJHTAd3x';
  static const String mediaToken = 'vercel_blob_rw_R4RmXAAr4Lb0ofNq_2XNk166CeMNYPUChKxuBlukPMkj0XO';

  // Ephemeral Status Vaults 1 through 5
  static const List<Map<String, String>> statusVaults = [
    {'index': '1', 'name': 'NEX-STATUS VAULT 1', 'token': 'vercel_blob_rw_jCNrgY96DrgBtoUm_INH2vNcllZzjIqVnvsdaRoz5tqs4eW'},
    {'index': '2', 'name': 'NEX-STATUS VAULT 2', 'token': 'vercel_blob_rw_7IvHQcdI5lb3oN8t_KaHnvD4QZ7X5HN6pnyD2ZbaBHhc3Ge'},
    {'index': '3', 'name': 'NEX-STATUS VAULT 3', 'token': 'vercel_blob_rw_J0e8RZ3glwBgsqKQ_nDWdloFydWRjlWLMWTu4K0TkZrchVc'},
    {'index': '4', 'name': 'NEX-STATUS VAULT 4', 'token': 'vercel_blob_rw_aiBRkSDHg0K7Hq8g_CIwlPJETUqINLvIOUluiH9oKpAAJLp'},
    {'index': '5', 'name': 'NEX-STATUS VAULT 5', 'token': 'vercel_blob_rw_b9u0Ll5xZBhFcaAD_CCX5iYxp0wLqESQ3JxfLDCSVpV5bwT'},
  ];

  /// Uploads ephemeral status media with auto-failover across Status Vaults 1 to 5.
  /// Uses 'nexapp/status/' path namespace to protect NEXCHAT data.
  Future<String?> uploadStatusMedia({
    required File file,
    required String uid,
    String? mediaType,
  }) async {
    final cleanName = file.uri.pathSegments.last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final pathname = 'nexapp/status/$uid/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final bytes = await file.readAsBytes();
    final contentType = mediaType ?? _guessContentType(cleanName);

    for (final vault in statusVaults) {
      try {
        final token = vault['token']!;
        debugPrint('[VercelBlob] Uploading status to ${vault['name']}...');
        final url = await _putToBlob(
          pathname: pathname,
          bytes: bytes,
          token: token,
          contentType: contentType,
        );
        if (url != null && url.isNotEmpty) {
          debugPrint('[VercelBlob] Status upload success in ${vault['name']}: $url');
          return url;
        }
      } catch (e) {
        debugPrint('[VercelBlob] Vault ${vault['name']} notice: $e');
      }
    }
    return null;
  }

  /// Uploads user avatar to Vercel Blob profile partition with isolated path.
  Future<String?> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    final cleanName = file.uri.pathSegments.last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final pathname = 'nexapp/avatars/$uid/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final bytes = await file.readAsBytes();
    final contentType = _guessContentType(cleanName);

    try {
      debugPrint('[VercelBlob] Uploading avatar to Profile Vault...');
      final url = await _putToBlob(
        pathname: pathname,
        bytes: bytes,
        token: profileToken,
        contentType: contentType,
      );
      return url;
    } catch (e) {
      debugPrint('[VercelBlob] Profile upload notice: $e');
      return null;
    }
  }

  /// Uploads user avatar bytes directly to Vercel Blob profile partition
  Future<String?> uploadAvatarBytes(
    Uint8List bytes,
    String uid, {
    String fileName = 'avatar.jpg',
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final pathname = 'nexapp/avatars/$uid/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final contentType = _guessContentType(cleanName);

    try {
      debugPrint('[VercelBlob] Uploading avatar bytes to Profile Vault...');
      final url = await _putToBlob(
        pathname: pathname,
        bytes: bytes,
        token: profileToken,
        contentType: contentType,
      );
      return url;
    } catch (e) {
      debugPrint('[VercelBlob] Profile upload notice: $e');
      return null;
    }
  }

  /// Direct HTTP PUT to Vercel Blob storage API
  Future<String?> _putToBlob({
    required String pathname,
    required Uint8List bytes,
    required String token,
    required String contentType,
  }) async {
    final uri = Uri.parse('https://blob.vercel-storage.com/$pathname');

    final response = await http.put(
      uri,
      headers: {
        'authorization': 'Bearer $token',
        'x-api-version': '7',
        'x-add-random-suffix': '1',
        'content-type': contentType,
      },
      body: bytes,
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['url']?.toString();
    } else {
      debugPrint('[VercelBlob] HTTP ${response.statusCode}: ${response.body}');
      return null;
    }
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    return 'application/octet-stream';
  }
}
