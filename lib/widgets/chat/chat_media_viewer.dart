import 'package:flutter/material.dart';

class ChatMediaViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final String? subtitle;

  const ChatMediaViewer({
    super.key,
    required this.imageUrl,
    this.title,
    this.subtitle,
  });

  static void show(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? subtitle,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (context, _, __) => ChatMediaViewer(
          imageUrl: imageUrl,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? 'Shared Image',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFF9E8DBE),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final progress = loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null;
              return Center(
                child: CircularProgressIndicator(
                  value: progress,
                  color: const Color(0xFFB44FFF),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Unable to load image preview',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
