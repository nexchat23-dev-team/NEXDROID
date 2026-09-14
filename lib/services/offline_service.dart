import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  late Box _box;
  final _uuid = const Uuid();
  bool _syncing = false;

  Future<void> init() async {
    _box = Hive.box('messages');
    // start listening to connectivity
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _syncPending();
      }
    });
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
  }

  Future<String> saveLocalMessage({
    required String conversationId,
    required String senderId,
    String? text,
    String? localPath,
    Map<String, dynamic>? extra,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final record = {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text ?? '',
      'localPath': localPath,
      'mediaUrl': null,
      'status': 'pending', // pending, uploading, sent, failed
      'createdAt': now,
      'extra': extra ?? {},
    };

    await _box.put(id, record);
    // Try syncing immediately if online
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.any((r) => r != ConnectivityResult.none)) {
      _syncPending();
    }
    return id;
  }

  List<Map<String, dynamic>> getLocalMessages(String conversationId) {
    final values = _box.values
        .cast<Map>()
        .where((m) => m['conversationId'] == conversationId);
    return values.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// Return a Hive [ValueListenable] so UI can listen for changes.
  ValueListenable<Box> listenable() {
    return _box.listenable();
  }

  Future<void> _syncPending() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final pending = _box.values
          .cast<Map>()
          .where((m) => m['status'] == 'pending' || m['status'] == 'failed');
      for (final m in pending) {
        final msg = Map<String, dynamic>.from(m);
        final id = msg['id'] as String;
        try {
          await _box.put(id, {...msg, 'status': 'uploading'});
          String? remoteUrl = msg['mediaUrl'];
          if ((msg['localPath'] as String?) != null) {
            final localPath = msg['localPath'] as String;
            // upload file
            try {
              remoteUrl =
                  await _uploadFile(msg['conversationId'] as String, localPath);
            } catch (e) {
              await _box.put(id, {...msg, 'status': 'failed'});
              continue;
            }
          }

          // update local record
          await _box.put(id, {
            ...msg,
            'status': 'sent',
            'mediaUrl': remoteUrl,
            'localPath': null,
          });
        } catch (e) {
          await _box.put(id, {...msg, 'status': 'failed'});
          debugPrint('Sync error for message $e');
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<String> _uploadFile(String conversationId, String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) throw Exception('File not found: $localPath');
    final filename = p.basename(localPath);
    return 'file://$localPath?conversation=$conversationId&filename=$filename';
  }

  Future<void> markAsSent(String id, {String? mediaUrl}) async {
    final rec = Map<String, dynamic>.from(_box.get(id) as Map);
    await _box.put(id,
        {...rec, 'status': 'sent', 'mediaUrl': mediaUrl, 'localPath': null});
  }

  Future<void> retryFailed() async {
    await _syncPending();
  }

  Future<void> retryMessageById(String id) async {
    final rec = _box.get(id);
    if (rec == null) return;
    final msg = Map<String, dynamic>.from(rec as Map);
    await _box.put(id, {...msg, 'status': 'pending'});
    await _syncPending();
  }
}
