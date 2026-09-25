import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CloudinaryVault {
  final int id;
  final String name;
  final String cloudName;
  final String uploadPreset;
  final String fallbackPreset;
  final String folder;
  final bool active;

  const CloudinaryVault({
    required this.id,
    required this.name,
    required this.cloudName,
    required this.uploadPreset,
    this.fallbackPreset = '',
    this.folder = 'nexchat-media',
    this.active = true,
  });
}

class CloudinaryUploadResult {
  final String url;
  final String secureUrl;
  final String publicId;
  final String format;
  final double duration;
  final int bytes;
  final String vault;
  final String cloudName;

  CloudinaryUploadResult({
    required this.url,
    required this.secureUrl,
    required this.publicId,
    required this.format,
    required this.duration,
    required this.bytes,
    required this.vault,
    required this.cloudName,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'secure_url': secureUrl,
      'public_id': publicId,
      'format': format,
      'duration': duration,
      'bytes': bytes,
      'vault': vault,
      'cloudName': cloudName,
    };
  }
}

/// NEXCHAT Multi-Vault Cloudinary Media Storage Pipeline
/// Supports direct client-side unsigned uploads for Reels, Videos, Avatars, and Media
/// with automatic sequential failover across all 15 Cloudinary accounts / vaults.
class CloudinaryStorageService {
  static final CloudinaryStorageService _instance = CloudinaryStorageService._internal();
  static CloudinaryStorageService get instance => _instance;
  CloudinaryStorageService._internal();

