import 'package:flutter/material.dart';
import '../services/upload_progress_service.dart';
import '../utils/constants.dart';

class UploadProgressOverlay extends StatelessWidget {
  final UploadProgressService uploadService;

  const UploadProgressOverlay({
    super.key,
    required this.uploadService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, UploadProgressEvent>>(
      valueListenable: uploadService.uploadProgress,
      builder: (context, uploads, _) {
        if (uploads.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: uploads.values
                .map((upload) => _UploadCard(upload: upload))
                .toList(),
          ),
        );
      },
    );
  }
}

class _UploadCard extends StatelessWidget {
  final UploadProgressEvent upload;

  const _UploadCard({required this.upload});

  Color get _statusColor {
    switch (upload.status) {
      case 'uploading':
        return kNeonGreen;
      case 'completed':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.grey;
      default:
        return kNeonBlue;
    }
  }

  IconData get _statusIcon {
    switch (upload.status) {
      case 'uploading':
        return Icons.cloud_upload_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_statusIcon, color: _statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      upload.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      upload.displayStatus,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (upload.status == 'uploading')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    upload.progressPercent,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (upload.status == 'uploading') ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: upload.progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(upload.bytesUploaded / 1024 / 1024).toStringAsFixed(1)} MB / ${(upload.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  _calculateSpeed(upload),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          if (upload.status == 'failed' && upload.error != null) ...[
            const SizedBox(height: 8),
            Text(
              upload.error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calculateSpeed(UploadProgressEvent upload) {
    // This would need to track time - for now return placeholder
    final speedMBps = (upload.totalBytes / 1024 / 1024) * upload.progress / 5; // Assume 5s
    if (speedMBps < 1) {
      return '${(speedMBps * 1024).toStringAsFixed(0)} KB/s';
    }
    return '${speedMBps.toStringAsFixed(1)} MB/s';
  }
}

/// Wrapper to add upload progress overlay to a widget
class WithUploadProgress extends StatelessWidget {
  final Widget child;
  final UploadProgressService uploadService;

  const WithUploadProgress({
    super.key,
    required this.child,
    required this.uploadService,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        UploadProgressOverlay(uploadService: uploadService),
      ],
    );
  }
}
