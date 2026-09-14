import 'dart:math';
import 'package:flutter/material.dart';

class CyberBackground extends StatefulWidget {
  const CyberBackground({
    super.key,
    this.backgroundColors = const [
      Color(0xFF010308),
      Color(0xFF050816),
      Color(0xFF081122),
      Color(0xFF02040D),
    ],
    this.leftAuroraColors = const [
      Color(0xFF0078FF),
      Color(0xFF5A50FF),
      Color(0x00000000),
    ],
    this.rightAuroraColors = const [
      Color(0xFFC35AFF),
      Color(0xFF8E5FFF),
      Color(0x00000000),
    ],
    this.fogColor = const Color(0x1AFFFFFF),
    this.leftAuroraCenter = const Alignment(-0.26, -0.28),
    this.rightAuroraCenter = const Alignment(0.82, -0.16),
    this.leftAuroraRadius = 1.08,
    this.rightAuroraRadius = 1.0,
    this.leftAuroraScale = 0.34,
    this.rightAuroraScale = 0.24,
    this.starCount = 90,
    this.particleCount = 32,
    this.shipCount = 20,
  });

  final List<Color> backgroundColors;
  final List<Color> leftAuroraColors;
  final List<Color> rightAuroraColors;
  final Color fogColor;
  final Alignment leftAuroraCenter;
  final Alignment rightAuroraCenter;
  final double leftAuroraRadius;
  final double rightAuroraRadius;
  final double leftAuroraScale;
  final double rightAuroraScale;
  final int starCount;
  final int particleCount;
  final int shipCount;

  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _CyberPainter(
          progress: _controller.value,
          backgroundColors: widget.backgroundColors,
          leftAuroraColors: widget.leftAuroraColors,
          rightAuroraColors: widget.rightAuroraColors,
          fogColor: widget.fogColor,
          leftAuroraCenter: widget.leftAuroraCenter,
          rightAuroraCenter: widget.rightAuroraCenter,
          leftAuroraRadius: widget.leftAuroraRadius,
          rightAuroraRadius: widget.rightAuroraRadius,
          leftAuroraScale: widget.leftAuroraScale,
          rightAuroraScale: widget.rightAuroraScale,
          starCount: widget.starCount,
          particleCount: widget.particleCount,
          shipCount: widget.shipCount,
        ),
      ),
    );
  }
}

class _CyberPainter extends CustomPainter {
  const _CyberPainter({
    required this.progress,
    required this.backgroundColors,
    required this.leftAuroraColors,
    required this.rightAuroraColors,
    required this.fogColor,
    required this.leftAuroraCenter,
    required this.rightAuroraCenter,
    required this.leftAuroraRadius,
    required this.rightAuroraRadius,
    required this.leftAuroraScale,
    required this.rightAuroraScale,
    required this.starCount,
    required this.particleCount,
    required this.shipCount,
  });

