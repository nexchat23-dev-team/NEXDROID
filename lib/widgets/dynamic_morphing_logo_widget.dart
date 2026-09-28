import 'dart:math' as math;
import 'package:flutter/material.dart';

class DynamicMorphingLogoWidget extends StatefulWidget {
  final double size;
  final bool showText;
  final bool? enableAnimation;
  final VoidCallback? onTap;

  const DynamicMorphingLogoWidget({
    super.key,
    this.size = 36.0,
    this.showText = true,
    this.enableAnimation,
    this.onTap,
  });

  @override
  State<DynamicMorphingLogoWidget> createState() => _DynamicMorphingLogoWidgetState();
}

class _DynamicMorphingLogoWidgetState extends State<DynamicMorphingLogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  final Color _primaryCyan = const Color(0xFF00E5FF);
  final Color _secondaryGreen = const Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (widget.enableAnimation != false) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicMorphingLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimation != oldWidget.enableAnimation) {
      if (widget.enableAnimation == false) {
        _rotationController.stop();
      } else if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cyber 3D Rotating Core Logo Canvas
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SleekCyberLogoPainter(
                  rotation: _rotationController.value,
                  primaryColor: _primaryCyan,
                  secondaryColor: _secondaryGreen,
                ),
              );
            },
          ),

          if (widget.showText) ...[
            const SizedBox(width: 8),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [_primaryCyan, _secondaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'NEXDROID',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SleekCyberLogoPainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;
  final Color secondaryColor;

  _SleekCyberLogoPainter({
    required this.rotation,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Outer rotating energy ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.1),
          primaryColor,
          secondaryColor,
          primaryColor.withValues(alpha: 0.1),
        ],
        transform: GradientRotation(rotation * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.9, ringPaint);

    // Orbiting nodes (3 points)
    for (int i = 0; i < 3; i++) {
      final angle = rotation * 2 * math.pi + (i * 2 * math.pi / 3);
      final px = center.dx + (radius * 0.9) * math.cos(angle);
      final py = center.dy + (radius * 0.9) * math.sin(angle);

      canvas.drawCircle(
        Offset(px, py),
        3.5,
        Paint()
          ..color = (i == 0 ? primaryColor : secondaryColor).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(Offset(px, py), 1.8, Paint()..color = Colors.white);
    }

    // Inner glowing core polygon (hexagon)
    final coreRadius = radius * 0.62;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) + (rotation * math.pi * 0.5);
      final x = center.dx + coreRadius * math.cos(angle);
      final y = center.dy + coreRadius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill
    final coreGradient = LinearGradient(
      colors: [primaryColor.withValues(alpha: 0.35), secondaryColor.withValues(alpha: 0.2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );

    // Stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Engraved 'N' Emblem
    final emblemPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final nPath = Path();
    final s = radius * 0.28;
    nPath.moveTo(center.dx - s, center.dy + s);
    nPath.lineTo(center.dx - s, center.dy - s);
    nPath.lineTo(center.dx + s, center.dy + s);
    nPath.lineTo(center.dx + s, center.dy - s);
    canvas.drawPath(nPath, emblemPaint);
  }

  @override
  bool shouldRepaint(covariant _SleekCyberLogoPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
