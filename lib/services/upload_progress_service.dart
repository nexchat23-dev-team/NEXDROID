import 'package:flutter/material.dart';

class UploadProgressEvent {
  final String id;
  final String fileName;
  final double progress; // 0.0 to 1.0
  final String status; // uploading, completed, failed, cancelled
  final String? error;
  final int bytesUploaded;
  final int totalBytes;

  UploadProgressEvent({
    required this.id,
    required this.fileName,
    required this.progress,
    required this.status,
    this.error,
    required this.bytesUploaded,
    required this.totalBytes,
  });

  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';
  
  String get displayStatus {
    switch (status) {
      case 'uploading':
        return 'Uploading...';
      case 'completed':
        return 'Upload complete';
      case 'failed':
        return 'Upload failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class UploadProgressService {
  static final UploadProgressService _instance = UploadProgressService._internal();
  
  factory UploadProgressService() => _instance;
  
  UploadProgressService._internal();

  final _uploadProgressController = ValueNotifier<Map<String, UploadProgressEvent>>({});

  ValueNotifier<Map<String, UploadProgressEvent>> get uploadProgress => _uploadProgressController;

  void startUpload({
    required String id,
    required String fileName,
    required int totalBytes,
  }) {
    final event = UploadProgressEvent(
      id: id,
      fileName: fileName,
      progress: 0.0,
      status: 'uploading',
      bytesUploaded: 0,
      totalBytes: totalBytes,
    );
    
    _uploadProgressController.value = {
      ..._uploadProgressController.value,
      id: event,
    };
  }

  void updateProgress({
    required String id,
    required int bytesUploaded,
    required int totalBytes,
  }) {
    final current = _uploadProgressController.value[id];
    if (current == null) return;

    final progress = totalBytes > 0 ? bytesUploaded / totalBytes : 0.0;
    final event = UploadProgressEvent(
      id: id,
      fileName: current.fileName,
      progress: progress.clamp(0.0, 1.0),
      status: 'uploading',
      bytesUploaded: bytesUploaded,
      totalBytes: totalBytes,
    );

    _uploadProgressController.value = {
      ..._uploadProgressController.value,
      id: event,
    };
  }

  void completeUpload({required String id}) {
    final current = _uploadProgressController.value[id];
    if (current == null) return;

    final event = UploadProgressEvent(
      id: id,
      fileName: current.fileName,
      progress: 1.0,
      status: 'completed',
      bytesUploaded: current.totalBytes,
      totalBytes: current.totalBytes,
    );

    _uploadProgressController.value = {
      ..._uploadProgressController.value,
      id: event,
    };

    // Remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      final updated = _uploadProgressController.value;
      updated.remove(id);
      _uploadProgressController.value = {...updated};
    });
  }

  void failUpload({required String id, String? error}) {
    final current = _uploadProgressController.value[id];
    if (current == null) return;

    final event = UploadProgressEvent(
      id: id,
      fileName: current.fileName,
      progress: current.progress,
      status: 'failed',
      error: error ?? 'Upload failed',
      bytesUploaded: current.bytesUploaded,
      totalBytes: current.totalBytes,
    );

    _uploadProgressController.value = {
      ..._uploadProgressController.value,
      id: event,
    };
  }

  void cancelUpload({required String id}) {
    final updated = _uploadProgressController.value;
    updated.remove(id);
    _uploadProgressController.value = {...updated};
  }

  void clearAll() {
    _uploadProgressController.value = {};
  }

  void dispose() {
    _uploadProgressController.dispose();
  }
}
