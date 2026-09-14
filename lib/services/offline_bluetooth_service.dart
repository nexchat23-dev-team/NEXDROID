import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';

enum OfflineMessageType { text, file }

class OfflineMessage {
  final String id;
  final String sender;
  final String text;
  final OfflineMessageType type;
  final DateTime timestamp;
  final String? fileName;
  final String? filePath;
  final int? fileSize;

  OfflineMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.type,
    required this.timestamp,
    this.fileName,
    this.filePath,
    this.fileSize,
  });
}

class Endpoint {
  final String id;
  final String name;
  Endpoint({required this.id, required this.name});
}

class OfflineBluetoothService {
  static const String _serviceId = 'com.nex.chat';
  final Strategy _strategy = Strategy.P2P_CLUSTER;
  final List<Endpoint> _endpoints = [];
  final _endpointsController = StreamController<List<Endpoint>>.broadcast();
  final _messagesController = StreamController<OfflineMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _transferProgressController = StreamController<double>.broadcast();

  String? _connectedEndpointId;
  String? _connectedEndpointName;
  final Map<int, String> _incomingFileNames = {};
  final Map<int, String> _incomingFilePaths = {};

  Stream<List<Endpoint>> get endpointsStream => _endpointsController.stream;
  Stream<OfflineMessage> get messageStream => _messagesController.stream;
  Stream<bool> get isConnectedStream => _connectionController.stream;
  Stream<double> get transferProgressStream =>
      _transferProgressController.stream;
  String? get connectedEndpointName => _connectedEndpointName;
  String? get connectedEndpointId => _connectedEndpointId;

  Future<bool> startAdvertising(String userName) async {
    try {
      await Nearby().stopAdvertising();
      return await Nearby().startAdvertising(
        userName,
        _strategy,
        onConnectionInitiated: (id, info) async {
          _connectedEndpointName = info.endpointName;
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: _onPayloadReceived,
            onPayloadTransferUpdate: _onPayloadTransferUpdate,
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            _connectionController.add(true);
          } else {
            _connectionController.add(false);
          }
        },
        onDisconnected: (id) {
          if (_connectedEndpointId == id) {
            _connectedEndpointId = null;
            _connectionController.add(false);
          }
        },
        serviceId: _serviceId,
      );
    } catch (_) {
      _connectionController.add(false);
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await Nearby().stopAdvertising();
    } catch (_) {}
  }

  Future<bool> startDiscovery(String userName) async {
    _endpoints.clear();
    _endpointsController.add(List.unmodifiable(_endpoints));
    try {
      await Nearby().stopDiscovery();
      return await Nearby().startDiscovery(
        userName,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          if (!_endpoints.any((e) => e.id == id)) {
            _endpoints.add(Endpoint(id: id, name: name));
            _endpointsController.add(List.unmodifiable(_endpoints));
          }
        },
        onEndpointLost: (id) {
          _endpoints.removeWhere((e) => e.id == id);
          _endpointsController.add(List.unmodifiable(_endpoints));
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      _endpointsController.addError(e);
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await Nearby().stopDiscovery();
    } catch (_) {}
  }

  Future<bool> requestConnection(String userName, String endpointId) async {
    try {
      return await Nearby().requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: (id, info) async {
          _connectedEndpointName = info.endpointName;
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: _onPayloadReceived,
            onPayloadTransferUpdate: _onPayloadTransferUpdate,
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            _connectionController.add(true);
          } else {
            _connectionController.add(false);
          }
        },
        onDisconnected: (id) {
          if (_connectedEndpointId == id) {
            _connectedEndpointId = null;
            _connectionController.add(false);
          }
        },
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> sendText(String text) async {
    if (_connectedEndpointId == null) return;
    await Nearby().sendBytesPayload(
        _connectedEndpointId!, Uint8List.fromList(utf8.encode(text)));
    _messagesController.add(OfflineMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'You',
      text: text,
      type: OfflineMessageType.text,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> sendFile(String filePath) async {
    if (_connectedEndpointId == null) return;
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;
    final payloadId =
        await Nearby().sendFilePayload(_connectedEndpointId!, filePath);
    await Nearby().sendBytesPayload(_connectedEndpointId!,
        Uint8List.fromList(utf8.encode('FILE_META:$payloadId:$fileName')));
    _messagesController.add(OfflineMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'You',
      text: 'Sent file: $fileName',
      type: OfflineMessageType.file,
      timestamp: DateTime.now(),
      fileName: fileName,
      filePath: filePath,
      fileSize: await file.length(),
    ));
  }

  Future<void> disconnect() async {
    if (_connectedEndpointId != null) {
      await Nearby().disconnectFromEndpoint(_connectedEndpointId!);
      _connectedEndpointId = null;
    }
    _connectionController.add(false);
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final message = utf8.decode(payload.bytes!);
      if (message.startsWith('FILE_META:')) {
        final parts = message.split(':');
        if (parts.length >= 3) {
          final id = int.tryParse(parts[1]);
          final fileName = parts.sublist(2).join(':');
          if (id != null) {
            _incomingFileNames[id] = fileName;
          }
        }
      } else {
        _messagesController.add(OfflineMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: 'Peer',
          text: message,
          type: OfflineMessageType.text,
          timestamp: DateTime.now(),
        ));
      }
    } else if (payload.type == PayloadType.FILE) {
      final filePath = payload.uri;
      if (filePath != null) {
        _incomingFilePaths[payload.id] = filePath;
      }
    }
  }

  Future<void> _onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) async {
    if (update.status == PayloadStatus.IN_PROGRESS) {
      final progress = update.totalBytes > 0
          ? update.bytesTransferred / update.totalBytes
          : 0.0;
      _transferProgressController.add(progress.clamp(0.0, 1.0));
    }

    if (update.status == PayloadStatus.SUCCESS &&
        _incomingFilePaths.containsKey(update.id)) {
      final sourcePath = _incomingFilePaths.remove(update.id)!;
      final fileName =
          _incomingFileNames.remove(update.id) ?? 'received_${update.id}';
      try {
        final directory = await getApplicationDocumentsDirectory();
        final targetPath = '${directory.path}/$fileName';
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(targetPath);
        }
        _messagesController.add(OfflineMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: 'Peer',
          text: 'Received file: $fileName',
          type: OfflineMessageType.file,
          timestamp: DateTime.now(),
          fileName: fileName,
          filePath: targetPath,
          fileSize: update.totalBytes,
        ));
      } catch (_) {
        // ignore copy errors; file may still exist in temp location
      }
    }

    if (update.status == PayloadStatus.FAILURE ||
        update.status == PayloadStatus.CANCELED) {
      _transferProgressController.add(0.0);
    }
  }

  void dispose() {
    stopAdvertising();
    stopDiscovery();
    _endpointsController.close();
    _messagesController.close();
    _connectionController.close();
    _transferProgressController.close();
  }
}
