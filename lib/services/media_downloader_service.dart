import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadStatus { downloading, paused, completed, error, cancelled }

enum MediaPlatform { youtube, tiktok, instagram, twitter, unknown }

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    required this.quality,
    required this.format,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 1024 * 1024 * 15,
    this.speedKbps = 0.0,
    this.status = DownloadStatus.downloading,
    this.savedPath,
    this.thumbnailUrl,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String url;
  final String title;
  final MediaPlatform platform;
  final String quality;
  final String format; // 'mp4', 'mp3', etc.
  double progress;
  int downloadedBytes;
  int totalBytes;
  double speedKbps;
  DownloadStatus status;
  String? savedPath;
  String? thumbnailUrl;
  String? errorMessage;
  final DateTime createdAt;

  String get speedFormatted {
    if (speedKbps > 1024) {
      return '${(speedKbps / 1024).toStringAsFixed(1)} MB/s';
    }
    return '${speedKbps.toStringAsFixed(0)} KB/s';
  }

  String get sizeFormatted {
    final mb = totalBytes / (1024 * 1024);
    if (mb < 1) return '${(totalBytes / 1024).toStringAsFixed(0)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get downloadedFormatted {
    final mb = downloadedBytes / (1024 * 1024);
    if (mb < 1) return '${(downloadedBytes / 1024).toStringAsFixed(0)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get timeAgoFormatted {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'platform': platform.name,
        'quality': quality,
        'format': format,
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'status': status.name,
        'savedPath': savedPath,
        'thumbnailUrl': thumbnailUrl,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      platform: MediaPlatform.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => MediaPlatform.unknown,
      ),
      quality: json['quality'] as String? ?? '1080p',
      format: json['format'] as String? ?? 'mp4',
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.completed,
      ),
      savedPath: json['savedPath'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class MediaDownloaderService extends ChangeNotifier {
  static final MediaDownloaderService _instance =
      MediaDownloaderService._internal();
  factory MediaDownloaderService() => _instance;
  MediaDownloaderService._internal() {
    _loadHistory();
  }

  final List<DownloadTask> _activeTasks = [];
  final List<DownloadTask> _historyTasks = [];
  final Map<String, http.Client> _downloadClients = {};

  List<DownloadTask> get activeTasks => List.unmodifiable(_activeTasks);
  List<DownloadTask> get historyTasks => List.unmodifiable(_historyTasks);

  // ── Platform Detection ──────────────────────────────────────────────────
  static MediaPlatform detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('youtube-nocookie.com')) {
      return MediaPlatform.youtube;
    }
    if (lower.contains('tiktok.com') || lower.contains('vm.tiktok.com')) {
      return MediaPlatform.tiktok;
    }
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      return MediaPlatform.instagram;
    }
    if (lower.contains('twitter.com') || lower.contains('x.com') ||
        lower.contains('t.co')) {
      return MediaPlatform.twitter;
    }
    return MediaPlatform.unknown;
  }

  static String getPlatformName(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.tiktok:
        return 'TikTok';
      case MediaPlatform.instagram:
        return 'Instagram';
      case MediaPlatform.twitter:
        return 'X / Twitter';
      case MediaPlatform.unknown:
        return 'Web Media';
    }
  }

  static String getPlatformEmoji(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.youtube:
        return 'YT';
      case MediaPlatform.tiktok:
        return 'TT';
      case MediaPlatform.instagram:
        return 'IG';
      case MediaPlatform.twitter:
        return 'X';
      case MediaPlatform.unknown:
        return 'WEB';
    }
  }

  // ── API: Inspect / Extract URL ──────────────────────────────────────────
  /// Tries Cobalt v2 API first, falls back to simulated metadata.
  Future<Map<String, dynamic>> inspectUrl(String url) async {
    final platform = detectPlatform(url);
    final platformName = getPlatformName(platform);

    final providers = <Future<Map<String, dynamic>?> Function()>[
      () => _tryGenericExtractor(url),
      () => _tryTikWm(url),
      () => _tryInvidious(url),
      () => _tryCobaltV2(url),
      () => _tryCobaltLegacy(url),
      () => _trySnaptik(url),
      () => _tryYt1s(url),
      () => _tryLoaderTo(url),
      () => _tryVevioz(url),
      () => _tryXConvert(url),
      () => _trySaveFrom(url),
      () => _tryMultiPlatformApi(url),
    ];

    for (final provider in providers) {
      try {
        final result = await provider();
        if (result != null && (result['downloadUrl'] as String?)?.isNotEmpty == true) {
          return result;
        }
      } catch (e) {
        debugPrint('[MediaDownloader] provider failed: $e');
      }
    }

    return _buildFallbackMeta(platform, platformName, url);
  }

  Future<Map<String, dynamic>?> _tryCobaltV2(String url) async {
    final response = await http
        .post(
          Uri.parse('https://api.cobalt.tools/'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'url': url,
            'videoQuality': '1080',
            'audioFormat': 'mp3',
            'filenameStyle': 'pretty',
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;

    if (status == 'stream' || status == 'redirect' || status == 'tunnel') {
      return {
        'title': data['filename'] ?? data['text'] ?? 'Media content',
        'platform': detectPlatform(url),
        'downloadUrl': data['url'] ?? '',
        'thumbnailUrl': data['thumbnail'],
        'estimatedSizeMb': 28.0,
        'apiSource': 'cobalt',
      };
    }

    if (status == 'picker') {
      final picker = data['picker'] as List<dynamic>?;
      if (picker != null && picker.isNotEmpty) {
        final item = picker.first as Map<String, dynamic>;
        return {
          'title': data['audio'] != null ? 'Media content' : 'Media content',
          'platform': detectPlatform(url),
          'downloadUrl': item['url'] ?? '',
          'thumbnailUrl': item['thumb'],
          'estimatedSizeMb': 22.0,
          'apiSource': 'cobalt-picker',
        };
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _tryCobaltLegacy(String url) async {
    final response = await http
        .post(
          Uri.parse('https://co.wuk.sh/api/json'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString().toLowerCase();
    if (status == 'stream' || status == 'redirect') {
      return {
        'title': data['text'] ?? 'Media content',
        'platform': detectPlatform(url),
        'downloadUrl': data['url'] ?? '',
        'estimatedSizeMb': 24.5,
        'apiSource': 'cobalt-legacy',
      };
    }
    return null;
  }

  Future<Map<String, dynamic>?> _tryVevioz(String url) async {
    final response = await http
        .get(Uri.parse('https://vevioz.com/watch?url=${Uri.encodeComponent(url)}'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final html = response.body;
    final match = RegExp(r'data-url="([^"]+)"').firstMatch(html);
    if (match == null) return null;
    return {
      'title': 'Vevioz media',
      'platform': detectPlatform(url),
      'downloadUrl': match.group(1) ?? '',
      'apiSource': 'vevioz',
    };
  }

  Future<Map<String, dynamic>?> _tryLoaderTo(String url) async {
    final response = await http
        .get(Uri.parse('https://loader.to/api/button?url=${Uri.encodeComponent(url)}&format=mp3'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] == true && data['result'] is String) {
      return {
        'title': data['title'] ?? 'Loader.to media',
        'platform': detectPlatform(url),
        'downloadUrl': data['result'] as String,
        'apiSource': 'loader.to',
      };
    }
    return null;
  }

  Future<Map<String, dynamic>?> _trySnaptik(String url) async {
    final response = await http
        .post(
          Uri.parse('https://api.snaptik.app/aweme/v1/parse'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final link = data['data']?['play']?['url'] as String?;
    if (link == null) return null;
    return {
      'title': data['data']?['desc'] ?? 'SnapTik content',
      'platform': detectPlatform(url),
      'downloadUrl': link,
      'apiSource': 'snaptik',
    };
  }

  Future<Map<String, dynamic>?> _tryYt1s(String url) async {
    final response = await http
        .post(
          Uri.parse('https://www.yt1s.com/api/ajaxSearch/index'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'q': url}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final vid = data['vid'] as String?;
    if (vid == null) return null;
    return {
      'title': data['title'] ?? 'YT1S media',
      'platform': detectPlatform(url),
      'downloadUrl': 'https://www.yt1s.com/en68/download?video_id=$vid',
      'apiSource': 'yt1s',
    };
  }

  Future<Map<String, dynamic>?> _tryXConvert(String url) async {
    final response = await http
        .post(
          Uri.parse('https://xconvert.net/api/open/download'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final download = data['download'] as String?;
    if (download == null) return null;
    return {
      'title': data['title'] ?? 'XConvert media',
      'platform': detectPlatform(url),
      'downloadUrl': download,
      'apiSource': 'xconvert',
    };
  }

  Future<Map<String, dynamic>?> _trySaveFrom(String url) async {
    final response = await http
        .get(Uri.parse('https://savefrom.net/api/convert?url=${Uri.encodeComponent(url)}'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final download = data['url'] as String?;
    if (download == null) return null;
    return {
      'title': data['title'] ?? 'SaveFrom media',
      'platform': detectPlatform(url),
      'downloadUrl': download,
      'apiSource': 'savefrom',
    };
  }

  Future<Map<String, dynamic>?> _tryTikWm(String url) async {
    try {
      final response = await http
          .get(Uri.parse('https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] == 0 && data['data'] is Map) {
        final d = data['data'] as Map<String, dynamic>;
        final playUrl = d['play']?.toString() ?? d['wmplay']?.toString() ?? '';
        final musicUrl = d['music']?.toString() ?? '';
        final title = d['title']?.toString().isNotEmpty == true ? d['title'].toString() : 'TikTok Video';
        final cover = d['cover']?.toString();
        final sizeBytes = (d['size'] as num?)?.toDouble() ?? (15.0 * 1024 * 1024);

        if (playUrl.isNotEmpty) {
          return {
            'title': title,
            'platform': MediaPlatform.tiktok,
            'downloadUrl': playUrl,
            'audioUrl': musicUrl,
            'thumbnailUrl': cover,
            'estimatedSizeMb': (sizeBytes / (1024 * 1024)).clamp(1.0, 500.0),
            'apiSource': 'tikwm',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _tryInvidious(String url) async {
    try {
      final reg = RegExp(r'(?:v=|\/|youtu\.be\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})');
      final match = reg.firstMatch(url);
      if (match == null) return null;
      final videoId = match.group(1)!;

      final instances = [
        'https://inv.nadeko.net',
        'https://invidious.nerdvpn.de',
        'https://invidious.jing.rocks',
      ];

      for (final inst in instances) {
        try {
          final res = await http
              .get(Uri.parse('$inst/api/v1/videos/$videoId'))
              .timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final title = data['title']?.toString() ?? 'YouTube Video';
            final thumb = data['videoThumbnails'] is List && (data['videoThumbnails'] as List).isNotEmpty
                ? (data['videoThumbnails'] as List).first['url']?.toString()
                : null;
            final streams = data['formatStreams'] as List<dynamic>?;
            if (streams != null && streams.isNotEmpty) {
              final stream = streams.last as Map<String, dynamic>;
              final direct = stream['url']?.toString() ?? '';
              if (direct.isNotEmpty) {
                return {
                  'title': title,
                  'platform': MediaPlatform.youtube,
                  'downloadUrl': direct,
                  'thumbnailUrl': thumb,
                  'estimatedSizeMb': 24.0,
                  'apiSource': 'invidious',
                };
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _tryGenericExtractor(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;

      final lower = url.toLowerCase();
      final pathLower = uri.path.toLowerCase();
      final isDirectMediaExt = pathLower.endsWith('.mp4') ||
          pathLower.endsWith('.mp3') ||
          pathLower.endsWith('.m4a') ||
          pathLower.endsWith('.webm') ||
          pathLower.endsWith('.mov') ||
          pathLower.endsWith('.wav') ||
          pathLower.endsWith('.aac') ||
          pathLower.endsWith('.flac') ||
          pathLower.endsWith('.ogg') ||
          pathLower.endsWith('.opus') ||
          pathLower.endsWith('.jpg') ||
          pathLower.endsWith('.png') ||
          pathLower.endsWith('.webp') ||
          pathLower.endsWith('.gif') ||
          pathLower.endsWith('.pdf') ||
          pathLower.endsWith('.zip') ||
          pathLower.endsWith('.apk');

      final isStorageUrl = lower.contains('firebasestorage') ||
          lower.contains('storage.googleapis') ||
          lower.contains('cloudinary') ||
          lower.contains('s3.') ||
          lower.contains('cdn.') ||
          lower.contains('download');

      if (isDirectMediaExt || isStorageUrl) {
        String filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Direct Media File';
        if (filename.contains('?')) filename = filename.split('?').first;
        if (filename.isEmpty) filename = 'Downloaded Media';

        double sizeMb = 12.0;
        try {
          final headRes = await http.head(uri).timeout(const Duration(seconds: 4));
          final len = headRes.contentLength;
          if (len != null && len > 0) {
            sizeMb = len / (1024 * 1024);
          }
        } catch (_) {}

        return {
          'title': filename,
          'platform': MediaPlatform.unknown,
          'downloadUrl': url,
          'estimatedSizeMb': sizeMb,
          'apiSource': 'direct-stream',
        };
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _tryMultiPlatformApi(String url) async {
    final response = await http
        .post(
          Uri.parse('https://api.genyoutube.net/search'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final download = data['downloadUrl'] as String?;
    if (download == null) return null;
    return {
      'title': data['title'] ?? 'GenYouTube media',
      'platform': detectPlatform(url),
      'downloadUrl': download,
      'apiSource': 'genyoutube',
    };
  }

  Map<String, dynamic> _buildFallbackMeta(
      MediaPlatform platform, String platformName, String url) {
    // If the URL is any valid HTTP/HTTPS link, treat as direct streamable fallback
    final isValidHttp = url.startsWith('http://') || url.startsWith('https://');
    return {
      'title': '$platformName media',
      'platform': platform,
      'downloadUrl': isValidHttp ? url : '',
      'estimatedSizeMb': 15.0,
      'apiSource': isValidHttp ? 'universal-stream' : 'unavailable',
    };
  }

  // ── Start Download ──────────────────────────────────────────────────────
  Future<DownloadTask> startDownload({
    required String url,
    required String title,
    required MediaPlatform platform,
    required String quality,
    required String format,
    String? downloadUrl,
    String? thumbnailUrl,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: id,
      url: downloadUrl ?? url,
      title: title.isNotEmpty
          ? title
          : '${getPlatformName(platform)} Download',
      platform: platform,
      quality: quality,
      format: format,
      totalBytes: 0,
      thumbnailUrl: thumbnailUrl,
      status: DownloadStatus.downloading,
    );

    _activeTasks.add(task);
    notifyListeners();

    // Ensure we have storage permission on Android before resolving save path.
    await _ensureStoragePermission();
    unawaited(_downloadTask(task));
    return task;
  }

  Future<void> _ensureStoragePermission() async {
    try {
      if (!Platform.isAndroid) return;
      // On Android, request storage access when possible. Use the best available
      // permission for the platform and fall back to regular storage permission.
      if (await Permission.manageExternalStorage.isGranted) return;

      // Android 11+ may require MANAGE_EXTERNAL_STORAGE; request it first.
      final sdkInt = int.tryParse(Platform.version.split(' ').first) ?? 0;
      if (sdkInt >= 30) {
        if (await Permission.manageExternalStorage.request().isGranted) return;
      }

      // Fall back to legacy storage permission request.
      await Permission.storage.request();
    } catch (_) {}
  }

  Future<void> _downloadTask(DownloadTask task) async {
    if (task.url.isEmpty) {
      _failTask(task, 'No direct download URL was returned by the media provider.');
      return;
    }

    final client = http.Client();
    _downloadClients[task.id] = client;
    IOSink? sink;
    try {
      final resumeFrom = task.downloadedBytes;
      final request = http.Request('GET', Uri.parse(task.url));
      request.headers['User-Agent'] = 'NEX-App Media Downloader';
      if (resumeFrom > 0) {
        request.headers['Range'] = 'bytes=$resumeFrom-';
      }

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download server returned ${response.statusCode}');
      }

      final supportsResume = response.statusCode == 206 && resumeFrom > 0;
      final startingBytes = supportsResume ? resumeFrom : 0;
      if (!supportsResume) {
        task.downloadedBytes = 0;
      }
      final contentLength = response.contentLength ?? 0;
      task.totalBytes = supportsResume ? startingBytes + contentLength : contentLength;
      task.progress = task.totalBytes > 0 ? task.downloadedBytes / task.totalBytes : 0;

      final savedPath = task.savedPath ?? await _resolveSavePath(task);
      task.savedPath = savedPath;
      final file = File(savedPath);
      await file.parent.create(recursive: true);
      sink = file.openWrite(mode: supportsResume ? FileMode.append : FileMode.write);

      final stopwatch = Stopwatch()..start();
      await for (final chunk in response.stream) {
        if (task.status != DownloadStatus.downloading) break;
        sink.add(chunk);
        task.downloadedBytes += chunk.length;
        final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
        task.speedKbps = elapsedSeconds > 0
            ? task.downloadedBytes / 1024 / elapsedSeconds
            : 0;
        task.progress = task.totalBytes > 0
            ? (task.downloadedBytes / task.totalBytes).clamp(0.0, 1.0)
            : 0;
        notifyListeners();
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (task.status == DownloadStatus.paused) {
        task.speedKbps = 0;
        notifyListeners();
        return;
      }
      if (task.status == DownloadStatus.cancelled) return;
      if (task.totalBytes > 0 && task.downloadedBytes < task.totalBytes) {
        throw const HttpException('Download ended before all bytes were received');
      }

      task.progress = 1;
      task.status = DownloadStatus.completed;
      task.speedKbps = 0;
      _activeTasks.remove(task);
      _historyTasks.insert(0, task);
      await _saveHistory();
      notifyListeners();
    } catch (error) {
      if (task.status == DownloadStatus.paused || task.status == DownloadStatus.cancelled) {
        return;
      }
      _failTask(task, error.toString());
    } finally {
      await sink?.close();
      client.close();
      _downloadClients.remove(task.id);
    }
  }

  void _failTask(DownloadTask task, String message) {
    task.status = DownloadStatus.error;
    task.speedKbps = 0;
    task.errorMessage = message;
    _activeTasks.remove(task);
    _historyTasks.insert(0, task);
    unawaited(_saveHistory());
    notifyListeners();
  }

  // ── Controls ────────────────────────────────────────────────────────────
  void pauseTask(DownloadTask task) {
    task.status = DownloadStatus.paused;
    task.speedKbps = 0.0;
    _downloadClients[task.id]?.close();
    notifyListeners();
  }

  void resumeTask(DownloadTask task) {
    if (task.status == DownloadStatus.paused) {
      task.status = DownloadStatus.downloading;
      notifyListeners();
      unawaited(_downloadTask(task));
    }
  }

  void cancelTask(DownloadTask task) {
    task.status = DownloadStatus.cancelled;
    _downloadClients[task.id]?.close();
    _activeTasks.remove(task);
    notifyListeners();
  }

  void pauseAll() {
    for (final task in List<DownloadTask>.from(_activeTasks)) {
      if (task.status == DownloadStatus.downloading) pauseTask(task);
    }
  }

  void resumeAll() {
    for (final task in List<DownloadTask>.from(_activeTasks)) {
      if (task.status == DownloadStatus.paused) resumeTask(task);
    }
  }

  void cancelAll() {
    for (final task in List<DownloadTask>.from(_activeTasks)) {
      cancelTask(task);
    }
  }

  Future<void> clearHistory() async {
    _historyTasks.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> deleteHistoryItem(DownloadTask task) async {
    _historyTasks.removeWhere((t) => t.id == task.id);
    if (task.savedPath != null) {
      try {
        final f = File(task.savedPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<String> _resolveSavePath(DownloadTask task) async {
    try {
      Directory? baseDir;

      if (Platform.isAndroid) {
        final directDownload = Directory('/storage/emulated/0/Download');
        if (await directDownload.exists()) {
          baseDir = directDownload;
        } else {
          baseDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        baseDir = await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getDownloadsDirectory();
      }

      baseDir ??= await getApplicationDocumentsDirectory();
      final safeTitle = task.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final filename = '${safeTitle.isNotEmpty ? safeTitle : 'nex_media'}_${task.id}.${task.format}';
      final saveDir = Directory('${baseDir.path}/NEX Downloader');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      return '${saveDir.path}/$filename';
    } catch (_) {
      final fallback = await getApplicationDocumentsDirectory();
      final safeTitle = task.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      return '${fallback.path}/${safeTitle.isNotEmpty ? safeTitle : 'nex_media'}_${task.id}.${task.format}';
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────────
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _historyTasks.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('nex_media_downloader_history_v2', list);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('nex_media_downloader_history_v2');
      if (list != null && list.isNotEmpty) {
        _historyTasks.clear();
        for (final item in list) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            _historyTasks.add(DownloadTask.fromJson(map));
          } catch (_) {}
        }
        notifyListeners();
      } else {
        // Seed with demo data
        _historyTasks.addAll([
          DownloadTask(
            id: 'demo_yt1',
            url: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
            title: 'Cyberpunk Synthwave 4K Visualizer',
            platform: MediaPlatform.youtube,
            quality: '1080p',
            format: 'mp4',
            progress: 1.0,
            totalBytes: 1024 * 1024 * 42,
            downloadedBytes: 1024 * 1024 * 42,
            status: DownloadStatus.completed,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          DownloadTask(
            id: 'demo_tt1',
            url: 'https://tiktok.com/@user/video/123456',
            title: 'TikTok Dance Trend (No Watermark)',
            platform: MediaPlatform.tiktok,
            quality: '720p',
            format: 'mp4',
            progress: 1.0,
            totalBytes: 1024 * 1024 * 14,
            downloadedBytes: 1024 * 1024 * 14,
            status: DownloadStatus.completed,
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
          DownloadTask(
            id: 'demo_ig1',
            url: 'https://instagram.com/reel/ABC123',
            title: 'Instagram Travel Reel Audio',
            platform: MediaPlatform.instagram,
            quality: '320kbps',
            format: 'mp3',
            progress: 1.0,
            totalBytes: 1024 * 1024 * 6,
            downloadedBytes: 1024 * 1024 * 6,
            status: DownloadStatus.completed,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          DownloadTask(
            id: 'demo_tw1',
            url: 'https://twitter.com/user/status/123',
            title: 'Twitter Viral Video Clip',
            platform: MediaPlatform.twitter,
            quality: '720p',
            format: 'mp4',
            progress: 1.0,
            totalBytes: 1024 * 1024 * 18,
            downloadedBytes: 1024 * 1024 * 18,
            status: DownloadStatus.completed,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ]);
        await _saveHistory();
      }
    } catch (_) {}
  }
}