  /// The complete 15-vault pool identical to NEXCHAT
  static const List<CloudinaryVault> vaultPool = [
    CloudinaryVault(
      id: 1,
      name: 'Cloudinary Vault 1 (Primary - Active)',
      cloudName: 'kkiyeyj8',
      uploadPreset: 'ml_default',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 2,
      name: 'Cloudinary Vault 2 (NEX-VAULT - Active)',
      cloudName: 'l7roj4t8',
      uploadPreset: 'NEX-VAULT',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 3,
      name: 'Cloudinary Vault 3 (NEXVAULT2 - Active)',
      cloudName: 'bll4dbye',
      uploadPreset: 'NEXVAULT2',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 4,
      name: 'Cloudinary Vault 4 (NEXVAULT4 - Active)',
      cloudName: 'w36igvww',
      uploadPreset: 'NEXVAULT4',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 5,
      name: 'Cloudinary Vault 5 (NEXVAULT5 - Active)',
      cloudName: 'l5wrspfy',
      uploadPreset: 'NEXVAULT5',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 6,
      name: 'Cloudinary Vault 6 (NEXVAULT6 - Active)',
      cloudName: 'igo9ryhz',
      uploadPreset: 'NEXVAULT6',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 7,
      name: 'Cloudinary Vault 7 (NEXVUALT7 - Active)',
      cloudName: 'eicyrgp1',
      uploadPreset: 'NEXVUALT7',
      fallbackPreset: 'NEXVAULT7',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 8,
      name: 'Cloudinary Vault 8 (NEXVUALT8 - Active)',
      cloudName: 'amcjyisj',
      uploadPreset: 'NEXVUALT8',
      fallbackPreset: 'NEXVAULT8',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 9,
      name: 'Cloudinary Vault 9 (NEXVUALT9 - Active)',
      cloudName: 'yuzo3n8d',
      uploadPreset: 'NEXVUALT9',
      fallbackPreset: 'NEXVAULT9',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 10,
      name: 'Cloudinary Vault 10 (NEXVUALT10 - Active)',
      cloudName: 'aq5q5j9b',
      uploadPreset: 'NEXVUALT10',
      fallbackPreset: 'NEXVAULT10',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 11,
      name: 'Cloudinary Vault 11 (NEXVUALT11 - Active)',
      cloudName: 'szmtrrsa',
      uploadPreset: 'NEXVUALT11',
      fallbackPreset: 'NEXVAULT11',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 12,
      name: 'Cloudinary Vault 12 (NEXVUALT12 - Active)',
      cloudName: 'qrtbu9wp',
      uploadPreset: 'NEXVUALT12',
      fallbackPreset: 'NEXVAULT12',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 13,
      name: 'Cloudinary Vault 13 (NEXVUALT13 - Active)',
      cloudName: 'snssg69f',
      uploadPreset: 'NEXVUALT13',
      fallbackPreset: 'NEXVAULT13',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 14,
      name: 'Cloudinary Vault 14 (NEXVUALT14 - Active)',
      cloudName: 'ku8n112m',
      uploadPreset: 'NEXVUALT14',
      fallbackPreset: 'NEXVAULT14',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 15,
      name: 'Cloudinary Vault 15 (NEXVUALT15 - Active)',
      cloudName: 'm8yb3vlx',
      uploadPreset: 'NEXVUALT15',
      fallbackPreset: 'NEXVAULT15',
      folder: 'nexchat-media',
    ),
    CloudinaryVault(
      id: 16,
      name: 'Cloudinary Vault 16 (NEXVAULT16 - Active)',
      cloudName: 'd4e5nx1s',
      uploadPreset: 'NEXVAULT16',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 17,
      name: 'Cloudinary Vault 17 (NEXVAULT17 - Active)',
      cloudName: 'agtlu4wl',
      uploadPreset: 'NEXVAULT17',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 18,
      name: 'Cloudinary Vault 18 (NEXVAULT18 - Active)',
      cloudName: 'vaglvxqk',
      uploadPreset: 'NEXVAULT18',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 19,
      name: 'Cloudinary Vault 19 (NEXVAULT19 - Active)',
      cloudName: 'bx18lxml',
      uploadPreset: 'NEXVAULT19',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 20,
      name: 'Cloudinary Vault 20 (NEXVAULT20 - Active)',
      cloudName: 'hsb4reur',
      uploadPreset: 'NEXVAULT20',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 21,
      name: 'Cloudinary Vault 21 (NEXVAULT21 - Active)',
      cloudName: 'egupywam',
      uploadPreset: 'NEXVAULT21',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 22,
      name: 'Cloudinary Vault 22 (NEXVAULT22 - Active)',
      cloudName: 'rxpyax5m',
      uploadPreset: 'NEXVAULT22',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 23,
      name: 'Cloudinary Vault 23 (NEXVAULT23 - Reserve)',
      cloudName: 'nexvault23',
      uploadPreset: 'NEXVAULT23',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 24,
      name: 'Cloudinary Vault 24 (NEXVAULT24 - Reserve)',
      cloudName: 'nexvault24',
      uploadPreset: 'NEXVAULT24',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
    CloudinaryVault(
      id: 25,
      name: 'Cloudinary Vault 25 (NEXVAULT25 - Reserve)',
      cloudName: 'nexvault25',
      uploadPreset: 'NEXVAULT25',
      fallbackPreset: 'ml_default',
      folder: 'nexchat-media',
      active: true,
    ),
  ];

  static final Map<int, CloudinaryVault> _dynamicOverrides = {};

  /// Dynamically configure or update any vault parameters at runtime
  static void configureVault({
    required int id,
    required String cloudName,
    required String uploadPreset,
    String? fallbackPreset,
    String? name,
    String? folder,
    bool active = true,
  }) {
    _dynamicOverrides[id] = CloudinaryVault(
      id: id,
      name: name ?? 'Cloudinary Vault $id (Configured)',
      cloudName: cloudName,
      uploadPreset: uploadPreset,
      fallbackPreset: fallbackPreset ?? '',
      folder: folder ?? 'nexchat-media',
      active: active,
    );
    debugPrint('[CloudinaryPool] Configured Vault $id ($cloudName)');
  }

  /// Returns the full list of vaults with dynamic overrides applied
  List<CloudinaryVault> get allVaults {
    return vaultPool.map((v) => _dynamicOverrides[v.id] ?? v).toList();
  }

  /// Uploads media with automatic sequential failover across all 25 vaults
  Future<CloudinaryUploadResult> uploadMedia({
    File? file,
    Uint8List? bytes,
    required String fileName,
    String resourceType = 'auto',
    String folder = 'nexchat-media',
    void Function(double progress)? onProgress,
  }) async {
    if (file == null && bytes == null) {
      throw ArgumentError('Either file or bytes must be provided for upload.');
    }

    final Uint8List data = bytes ?? await file!.readAsBytes();

    dynamic lastError;

    final vaults = allVaults;
    for (int i = 0; i < vaults.length; i++) {
      final vault = vaults[i];
      if (!vault.active) continue;

      // Try primary preset first
      try {
        debugPrint('[CloudinaryPool] Attempting upload to ${vault.name} (${vault.cloudName})...');
        final result = await _uploadToSingleVault(
          data: data,
          fileName: fileName,
          vault: vault,
          preset: vault.uploadPreset,
          resourceType: resourceType,
          folder: folder,
          onProgress: onProgress,
        );
        debugPrint('[CloudinaryPool] Successfully uploaded to ${vault.name}: ${result.secureUrl}');
        return result;
      } catch (err) {
        debugPrint('[CloudinaryPool] Primary preset failed on ${vault.name}: $err');
        lastError = err;

        // Try fallback preset if available
        if (vault.fallbackPreset.isNotEmpty && vault.fallbackPreset != vault.uploadPreset) {
          try {
            debugPrint('[CloudinaryPool] Attempting fallback preset (${vault.fallbackPreset}) on ${vault.name}...');
            final result = await _uploadToSingleVault(
              data: data,
              fileName: fileName,
              vault: vault,
              preset: vault.fallbackPreset,
              resourceType: resourceType,
              folder: folder,
              onProgress: onProgress,
            );
            debugPrint('[CloudinaryPool] Fallback preset succeeded on ${vault.name}: ${result.secureUrl}');
            return result;
          } catch (fbErr) {
            debugPrint('[CloudinaryPool] Fallback preset also failed on ${vault.name}: $fbErr');
            lastError = fbErr;
          }
        }
      }
    }

    throw Exception('All 15 Cloudinary storage vaults failed. Last error: $lastError');
  }

  Future<CloudinaryUploadResult> _uploadToSingleVault({
    required Uint8List data,
    required String fileName,
    required CloudinaryVault vault,
    required String preset,
    required String resourceType,
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    final endpoint = Uri.parse('https://api.cloudinary.com/v1_1/${vault.cloudName}/$resourceType/upload');

    final request = http.MultipartRequest('POST', endpoint);
    request.fields['upload_preset'] = preset;
    if (folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    // High quality video optimization parameters
    if (resourceType == 'video') {
      request.fields['quality'] = 'auto:best';
      request.fields['fetch_format'] = 'auto';
      request.fields['video_codec'] = 'h264';
      request.fields['bit_rate'] = '8000k';
    }

    MediaType? contentType;
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.mp4')) {
      contentType = MediaType('video', 'mp4');
    } else if (lowerName.endsWith('.mov')) {
      contentType = MediaType('video', 'quicktime');
    } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      contentType = MediaType('image', 'jpeg');
    } else if (lowerName.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (lowerName.endsWith('.mp3')) {
      contentType = MediaType('audio', 'mpeg');
    } else if (lowerName.endsWith('.m4a')) {
      contentType = MediaType('audio', 'mp4');
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      data,
      filename: fileName,
      contentType: contentType,
    );
    request.files.add(multipartFile);

    onProgress?.call(0.15);

    final streamedResponse = await request.send();
    onProgress?.call(0.75);

    final response = await http.Response.fromStream(streamedResponse);
    onProgress?.call(1.0);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = jsonMap['secure_url']?.toString() ?? jsonMap['url']?.toString() ?? '';
      final publicId = jsonMap['public_id']?.toString() ?? '';
      final format = jsonMap['format']?.toString() ?? '';
      final duration = (jsonMap['duration'] is num) ? (jsonMap['duration'] as num).toDouble() : 0.0;
      final bytes = (jsonMap['bytes'] is int) ? (jsonMap['bytes'] as int) : data.length;

      return CloudinaryUploadResult(
        url: secureUrl,
        secureUrl: secureUrl,
        publicId: publicId,
        format: format,
        duration: duration,
        bytes: bytes,
        vault: vault.name,
        cloudName: vault.cloudName,
      );
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Convenience method for uploading user profile avatars
  Future<String> uploadImage({
    required File file,
    String folder = 'nexchat-avatars',
  }) async {
    final fileName = file.uri.pathSegments.last;
    final res = await uploadMedia(
      file: file,
      fileName: fileName,
      resourceType: 'image',
      folder: folder,
    );
    return res.secureUrl;
  }

  /// Convenience method for uploading avatar from memory bytes
  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
    String folder = 'nexchat-avatars',
  }) async {
    final res = await uploadMedia(
      bytes: bytes,
      fileName: fileName,
      resourceType: 'image',
      folder: folder,
    );
    return res.secureUrl;
  }

  /// Convenience method for uploading video reels with progress tracking
  Future<String> uploadVideo({
    required File file,
    String folder = 'nexchat-reels',
    void Function(double progress)? onProgress,
  }) async {
    final fileName = file.uri.pathSegments.last;
    final res = await uploadMedia(
      file: file,
      fileName: fileName,
      resourceType: 'video',
      folder: folder,
      onProgress: onProgress,
    );
    return res.secureUrl;
  }

  /// Convenience method for uploading voice notes / audio messages
  Future<String> uploadAudio({
    required File file,
    String folder = 'nexchat-audio',
  }) async {
    final fileName = file.uri.pathSegments.last;
    final res = await uploadMedia(
      file: file,
      fileName: fileName,
      resourceType: 'video', // Cloudinary handles audio under the video resource type
      folder: folder,
    );
    return res.secureUrl;
  }
}