  final double progress;
  final List<Color> backgroundColors;
  final List<Color> leftAuroraColors;
  final List<Color> rightAuroraColors;
  final Color fogColor;
  final Alignment leftAuroraCenter;
  final Alignment rightAuroraCenter;
  final double leftAuroraRadius;
  final double rightAuroraRadius;
  final double leftAuroraScale;
  final double rightAuroraScale;
  final int starCount;
  final int particleCount;
  final int shipCount;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        colors: backgroundColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final leftAuroraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          leftAuroraCenter.x + progress * 0.06,
          leftAuroraCenter.y + progress * 0.04,
        ),
        radius: leftAuroraRadius,
        colors: leftAuroraColors,
      ).createShader(rect);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.18),
      size.width * leftAuroraScale,
      leftAuroraPaint,
    );

    final rightAuroraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          rightAuroraCenter.x - progress * 0.04,
          rightAuroraCenter.y + progress * 0.03,
        ),
        radius: rightAuroraRadius,
        colors: rightAuroraColors,
      ).createShader(rect);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.16),
      size.width * rightAuroraScale,
      rightAuroraPaint,
    );

    final fogPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.05 + progress * 0.02, 0.12 - progress * 0.01),
        radius: 1.35,
        colors: [
          fogColor,
          fogColor.withValues(alpha: 0.18),
          const Color(0x00000000),
        ],
      ).createShader(rect);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.55),
      size.width * 0.85,
      fogPaint,
    );

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final blueStarPaint = Paint()..color = const Color(0xFF66D9FF).withValues(alpha: 0.85);
    final purpleStarPaint = Paint()..color = const Color(0xFFC28BFF).withValues(alpha: 0.8);

    for (var i = 0; i < starCount; i++) {
      final x = ((i * 37) % 1000) / 1000 * size.width;
      final y = ((i * 53 + 11) % 1000) / 1000 * size.height;
      final radius = (i % 5 == 0 ? 1.8 : i % 3 == 0 ? 1.2 : 0.8) +
          0.05 * (i % 4);
      final twinkle = 0.28 + (0.72 * ((sin((progress * 2.6) + i) + 1) / 2));
      final paint = i % 4 == 0
          ? purpleStarPaint
          : i % 3 == 0
              ? blueStarPaint
              : starPaint;
      paint.color = paint.color.withValues(alpha: twinkle * 0.9);
      canvas.drawCircle(Offset(x, y), radius, paint);
      paint.color = paint.color.withValues(alpha: 0.95);
    }

    final particlePaint = Paint()
      ..color = const Color(0xFF66B3FF).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 0; i < particleCount; i++) {
      final baseX = ((i * 97 + 13) % 1000) / 1000 * size.width;
      final baseY = ((i * 71 + 29) % 1000) / 1000 * size.height;
      final drift = (i % 7) * 0.02 + progress * 0.03;
      final offsetY = baseY + size.height * drift;
      final sizeFactor = 2.4 + (i % 5) * 0.9;
      canvas.drawCircle(
        Offset(baseX, offsetY.clamp(0, size.height)),
        sizeFactor,
        particlePaint,
      );
    }

    final streakPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.white,
          Color(0xFF66B3FF),
          Color(0x00000000),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);

    final streakY = size.height * (0.16 + (progress * 0.06));
    canvas.drawRect(
      Rect.fromLTWH(-size.width * 0.08, streakY, size.width * 0.25, 2.0),
      streakPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(-size.width * 0.06, size.height * 0.4, size.width * 0.18, 1.4),
      streakPaint,
    );

    for (var i = 0; i < shipCount; i++) {
      final direction = i.isEven ? 1.0 : -1.0;
      final normalized = (progress + (i / shipCount) * 0.85) % 1.0;
      final sweep = (progress * 1.35 + i * 0.08) % 1.0;
      final enterFromSide = i % 3 == 0;
      final x = enterFromSide
          ? (direction > 0
              ? -40 - (normalized * 140)
              : size.width + 40 + (normalized * 140))
          : (direction > 0
              ? size.width * (0.04 + sweep * 0.92)
              : size.width * (0.96 - sweep * 0.92));
      final y = size.height * (0.08 + ((i * 67) % 1000) / 1000 * 0.8);
      final scale = 0.9 + ((i % 5) * 0.24);
      final isFrontLayer = i % 7 == 0;
      final shouldBurst = i % 11 == 0 && normalized > 0.45 && normalized < 0.6;

      final trailLength = 70 + (i % 4) * 20;
      final trailStart = Offset(x - direction * trailLength, y);
      final trailEnd = Offset(x - direction * 10, y);
      final trailPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00000000),
            const Color(0xFF66B3FF).withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.4),
          ],
          begin: direction > 0 ? Alignment.centerRight : Alignment.centerLeft,
          end: direction > 0 ? Alignment.centerLeft : Alignment.centerRight,
        ).createShader(Rect.fromPoints(trailStart, trailEnd));
      canvas.drawLine(trailStart, trailEnd, trailPaint);

      final shipBodyPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      final shipGlowPaint = Paint()
        ..color = isFrontLayer
            ? const Color(0xFF7CFFE7).withValues(alpha: 0.34)
            : const Color(0xFFFF5ACD).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final shipWingPaint = Paint()
        ..color = const Color(0xFF66D9FF).withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      final body = Path()
        ..moveTo(x, y - 6 * scale)
        ..lineTo(x + direction * 10 * scale, y)
        ..lineTo(x, y + 6 * scale)
        ..lineTo(x - direction * 5 * scale, y + 2.5 * scale)
        ..close();
      canvas.drawPath(body, shipBodyPaint);
      canvas.drawPath(body, shipGlowPaint);

      final wing = Path()
        ..moveTo(x - direction * 2.5 * scale, y - 4 * scale)
        ..lineTo(x - direction * 6 * scale, y - 1.5 * scale)
        ..lineTo(x - direction * 2.5 * scale, y + 4 * scale)
        ..close();
      canvas.drawPath(wing, shipWingPaint);

      if (isFrontLayer) {
        canvas.drawCircle(
          Offset(x, y),
          12 + scale * 3,
          Paint()..color = const Color(0xFF7CFFE7).withValues(alpha: 0.08),
        );
      }

      if (shouldBurst) {
        final burstPaint = Paint()
          ..color = const Color(0xFFFF5ACD).withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        for (var burst = 0; burst < 6; burst++) {
          final burstAngle = (burst / 6) * 2 * pi;
          final burstX = x + cos(burstAngle) * 16 * scale;
          final burstY = y + sin(burstAngle) * 16 * scale;
          canvas.drawCircle(Offset(burstX, burstY), 2.2 + scale * 0.4, burstPaint);
        }
      }

      if (i % 5 == 0 && normalized > 0.2) {
        for (var drone = 0; drone < 3; drone++) {
          final droneOffset = (drone - 1) * 8.0;
          canvas.drawCircle(
            Offset(x + direction * 6 * scale + droneOffset, y + 10 + drone * 2),
            1.2 + scale * 0.25,
            Paint()..color = const Color(0xFF66D9FF).withValues(alpha: 0.9),
          );
        }
      }

      canvas.drawCircle(
        Offset(x + direction * 4 * scale, y),
        1.8 + scale * 0.6,
        Paint()..color = const Color(0xFF7CFFE7).withValues(alpha: 0.95),
      );

      canvas.drawCircle(
        Offset(x - direction * 2.5 * scale, y),
        1.0 + scale * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
