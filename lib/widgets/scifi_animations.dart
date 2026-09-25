import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/game_sound_service.dart';

// Helper to calculate looking direction / pointing offset for tracking
Offset _calcLookOffset(Offset origin, Offset? target, double maxDist) {
  if (target == null) return Offset.zero;
  final diff = target - origin;
  final dist = diff.distance;
  if (dist == 0) return Offset.zero;
  return (diff / dist) * min(maxDist, dist);
}

// ============================================================
// WIDGET 1: Terminator Endoskeleton
// ============================================================
class TerminatorAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const TerminatorAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TerminatorAnimation> createState() => _TerminatorAnimationState();
}

class _TerminatorAnimationState extends State<TerminatorAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late AnimationController _eyeCtrl;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat();
    _eyeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _eyeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => setState(() => _touchPos = details.localPosition),
      onPanUpdate: (details) => setState(() => _touchPos = details.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (details) => setState(() => _touchPos = details.localPosition),
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_scanCtrl, _eyeCtrl]),
        builder: (context, _) {
          return CustomPaint(
            painter: _TerminatorPainter(
              scanProgress: _scanCtrl.value,
              eyeGlow: _eyeCtrl.value,
              gyroX: widget.gyroX,
              gyroY: widget.gyroY,
              touchPos: _touchPos,
            ),
          );
        },
      ),
    );
  }
}

class _TerminatorPainter extends CustomPainter {
  final double scanProgress;
  final double eyeGlow;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _TerminatorPainter({
    required this.scanProgress,
    required this.eyeGlow,
    required this.gyroX,
    required this.gyroY,
    required this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5 + gyroX * 20;
    final cy = size.height * 0.45 + gyroY * 20;

    // Deep red warning background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF040000));

    // Futuristic HUD metrics
    final hudPaint = Paint()..color = const Color(0xFFFF2200).withValues(alpha: 0.15)..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.28, hudPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.7, height: size.height * 0.5), hudPaint);

    // Endoskeleton Skull frame
    final skullPaint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.38, height: size.height * 0.3), skullPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + size.height * 0.1), width: size.width * 0.2, height: size.height * 0.08), skullPaint);

    // Eyes positioning
    final eyeLeft = Offset(cx - size.width * 0.08, cy - size.height * 0.03);
    final eyeRight = Offset(cx + size.width * 0.08, cy - size.height * 0.03);

    // Dynamic pupil look offset tracking touch
    final lookOffsetL = _calcLookOffset(eyeLeft, touchPos, 5.0);
    final lookOffsetR = _calcLookOffset(eyeRight, touchPos, 5.0);

    // Red glowing eyes with looking aberration
    final eyeGlowPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: eyeGlow * 0.9 + 0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * eyeGlow + 2);

    canvas.drawCircle(eyeLeft + lookOffsetL, 8, eyeGlowPaint);
    canvas.drawCircle(eyeRight + lookOffsetR, 8, eyeGlowPaint);

    // Red hot pinpoint pupil core
    final pupilPaint = Paint()..color = Colors.white;
    canvas.drawCircle(eyeLeft + lookOffsetL, 2, pupilPaint);
    canvas.drawCircle(eyeRight + lookOffsetR, 2, pupilPaint);

    // Sweep scan line
    final scanY = size.height * scanProgress;
    final laserPaint = Paint()
      ..color = const Color(0xFFFF1100).withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), laserPaint);

    // Scan overlay metrics text
    if (touchPos != null) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'TARGET LOCK\nT-800 ACTIVE',
          style: TextStyle(color: Color(0xFFFF2200), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(touchPos!.dx + 12, touchPos!.dy - 12));
      canvas.drawCircle(touchPos!, 8, Paint()..color = const Color(0xFFFF2200).withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _TerminatorPainter old) => true;

  }

// ============================================================
// WIDGET 2: Iron Man Arc Reactor
// ============================================================
class IronManAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const IronManAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<IronManAnimation> createState() => _IronManAnimationState();
}

class _IronManAnimationState extends State<IronManAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _chargeSpeed = 1.0;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => setState(() {
        _touchPos = details.localPosition;
        _chargeSpeed = 3.5;
      }),
      onPanUpdate: (details) => setState(() => _touchPos = details.localPosition),
      onPanEnd: (_) => setState(() {
        _touchPos = null;
        _chargeSpeed = 1.0;
      }),
      onTapDown: (details) => setState(() {
        _touchPos = details.localPosition;
        _chargeSpeed = 3.5;
      }),
      onTapUp: (_) => setState(() {
        _touchPos = null;
        _chargeSpeed = 1.0;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _IronManPainter(
              t: _ctrl.value * _chargeSpeed,
              gyroX: widget.gyroX,
              gyroY: widget.gyroY,
              touchPos: _touchPos,
            ),
          );
        },
      ),
    );
  }
}

class _IronManPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _IronManPainter({required this.t, required this.gyroX, required this.gyroY, required this.touchPos});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF00060E));
    final cx = size.width * 0.5 + gyroX * 20;
    final cy = size.height * 0.5 + gyroY * 20;

    // Glowing core circles
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.35, glowPaint);

    // Inner mechanical details
    final ringPaint = Paint()
      ..color = const Color(0xFF00CFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.2, ringPaint);

    // Rotating segments
    final numSegments = 10;
    for (int i = 0; i < numSegments; i++) {
      final angle = (i * 2 * pi / numSegments) + (t * pi * 0.5);
      final x1 = cx + cos(angle) * (size.width * 0.18);
      final y1 = cy + sin(angle) * (size.width * 0.18);
      final x2 = cx + cos(angle) * (size.width * 0.22);
      final y2 = cy + sin(angle) * (size.width * 0.22);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), ringPaint..strokeWidth = 4.0);
    }

    // Centered triangular core
    final corePath = Path()
      ..moveTo(cx, cy - 25)
      ..lineTo(cx - 22, cy + 15)
      ..lineTo(cx + 22, cy + 15)
      ..close();
    canvas.drawPath(corePath, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.inner, 4));
    canvas.drawPath(corePath, Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 3);

    // Energy discharge arcs towards touch position
    if (touchPos != null) {
      final sparkPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final rng = Random();
      Offset curr = Offset(cx, cy);
      for (int i = 0; i < 4; i++) {
        final next = Offset.lerp(Offset(cx, cy), touchPos!, (i + 1) / 4)! +
            Offset(rng.nextDouble() * 20 - 10, rng.nextDouble() * 20 - 10);
        canvas.drawLine(curr, next, sparkPaint);
        curr = next;
      }
      canvas.drawLine(curr, touchPos!, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IronManPainter old) => true;

  }

// ============================================================
// WIDGET 3: Matrix Digital Rain
// ============================================================
class MatrixRainAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const MatrixRainAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MatrixRainAnimation> createState() => _MatrixRainAnimationState();
}

class _MatrixRainAnimationState extends State<MatrixRainAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = Random();
  late List<double> _drops;
  late List<double> _speeds;
  late List<int> _chars;
  static const int _cols = 20;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _drops = List.generate(_cols, (i) => _rng.nextDouble() * -120);
    _speeds = List.generate(_cols, (i) => 0.8 + _rng.nextDouble() * 1.8);
    _chars = List.generate(_cols, (i) => _rng.nextInt(94) + 33);
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 70))
      ..addListener(() {
        for (int i = 0; i < _cols; i++) {
          _drops[i] += _speeds[i];
          if (_drops[i] > 100) {
            _drops[i] = -_rng.nextDouble() * 50;
          }
          _chars[i] = _rng.nextInt(94) + 33;
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _touchPos = details.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (details) => setState(() => _touchPos = details.localPosition),
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _MatrixPainter(drops: _drops, chars: _chars, gyroX: widget.gyroX, touchPos: _touchPos),
        ),
      ),
    );
  }
}

class _MatrixPainter extends CustomPainter {
  final List<double> drops;
  final List<int> chars;
  final double gyroX;
  final Offset? touchPos;
  static const int _cols = 20;

  const _MatrixPainter({required this.drops, required this.chars, required this.gyroX, required this.touchPos});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000000));
    final colW = size.width / _cols;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int c = 0; c < _cols; c++) {
      final x = colW * c + gyroX * 8;
      final progress = (drops[c] / 100).clamp(0.0, 1.0);

      for (int r = 0; r < 16; r++) {
        final y = (progress * size.height) - r * 18.0;
        if (y < 0 || y > size.height) continue;

        // Color modification near touch position
        Color codeColor = const Color(0xFF00FF41);
        if (touchPos != null) {
          final distToTouch = (Offset(x, y) - touchPos!).distance;
          if (distToTouch < 80) {
            codeColor = const Color(0xFF00E5FF); // Cyber blue shift near touch
          }
        }

        final alpha = (1.0 - r / 16).clamp(0.0, 1.0);
        final isHead = r == 0;
        textPainter.text = TextSpan(
          text: String.fromCharCode(chars[c]),
          style: TextStyle(
            color: isHead ? Colors.white : codeColor.withValues(alpha: alpha),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter old) => true;

  }

// ============================================================
// WIDGET 4: Lightsaber Duel
// ============================================================
class LightsaberAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const LightsaberAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<LightsaberAnimation> createState() => _LightsaberAnimationState();
}

class _LightsaberAnimationState extends State<LightsaberAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _touchPos = details.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (details) => setState(() => _touchPos = details.localPosition),
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _LightsaberPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, touchPos: _touchPos),
        ),
      ),
    );
  }
}

class _LightsaberPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _LightsaberPainter({required this.t, required this.gyroX, required this.gyroY, required this.touchPos});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010107));

    // Clash point follows touch if interacting, otherwise oscillates
    final clashX = touchPos != null ? touchPos!.dx : (size.width * 0.5 + gyroX * 25);
    final clashY = touchPos != null ? touchPos!.dy : (size.height * 0.45 + gyroY * 25 + sin(t * pi) * 15);
    final angle = sin(t * pi) * 0.15;

    // Blue saber paint
    final bluePaint = Paint()
      ..color = const Color(0xFF0088FF)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    // Draw Blue Saber (Jedi side)
    canvas.drawLine(
      Offset(clashX - 10, clashY - 10),
      Offset(clashX - size.width * 0.4 * cos(angle - 0.4), clashY - size.height * 0.4 * sin(angle - 0.4)),
      bluePaint,
    );
    canvas.drawLine(
      Offset(clashX - 10, clashY - 10),
      Offset(clashX - size.width * 0.4 * cos(angle - 0.4), clashY - size.height * 0.4 * sin(angle - 0.4)),
      Paint()..color = Colors.white..strokeWidth = 2.0..strokeCap = StrokeCap.round,
    );

    // Red saber paint
    final redPaint = Paint()
      ..color = const Color(0xFFFF0033)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    // Draw Red Saber (Sith side)
    canvas.drawLine(
      Offset(clashX + 10, clashY + 10),
      Offset(clashX + size.width * 0.4 * cos(angle + 0.4), clashY + size.height * 0.4 * sin(angle + 0.4)),
      redPaint,
    );
    canvas.drawLine(
      Offset(clashX + 10, clashY + 10),
      Offset(clashX + size.width * 0.4 * cos(angle + 0.4), clashY + size.height * 0.4 * sin(angle + 0.4)),
      Paint()..color = Colors.white..strokeWidth = 2.0..strokeCap = StrokeCap.round,
    );

    // Spark bursts
    final sparksCount = touchPos != null ? 15 : 6;
    final rng = Random();
    final sparkPaint = Paint()..color = const Color(0xFFFFD700);
    for (int i = 0; i < sparksCount; i++) {
      final rad = rng.nextDouble() * 2 * pi;
      final dist = (rng.nextDouble() * 30) + 10;
      canvas.drawCircle(Offset(clashX + cos(rad) * dist, clashY + sin(rad) * dist), rng.nextDouble() * 2 + 1, sparkPaint);
    }

    // Clash flash core
    canvas.drawCircle(Offset(clashX, clashY), 16, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }

  @override
  bool shouldRepaint(covariant _LightsaberPainter old) => true;

  }

// ============================================================
// WIDGET 5: Xenomorph Shadow
// ============================================================
class XenomorphAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const XenomorphAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<XenomorphAnimation> createState() => _XenomorphAnimationState();
}

class _XenomorphAnimationState extends State<XenomorphAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _dripPos;
  double _screenShake = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerHiss(TapDownDetails details) {
    setState(() {
      _dripPos = details.localPosition;
      _screenShake = 15.0;
    });
    // Decay shake
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _screenShake *= 0.7;
        if (_screenShake < 0.5) {
          _screenShake = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _triggerHiss,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final rng = Random();
          final shakeX = _screenShake > 0 ? (rng.nextDouble() * _screenShake - _screenShake / 2) : 0.0;
          final shakeY = _screenShake > 0 ? (rng.nextDouble() * _screenShake - _screenShake / 2) : 0.0;

          return CustomPaint(
            painter: _XenomorphPainter(
              t: _ctrl.value,
              gyroX: widget.gyroX,
              gyroY: widget.gyroY,
              shakeX: shakeX,
              shakeY: shakeY,
              dripPos: _dripPos,
            ),
          );
        },
      ),
    );
  }
}

class _XenomorphPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final double shakeX;
  final double shakeY;
  final Offset? dripPos;

  const _XenomorphPainter({
    required this.t,
    required this.gyroX,
    required this.gyroY,
    required this.shakeX,
    required this.shakeY,
    required this.dripPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(shakeX, shakeY);

    // Pitch black background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000300));

    final emerge = (sin(t * pi) * 0.5 + 0.5);
    final cx = size.width * 0.5 + gyroX * 22;
    final cy = size.height * (0.8 - emerge * 0.25) + gyroY * 15;

    // Bioluminescent green nest background glow
    final nestPaint = Paint()
      ..color = const Color(0xFF11FF44).withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.5, nestPaint);

    // Outer shell silhouette
    final bioPaint = Paint()..color = const Color(0xFF060D07);
    final headPath = Path()
      ..moveTo(cx - 30, cy)
      ..quadraticBezierTo(cx - 50, cy - size.height * 0.18, cx, cy - size.height * 0.25)
      ..quadraticBezierTo(cx + 80, cy - size.height * 0.22, cx + 90, cy - size.height * 0.08)
      ..quadraticBezierTo(cx + 20, cy, cx - 30, cy)
      ..close();
    canvas.drawPath(headPath, bioPaint);

    // Inner jaw elongation scan
    if (emerge > 0.7) {
      final innerJawPaint = Paint()..color = const Color(0xFF020502);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx - 35, cy - 30), width: 35, height: 12),
        innerJawPaint,
      );
    }

    // Slime drips
    if (dripPos != null) {
      final acidPaint = Paint()
        ..color = const Color(0xFF00FF44).withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(dripPos!, 10, acidPaint);
      canvas.drawCircle(dripPos! + const Offset(0, 15), 6, acidPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _XenomorphPainter old) => true;

  }

// ============================================================
// WIDGET 6: Predator Cloaking
// ============================================================
class PredatorAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const PredatorAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<PredatorAnimation> createState() => _PredatorAnimationState();
}

class _PredatorAnimationState extends State<PredatorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _targetLock;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _targetLock = details.localPosition),
      onPanEnd: (_) => setState(() => _targetLock = null),
      onTapDown: (details) => setState(() => _targetLock = details.localPosition),
      onTapUp: (_) => setState(() => _targetLock = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _PredatorPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, targetLock: _targetLock),
        ),
      ),
    );
  }
}

class _PredatorPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? targetLock;

  const _PredatorPainter({required this.t, required this.gyroX, required this.gyroY, this.targetLock});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000C02));

    final cx = size.width * 0.5 + gyroX * 20;
    final cy = size.height * 0.45 + gyroY * 20;
    final shimmerProgress = (t * 2 * pi);

    // Heat vision thermal glow
    final thermalPaint = Paint()
      ..color = const Color(0xFFFF3300).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(Offset(cx, cy), 120, thermalPaint);

    // Interactive hunting target laser
    final targetX = targetLock != null ? targetLock!.dx : (cx + cos(shimmerProgress) * 60);
    final targetY = targetLock != null ? targetLock!.dy : (cy + sin(shimmerProgress) * 60);

    final laserPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Draw three points of Predator laser sight
    canvas.drawCircle(Offset(targetX, targetY), 4, laserPaint);
    canvas.drawCircle(Offset(targetX - 8, targetY + 10), 3, laserPaint);
    canvas.drawCircle(Offset(targetX + 8, targetY + 10), 3, laserPaint);

    if (targetLock != null) {
      // Futuristic locked target bracket
      final targetBoxPaint = Paint()
        ..color = const Color(0xFFFF3300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(Rect.fromCenter(center: Offset(targetX, targetY + 5), width: 45, height: 45), targetBoxPaint);
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'LOCK MATCH',
          style: TextStyle(color: Color(0xFFFF0000), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(targetX - 25, targetY - 32));
    }
  }

  @override
  bool shouldRepaint(covariant _PredatorPainter old) => true;

  }

// ============================================================
// WIDGET 7: Optimus Prime Transform
// ============================================================
class OptimusAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const OptimusAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<OptimusAnimation> createState() => _OptimusAnimationState();
}

class _OptimusAnimationState extends State<OptimusAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isRobot = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerTransform() {
    setState(() {
      _isRobot = !_isRobot;
      if (_isRobot) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerTransform,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _OptimusPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
        ),
      ),
    );
  }
}

class _OptimusPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  const _OptimusPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF00030C));
    final cx = size.width * 0.5 + gyroX * 18;
    final cy = size.height * 0.45 + gyroY * 18;

    final redPaint = Paint()..color = const Color(0xFFFF2200)..style = PaintingStyle.stroke..strokeWidth = 3;
    final bluePaint = Paint()..color = const Color(0xFF0055FF)..style = PaintingStyle.stroke..strokeWidth = 3;

    // Transition interpolation between truck and robot
    final truckWidth = 130.0 - (t * 50);
    final truckHeight = 70.0 + (t * 80);
    final cyOffset = cy + (1.0 - t) * 40;

    // Cabin/Chest
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cyOffset), width: truckWidth, height: truckHeight), const Radius.circular(8)),
      redPaint,
    );

    // Transforming legs (unfolding wheels/panels)
    final legW = 24.0 + (t * 12);
    final legH = 40.0 + (t * 80);
    canvas.drawRect(Rect.fromLTWH(cx - legW - 10, cyOffset + truckHeight / 2, legW, legH), bluePaint);
    canvas.drawRect(Rect.fromLTWH(cx + 10, cyOffset + truckHeight / 2, legW, legH), bluePaint);

    // Robot head emerges on transform
    if (t > 0.4) {
      final headScale = (t - 0.4) / 0.6;
      final headY = cyOffset - truckHeight / 2 - (25 * headScale);
      canvas.drawCircle(Offset(cx, headY), 16 * headScale, bluePaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, headY), width: 14 * headScale, height: 18 * headScale), redPaint);

      // Glowing optics
      final eyePaint = Paint()..color = const Color(0xFF00DFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(cx - 5, headY), 2.5, eyePaint);
      canvas.drawCircle(Offset(cx + 5, headY), 2.5, eyePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OptimusPainter old) => true;

  }

// ============================================================
// WIDGET 8: TRON Grid
// ============================================================
class TronGridAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const TronGridAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TronGridAnimation> createState() => _TronGridAnimationState();
}

class _TronGridAnimationState extends State<TronGridAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _gravityHole;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _gravityHole = details.localPosition),
      onPanEnd: (_) => setState(() => _gravityHole = null),
      onTapDown: (details) => setState(() => _gravityHole = details.localPosition),
      onTapUp: (_) => setState(() => _gravityHole = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _TronPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, gravityHole: _gravityHole),
        ),
      ),
    );
  }
}

class _TronPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? gravityHole;

  const _TronPainter({required this.t, required this.gyroX, required this.gyroY, required this.gravityHole});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF00050D));

    final horizon = size.height * 0.52 + gyroY * 18;
    final vp = Offset(size.width * 0.5 + gyroX * 18, horizon);
    final gridColor = const Color(0xFF00E5FF).withValues(alpha: 0.35);
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.8;

    // Distorted grid perspective lines
    for (int i = -8; i <= 8; i++) {
      final startX = size.width * 0.5 + (i * size.width * 0.08);
      final path = Path()..moveTo(startX, size.height);

      // Bend line toward touch point
      for (int step = 0; step <= 10; step++) {
        final ratio = step / 10;
        final px = ui.lerpDouble(startX, vp.dx, ratio)!;
        final py = ui.lerpDouble(size.height, vp.dy, ratio)!;
        double dx = 0.0;
        if (gravityHole != null) {
          final dist = (Offset(px, py) - gravityHole!).distance;
          if (dist < 120) {
            final pull = (120 - dist) * 0.25;
            dx = (gravityHole!.dx > px ? pull : -pull);
          }
          }
        path.lineTo(px + dx, py);
      }
      canvas.drawPath(path, gridPaint);
    }

    // Horizontal grid lines
    for (int j = 1; j <= 9; j++) {
      final y = horizon + (size.height - horizon) * (j / 9);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Light Cycle and trails
    final cycleProgress = t;
    final cx = size.width * (0.1 + cycleProgress * 0.8);
    final cy = size.height * 0.78;

    final trailPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawLine(Offset(cx - 70, cy), Offset(cx, cy), trailPaint);

    final bikePaint = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 16, height: 8), const Radius.circular(4)), bikePaint);
  }
  @override
  bool shouldRepaint(covariant _TronPainter old) => true;

}

// ============================================================
// WIDGET 9: Dune Sandworm
// ============================================================
class DuneSandwormAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const DuneSandwormAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<DuneSandwormAnimation> createState() => _DuneSandwormAnimationState();
}

class _DuneSandwormAnimationState extends State<DuneSandwormAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _thumperTouch;
  double _thumpProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerThumper(TapDownDetails details) {
    setState(() {
      _thumperTouch = details.localPosition;
      _thumpProgress = 1.0;
    });
    // Shrink thump ripple over time
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _thumpProgress *= 0.9;
        if (_thumpProgress < 0.05) {
          _thumpProgress = 0.0;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _triggerThumper,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _DunePainter(
            t: _ctrl.value,
            gyroX: widget.gyroX,
            gyroY: widget.gyroY,
            thumper: _thumperTouch,
            thumpScale: 1.0 - _thumpProgress,
          ),
        ),
      ),
    );
  }
}

class _DunePainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? thumper;
  final double thumpScale;

  const _DunePainter({required this.t, required this.gyroX, required this.gyroY, required this.thumper, required this.thumpScale});

  @override
  void paint(Canvas canvas, Size size) {
    // Spiced orange sky
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF1E0A00));

    // Draw Sand dunes
    final dunePaint = Paint()..color = const Color(0xFF8C5300);
    for (int d = 0; d < 4; d++) {
      final yBase = size.height * (0.6 + d * 0.08) + gyroY * 8;
      final path = Path()..moveTo(0, yBase);
      for (int x = 0; x <= 20; x++) {
        final ratio = x / 20;
        path.lineTo(size.width * ratio, yBase + sin(ratio * 3.5 + t * 2 * pi + d) * 12);
      }
        path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, dunePaint..color = const Color(0xFF8C5300).withValues(alpha: 0.4 + (d * 0.15)));
    }

    // Summon worm to thumper touch or screen center
    final wormX = thumper != null ? thumper!.dx : (size.width * 0.5 + gyroX * 22);
    final wormY = thumper != null ? thumper!.dy : (size.height * 0.65 + gyroY * 18);
    final wormScale = thumper != null ? (1.0 - thumpScale) : 0.8;

    if (wormScale > 0.1) {
      final wormPaint = Paint()..color = const Color(0xFF4C2A02);
      // Segment body
      canvas.drawOval(
        Rect.fromCenter(center: Offset(wormX, wormY), width: size.width * 0.45 * wormScale, height: size.height * 0.35 * wormScale),
        wormPaint,
      );

      // Open maw circular rings
      for (int r = 0; r < 5; r++) {
        final ringColor = const Color(0xFFFFAA00).withValues(alpha: (0.8 - r * 0.15).clamp(0.0, 1.0));
        canvas.drawOval(
          Rect.fromCenter(center: Offset(wormX, wormY - 10), width: size.width * (0.28 - r * 0.05) * wormScale, height: size.height * (0.16 - r * 0.03) * wormScale),
          Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 2.0,
        );
      }
    }
  }
  @override
  bool shouldRepaint(covariant _DunePainter old) => true;

}

// ============================================================
// WIDGET 10: Interstellar Wormhole
// ============================================================
class WormholeAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const WormholeAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<WormholeAnimation> createState() => _WormholeAnimationState();
}

class _WormholeAnimationState extends State<WormholeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _touchOffset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _touchOffset = details.localPosition),
      onPanEnd: (_) => setState(() => _touchOffset = null),
      onTapDown: (details) => setState(() => _touchOffset = details.localPosition),
      onTapUp: (_) => setState(() => _touchOffset = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _WormholePainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, touchOffset: _touchOffset),
        ),
      ),
    );
  }
}

class _WormholePainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? touchOffset;

  const _WormholePainter({required this.t, required this.gyroX, required this.gyroY, required this.touchOffset});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF01000A));

    // Centered wormhole or follows touch drag
    final cx = touchOffset != null ? touchOffset!.dx : (size.width * 0.5 + gyroX * 22);
    final cy = touchOffset != null ? touchOffset!.dy : (size.height * 0.45 + gyroY * 22);

    // Space bending concentric warped rings
    for (int i = 0; i < 22; i++) {
      final progress = t * 2 * pi - i * 0.3;
      final radius = size.width * 0.038 * (i + 1);
      final alpha = (1.0 - i / 22).clamp(0.0, 1.0) * 0.7;

      final bendPaint = Paint()
        ..color = const Color(0xFFAABBFF).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + (1.0 - i / 22) * 2;

      final path = Path();
      for (int a = 0; a <= 360; a += 5) {
        final rad = a * pi / 180;
        final wave = sin(rad * 4 + progress) * radius * 0.06;
        final rx = cx + (radius + wave) * cos(rad);
        final ry = cy + (radius + wave) * sin(rad);
        if (a == 0) {
          path.moveTo(rx, ry);
        } else {
          path.lineTo(rx, ry);
        }
        }
      path.close();
      canvas.drawPath(path, bendPaint);
    }

    // Schwarzschild singularity void
    canvas.drawCircle(
      Offset(cx, cy),
      35,
      Paint()
        ..color = Colors.black
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
  @override
  bool shouldRepaint(covariant _WormholePainter old) => true;

}

// ============================================================
// WIDGET 11: Avatar Banshee
// ============================================================
class AvatarBansheeAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const AvatarBansheeAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<AvatarBansheeAnimation> createState() => _AvatarBansheeAnimationState();
}

class _AvatarBansheeAnimationState extends State<AvatarBansheeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _lureTouch;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _lureTouch = details.localPosition),
      onPanEnd: (_) => setState(() => _lureTouch = null),
      onTapDown: (details) => setState(() => _lureTouch = details.localPosition),
      onTapUp: (_) => setState(() => _lureTouch = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _AvatarPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, lureTouch: _lureTouch),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? lureTouch;

  const _AvatarPainter({required this.t, required this.gyroX, required this.gyroY, required this.lureTouch});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000810));

    // Target tracking: fly towards finger lure or stay at center
    final destX = lureTouch != null ? lureTouch!.dx : (size.width * 0.5 + gyroX * 22);
    final destY = lureTouch != null ? lureTouch!.dy : (size.height * 0.45 + gyroY * 18 + sin(t * 2 * pi) * 15);
    final wingFlap = sin(t * 2 * pi * 2.0);

    // Bioluminescent flora glowing spores
    final seedPaint = Paint()..color = const Color(0xFF00FFCC);
    for (int i = 0; i < 24; i++) {
      final offsetMultiplier = sin(t * pi + i) * 0.5 + 0.5;
      final x = (i * size.width * 0.08) % size.width;
      final y = (i * size.height * 0.06 + t * 40) % size.height;
      canvas.drawCircle(Offset(x, y), 2.0 * offsetMultiplier, seedPaint..color = const Color(0xFF00FFCC).withValues(alpha: 0.4 * offsetMultiplier));
    }
      // Wings
    final wingPaint = Paint()
      ..color = const Color(0xFF005577).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final leftWing = Path()
      ..moveTo(destX, destY)
      ..quadraticBezierTo(destX - 60, destY - 80 - wingFlap * 15, destX - 110, destY - 20)
      ..quadraticBezierTo(destX - 50, destY + 20, destX, destY)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    final rightWing = Path()
      ..moveTo(destX, destY)
      ..quadraticBezierTo(destX + 60, destY - 80 - wingFlap * 15, destX + 110, destY - 20)
      ..quadraticBezierTo(destX + 50, destY + 20, destX, destY)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Torso/Head glow
    canvas.drawCircle(Offset(destX, destY - 8), 10, Paint()..color = const Color(0xFF00FFCC)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }
  @override
  bool shouldRepaint(covariant _AvatarPainter old) => true;

}

// ============================================================
// WIDGET 12: RoboCop HUD
// ============================================================
class RobocopHudAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const RobocopHudAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<RobocopHudAnimation> createState() => _RobocopHudAnimationState();
}

class _RobocopHudAnimationState extends State<RobocopHudAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _lockTarget;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _lockTarget = details.localPosition),
      onPanEnd: (_) => setState(() => _lockTarget = null),
      onTapDown: (details) => setState(() => _lockTarget = details.localPosition),
      onTapUp: (_) => setState(() => _lockTarget = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RobocopPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, lockTarget: _lockTarget),
        ),
      ),
    );
  }
}

class _RobocopPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? lockTarget;

  const _RobocopPainter({required this.t, required this.gyroX, required this.gyroY, required this.lockTarget});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF050000));

    final cx = size.width * 0.5 + gyroX * 22;
    final cy = size.height * 0.45 + gyroY * 22;
    final lockX = lockTarget != null ? lockTarget!.dx : cx;
    final lockY = lockTarget != null ? lockTarget!.dy : cy;

    final hudPaint = Paint()
      ..color = const Color(0xFFFF2200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Cross reticles
    canvas.drawLine(Offset(lockX - 40, lockY), Offset(lockX + 40, lockY), hudPaint);
    canvas.drawLine(Offset(lockX, lockY - 40), Offset(lockX, lockY + 40), hudPaint);
    canvas.drawCircle(Offset(lockX, lockY), 20, hudPaint);

    // Circular scanning ring
    final sweepAngle = t * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(lockX, lockY), radius: 50),
      -pi / 2, sweepAngle, false,
      hudPaint..strokeWidth = 1.5,
    );

    // Targeting text readout
    if (lockTarget != null) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'DIRECTIVE ACTIVE\nLOCK ACQUIRED',
          style: TextStyle(color: Color(0xFFFF2200), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(lockX + 25, lockY + 25));
    }
    }
  @override
  bool shouldRepaint(covariant _RobocopPainter old) => true;

}

// ============================================================
// WIDGET 13: Mandalorian Jetpack
// ============================================================
class MandalorianAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const MandalorianAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MandalorianAnimation> createState() => _MandalorianAnimationState();
}

class _MandalorianAnimationState extends State<MandalorianAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _turboActive = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _turboActive = true),
      onTapUp: (_) => setState(() => _turboActive = false),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _MandalorianPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, turbo: _turboActive),
        ),
      ),
    );
  }
}

class _MandalorianPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final bool turbo;

  const _MandalorianPainter({required this.t, required this.gyroX, required this.gyroY, required this.turbo});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020408));
    final cx = size.width * 0.5 + gyroX * 18;
    final cy = size.height * 0.42 + gyroY * 18 + sin(t * 2 * pi) * 8;

    final beskar = Paint()..color = const Color(0xFF9E9EAE)..style = PaintingStyle.stroke..strokeWidth = 2;

    // Mandalorian Helmet
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 50), width: 70, height: 80), beskar);
    // T-Visor
    final visorPath = Path()
      ..moveTo(cx - 15, cy - 65)
      ..lineTo(cx + 15, cy - 65)
      ..lineTo(cx + 15, cy - 50)
      ..lineTo(cx + 4, cy - 50)
      ..lineTo(cx + 4, cy - 25)
      ..lineTo(cx - 4, cy - 25)
      ..lineTo(cx - 4, cy - 50)
      ..lineTo(cx - 15, cy - 50)
      ..close();
    canvas.drawPath(visorPath, Paint()..color = Colors.black);

    // Shoulder plates & armor body outline
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 40), width: 110, height: 90), const Radius.circular(10)), beskar);

    // Left and Right Jetpack flames
    final flamePulse = (sin(t * 2 * pi * 4) * 0.4 + 0.6);
    final scale = turbo ? 2.5 : 1.0;
    for (int dir = -1; dir <= 1; dir += 2) {
      final fx = cx + (dir * 45);
      final fy = cy + 85;
      final flamePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF8800),
            const Color(0xFFFF2200).withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCenter(center: Offset(fx, fy), width: 30 * scale, height: 70 * scale));

      canvas.drawOval(
        Rect.fromCenter(center: Offset(fx, fy + 12), width: 14 * scale, height: (35 + flamePulse * 15) * scale),
        flamePaint,
      );
    }
    }
  @override
  bool shouldRepaint(covariant _MandalorianPainter old) => true;

}

// ============================================================
// WIDGET 14: Groot Growth
// ============================================================
class GrootAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const GrootAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<GrootAnimation> createState() => _GrootAnimationState();
}

class _GrootAnimationState extends State<GrootAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Offset> _branchPoints = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (_branchPoints.length < 50) {
          setState(() {
            _branchPoints.add(details.localPosition);
          });
        }
      },
      onDoubleTap: () => setState(() => _branchPoints.clear()),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _GrootPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, points: _branchPoints),
        ),
      ),
    );
  }
}

class _GrootPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final List<Offset> points;

  const _GrootPainter({required this.t, required this.gyroX, required this.gyroY, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF030A02));
    final cx = size.width * 0.5 + gyroX * 15;

    // Groot wood trunk
    final woodPaint = Paint()..color = const Color(0xFF5A3E1A)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(cx - 20, size.height * 0.5, cx + 20, size.height), woodPaint);

    // Growing leaves from tap path
    final leafPaint = Paint()..color = const Color(0xFF66BB6A);
    for (final pt in points) {
      canvas.drawOval(
        Rect.fromCenter(center: pt, width: 14, height: 8),
        leafPaint,
      );
      canvas.drawLine(
        pt, pt + const Offset(0, 5),
        Paint()..color = const Color(0xFF5A3E1A)..strokeWidth = 2,
      );
    }
      // Luminescent floating forest seeds
    for (int i = 0; i < 8; i++) {
      final pulse = sin(t * 2 * pi + i) * 0.5 + 0.5;
      final sy = size.height * 0.4 + sin(t * 2 * pi) * 20;
      canvas.drawCircle(Offset(cx - 60 + i * 20, sy - i * 10), 3 * pulse, Paint()..color = const Color(0xFF90FF17).withValues(alpha: 0.6 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }
  @override
  bool shouldRepaint(covariant _GrootPainter old) => true;

}

// ============================================================
// WIDGET 15: Combat Exosuit
// ============================================================
class ExosuitAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const ExosuitAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<ExosuitAnimation> createState() => _ExosuitAnimationState();
}

class _ExosuitAnimationState extends State<ExosuitAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _shieldActive = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _shieldActive = true),
      onTapUp: (_) => setState(() => _shieldActive = false),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _ExosuitPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, shield: _shieldActive),
        ),
      ),
    );
  }
}

class _ExosuitPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final bool shield;

  const _ExosuitPainter({required this.t, required this.gyroX, required this.gyroY, required this.shield});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020704));
    final cx = size.width * 0.5 + gyroX * 18;
    final cy = size.height * 0.45 + gyroY * 18;

    final framePaint = Paint()
      ..color = const Color(0xFF2C5E3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Heavy Mech Frame
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 100, height: 130), framePaint);
    canvas.drawCircle(Offset(cx, cy - 85), 18, framePaint); // Helmet cage

    // Core powerup engine
    final glowVal = sin(t * 2 * pi) * 0.3 + 0.7;
    canvas.drawCircle(
      Offset(cx, cy),
      14,
      Paint()
        ..color = const Color(0xFF00FF66).withValues(alpha: glowVal * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Glowing protective energy grid
    if (shield) {
      final shieldPaint = Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(cx, cy), size.width * 0.38, shieldPaint);
      canvas.drawCircle(
        Offset(cx, cy),
        size.width * 0.38,
        Paint()
          ..color = const Color(0xFF00FF88).withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    }
  @override
  bool shouldRepaint(covariant _ExosuitPainter old) => true;

}

// ============================================================
// WIDGET 16: Mad Max Fury Road
// ============================================================
class MadMaxAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const MadMaxAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MadMaxAnimation> createState() => _MadMaxAnimationState();
}

class _MadMaxAnimationState extends State<MadMaxAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Offset> _fireTread = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (_fireTread.length < 40) {
          setState(() {
            _fireTread.add(details.localPosition);
          });
        }
      },
      onDoubleTap: () => setState(() => _fireTread.clear()),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _MadMaxPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, treads: _fireTread),
        ),
      ),
    );
  }
}

class _MadMaxPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final List<Offset> treads;

  const _MadMaxPainter({required this.t, required this.gyroX, required this.gyroY, required this.treads});

  @override
  void paint(Canvas canvas, Size size) {
    // Apocalyptic red wasteland sky
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF280700));

    // Flame drag treads
    final firePaint = Paint()
      ..color = const Color(0xFFFF5500)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (final td in treads) {
      canvas.drawCircle(td, 16, firePaint);
      canvas.drawCircle(td, 8, Paint()..color = const Color(0xFFFFCC00));
    }
      // War rig structure moving across Wasteland
    final rigX = (t * size.width * 1.3) - size.width * 0.2 + gyroX * 22;
    final rigY = size.height * 0.65 + gyroY * 12;

    final rigPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawRect(Rect.fromLTWH(rigX, rigY, size.width * 0.35, 45), rigPaint);
    canvas.drawCircle(Offset(rigX + 25, rigY + 45), 14, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(rigX + size.width * 0.25, rigY + 45), 14, Paint()..color = Colors.black);
  }
  @override
  bool shouldRepaint(covariant _MadMaxPainter old) => true;

}

// ============================================================
// WIDGET 17: Fifth Element Multipass
// ============================================================
class MultipassAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const MultipassAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MultipassAnimation> createState() => _MultipassAnimationState();
}

class _MultipassAnimationState extends State<MultipassAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _swipeAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) => setState(() {
        _swipeAngle += details.primaryDelta! * 0.015;
      }),
      onDoubleTap: () => setState(() => _swipeAngle = 0.0),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _MultipassPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, swipeAngle: _swipeAngle),
        ),
      ),
    );
  }
}

class _MultipassPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final double swipeAngle;

  const _MultipassPainter({required this.t, required this.gyroX, required this.gyroY, required this.swipeAngle});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF07000F));

    final cx = size.width * 0.5 + gyroX * 22;
    final cy = size.height * 0.45 + gyroY * 18;

    canvas.save();
    canvas.translate(cx, cy);
    // Apply 3D perspective swipe rotation
    canvas.rotate(swipeAngle);

    final cardRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size.width * 0.7, height: size.height * 0.22),
      const Radius.circular(16),
    );

    // Glowing futuristic ID Card
    canvas.drawRRect(cardRRect, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF2A003E), Color(0xFF5C006B), Color(0xFF1E002B)],
    ).createShader(Rect.fromCenter(center: Offset.zero, width: size.width * 0.7, height: size.height * 0.22)));

    // Card Borders and chip
    canvas.drawRRect(cardRRect, Paint()..color = const Color(0xFFFF2288).withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawRect(Rect.fromCenter(center: Offset(-size.width * 0.22, 0), width: 30, height: 25), Paint()..color = const Color(0xFFFFD700));

    // Multi-pass holographic data barcode
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(-20, -25.0 + i * 15),
        Offset(60, -25.0 + i * 15),
        Paint()..color = const Color(0xFFFF2288)..strokeWidth = 3,
      );
    }
      canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _MultipassPainter old) => true;

}

// ============================================================
// WIDGET 18: Blade Runner Spinner
// ============================================================
class BladeRunnerAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const BladeRunnerAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<BladeRunnerAnimation> createState() => _BladeRunnerAnimationState();
}

class _BladeRunnerAnimationState extends State<BladeRunnerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset? _pilotTouch;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _pilotTouch = details.localPosition),
      onPanEnd: (_) => setState(() => _pilotTouch = null),
      onTapDown: (details) => setState(() => _pilotTouch = details.localPosition),
      onTapUp: (_) => setState(() => _pilotTouch = null),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _BladeRunnerPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, pilotTouch: _pilotTouch),
        ),
      ),
    );
  }
}

class _BladeRunnerPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final Offset? pilotTouch;

  const _BladeRunnerPainter({required this.t, required this.gyroX, required this.gyroY, required this.pilotTouch});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF03020A));

    // Skyscrapers
    final skyPaint = Paint()..color = const Color(0xFF060515);
    for (int i = 0; i < 10; i++) {
      final x = i * size.width / 10;
      final h = size.height * (0.2 + (i % 3) * 0.1);
      canvas.drawRect(Rect.fromLTRB(x + 2, size.height - h, x + size.width / 10 - 2, size.height), skyPaint);
    }
      // Heavy rain
    for (int r = 0; r < 20; r++) {
      final rx = (r * size.width / 20 + t * 40) % size.width;
      final ry = (r * 30 + t * size.height) % size.height;
      canvas.drawLine(Offset(rx, ry), Offset(rx - 3, ry + 15), Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.15));
    }

    // Spinner follows pilotTouch or flies in path
    final sx = pilotTouch != null ? pilotTouch!.dx : (size.width * 0.5 + sin(t * 2 * pi) * 110 + gyroX * 22);
    final sy = pilotTouch != null ? pilotTouch!.dy : (size.height * 0.38 + cos(t * 2 * pi) * 50 + gyroY * 18);

    // Headlights
    canvas.drawCircle(Offset(sx, sy), 18, Paint()..color = const Color(0xFF00CFFF).withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Spinner frame
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx, sy), width: 34, height: 14), const Radius.circular(4)), Paint()..color = const Color(0xFF222233));
  }
  @override
  bool shouldRepaint(covariant _BladeRunnerPainter old) => true;

}

// ============================================================
// WIDGET 19: District 9 Mech
// ============================================================
class District9Animation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const District9Animation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<District9Animation> createState() => _District9AnimationState();
}

class _District9AnimationState extends State<District9Animation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _laserFired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _laserFired = true),
      onTapUp: (_) => setState(() => _laserFired = false),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _District9Painter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, fire: _laserFired),
        ),
      ),
    );
  }
}

class _District9Painter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final bool fire;

  const _District9Painter({required this.t, required this.gyroX, required this.gyroY, required this.fire});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF030501));
    final cx = size.width * 0.5 + gyroX * 22;
    final cy = size.height * 0.45 + gyroY * 22;

    final alienArmor = Paint()..color = const Color(0xFF88AA00)..style = PaintingStyle.stroke..strokeWidth = 2.5;

    // Mech chassis
    canvas.drawCircle(Offset(cx, cy - 30), 25, alienArmor);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + 30), width: 70, height: 75), alienArmor);

    // Bio-weapon blast
    if (fire) {
      final blastPaint = Paint()
        ..color = const Color(0xFF88FF00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(Offset(cx, cy + 20), size.width * 0.35, blastPaint);
      canvas.drawCircle(Offset(cx, cy + 20), size.width * 0.15, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _District9Painter old) => true;

}

// ============================================================
// WIDGET 20: Interstellar Tesseract
// ============================================================
class TesseractAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const TesseractAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TesseractAnimation> createState() => _TesseractAnimationState();
}

class _TesseractAnimationState extends State<TesseractAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _swipeY = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) => setState(() {
        _swipeY += details.primaryDelta! * 0.5;
      }),
      onDoubleTap: () => setState(() => _swipeY = 0.0),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _TesseractPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY, swipeY: _swipeY),
        ),
      ),
    );
  }
}

class _TesseractPainter extends CustomPainter {
  final double t;
  final double gyroX;
  final double gyroY;
  final double swipeY;

  const _TesseractPainter({required this.t, required this.gyroX, required this.gyroY, required this.swipeY});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF030200));

    final oy = gyroY * 20 + swipeY;

    // Bookshelf dimensions grid
    for (int k = 0; k < 6; k++) {
      final y = size.height * (k / 6) + (oy % (size.height / 6));
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = const Color(0xFFFFAA33).withValues(alpha: 0.25)..strokeWidth = 1.5,
      );

      // Radial spacetime library lines
      for (int i = 0; i < 8; i++) {
        final bookX = (i * size.width * 0.14 + t * 40) % size.width;
        canvas.drawRect(
          Rect.fromLTWH(bookX, y - 18, 8, 18),
          Paint()..color = const Color(0xFFB37424).withValues(alpha: 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TesseractPainter old) => true;

}

// ============================================================
// WIDGET 21: Warship Beam Cannon — 3D Dreadnought & Superlaser
// ============================================================
class WarshipBeamAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const WarshipBeamAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<WarshipBeamAnimation> createState() => _WarshipBeamAnimationState();
}

class _WarshipBeamAnimationState extends State<WarshipBeamAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _fireCtrl;
  Offset? _touchPos;
  bool _firing = false;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _fireCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _fireCtrl.dispose();
    super.dispose();
  }

  void _triggerFireSound() {
    GameSoundService().playSuperLaser();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        if (!_firing) _triggerFireSound();
        setState(() { _touchPos = d.localPosition; _firing = true; });
      },
      onPanEnd: (_) => setState(() { _firing = false; }),
      onTapDown: (d) {
        _triggerFireSound();
        setState(() { _touchPos = d.localPosition; _firing = true; });
      },
      onTapUp: (_) => setState(() { _firing = false; }),
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _fireCtrl]),
        builder: (_, __) => Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(widget.gyroY * 0.15)
            ..rotateY(-widget.gyroX * 0.15),
          alignment: Alignment.center,
          child: CustomPaint(
            painter: _WarshipBeamPainter(
              t: _mainCtrl.value,
              fireT: _fireCtrl.value,
              gyroX: widget.gyroX,
              gyroY: widget.gyroY,
              touchPos: _touchPos,
              firing: _firing,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarshipBeamPainter extends CustomPainter {
  final double t;
  final double fireT;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;
  final bool firing;

  const _WarshipBeamPainter({
    required this.t,
    required this.fireT,
    required this.gyroX,
    required this.gyroY,
    required this.touchPos,
    required this.firing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42 + (t * 100).toInt());

    // Deep cosmic space background with deep blue/purple nebula
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.2 + gyroX * 0.1, -0.3 + gyroY * 0.1),
        radius: 1.4,
        colors: const [
          Color(0xFF0C1028),
          Color(0xFF050816),
          Color(0xFF01020A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 3D Parallax Starfield with depth tiers
    for (int tier = 1; tier <= 3; tier++) {
      final tierSpeed = tier * 6.0;
      final starPaint = Paint();
      for (int i = 0; i < 40; i++) {
        final rngS = Random(tier * 1000 + i * 31);
        final sx = (rngS.nextDouble() * size.width + gyroX * tierSpeed) % size.width;
        final sy = (rngS.nextDouble() * size.height + gyroY * (tierSpeed * 0.6)) % size.height;
        final br = rngS.nextDouble();
        final radius = (tier * 0.6) + br * 0.8;
        final col = tier == 3
            ? const Color(0xFF99DDFF)
            : (tier == 2 ? const Color(0xFFFFFFFF) : const Color(0xFF8888CC));
        starPaint.color = col.withValues(alpha: 0.3 + br * 0.7);
        canvas.drawCircle(Offset(sx, sy), radius, starPaint);
      }
    }

    // Distant volumetric nebula clouds
    final nebulaPaint = Paint()
      ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    canvas.drawCircle(Offset(size.width * 0.8 + gyroX * 10, size.height * 0.25 + gyroY * 8), 190, nebulaPaint);
    nebulaPaint.color = const Color(0xFF9333EA).withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.2 + gyroX * 8, size.height * 0.65 + gyroY * 6), 160, nebulaPaint);

    final cx = size.width * 0.5 + gyroX * 18;
    final cy = size.height * 0.45 + gyroY * 14;

    // ===== 3D ENEMY DREADNOUGHT (Top Right) =====
    final enemyX = size.width * 0.76 + gyroX * 10;
    final enemyY = size.height * 0.18 + gyroY * 6 + sin(t * 2 * pi) * 6;
    _draw3DDreadnought(canvas, Offset(enemyX, enemyY), 0.65, const Color(0xFFFF2A4B), isEnemy: true);

    // ===== 3D PLAYER CAPITAL BATTLECRUISER (Center Left) =====
    final playerX = cx - size.width * 0.22;
    final playerY = cy + 20;
    _draw3DDreadnought(canvas, Offset(playerX, playerY), 0.95, const Color(0xFF00E5FF), isEnemy: false);

    // ===== SUPERLASER BEAM & VOLUMETRIC PLASMA RAY =====
    final beamPulse = (sin(fireT * 2 * pi) * 0.5 + 0.5);
    final beamStart = Offset(playerX + 68, playerY - 4);
    final beamEnd = touchPos ?? Offset(enemyX - 25, enemyY);

    // 1. Plasma condenser arcs charging at cannon emitter
    for (int arc = 0; arc < 4; arc++) {
      final arcAngle = (fireT * 2 * pi * 3.0) + (arc * pi / 2);
      final arcR = 14.0 + (1 - beamPulse) * 12.0;
      final arcX = beamStart.dx + cos(arcAngle) * arcR;
      final arcY = beamStart.dy + sin(arcAngle) * (arcR * 0.6);
      canvas.drawLine(
        Offset(arcX, arcY),
        beamStart,
        Paint()
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.7)
          ..strokeWidth = 1.8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // 2. High-energy emitter bloom core
    canvas.drawCircle(
      beamStart,
      14 + beamPulse * 10,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 + beamPulse * 10),
    );
    canvas.drawCircle(beamStart, 6 + beamPulse * 3, Paint()..color = Colors.white);

    // 3. Wide volumetric laser halo with chromatic dispersion
    canvas.drawLine(
      beamStart,
      beamEnd,
      Paint()
        ..color = const Color(0xFF0077FF).withValues(alpha: 0.35 + beamPulse * 0.25)
        ..strokeWidth = 24 + beamPulse * 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawLine(
      beamStart,
      beamEnd,
      Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.7 + beamPulse * 0.3)
        ..strokeWidth = 10 + beamPulse * 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Pure white searing plasma beam core
    canvas.drawLine(
      beamStart,
      beamEnd,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3.5 + beamPulse * 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 4. Helical magnetic containment particle coils rotating along beam
    for (int i = 0; i < 9; i++) {
      final p = ((fireT * 1.5 + i * 0.11) % 1.0);
      final helixPhase = p * 8 * pi;
      final basePos = Offset.lerp(beamStart, beamEnd, p)!;
      final helixOffset = Offset(
        -sin(helixPhase) * 6,
        cos(helixPhase) * 10,
      );
      canvas.drawCircle(
        basePos + helixOffset,
        3.5 + (1 - p) * 3,
        Paint()
          ..color = const Color(0xFFE0FFFF).withValues(alpha: (1 - p) * 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // 5. Epic Deflector Shield & Plasma Impact Explosion at beamEnd
    final impactPulse = (sin(fireT * 2 * pi * 2) * 0.5 + 0.5);
    final impactPaint = Paint()
      ..color = const Color(0xFFFF9900).withValues(alpha: 0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 + impactPulse * 16);
    canvas.drawCircle(beamEnd, 22 + impactPulse * 16, impactPaint);
    canvas.drawCircle(
      beamEnd,
      10,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Dynamic 3D Shield Deflection Grid
    final shieldPaint = Paint()
      ..color = const Color(0xFFFF3366).withValues(alpha: 0.6 + beamPulse * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(enemyX, enemyY), width: 110, height: 65),
      shieldPaint,
    );

    // 3D Expanding Shockwave Rings from Impact
    for (int ring = 0; ring < 3; ring++) {
      final ringP = ((fireT * 1.8 + ring * 0.33) % 1.0);
      canvas.drawCircle(
        beamEnd,
        ringP * 50,
        Paint()
          ..color = const Color(0xFFFFB703).withValues(alpha: (1 - ringP) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - ringP) * 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // High-speed spark debris particles in 3D fan
    for (int i = 0; i < 14; i++) {
      final da = (i / 14.0) * 2 * pi + t * pi;
      final dist = 18 + rng.nextDouble() * 38;
      final px = beamEnd.dx + cos(da) * dist;
      final py = beamEnd.dy + sin(da) * dist * 0.7;
      canvas.drawCircle(
        Offset(px, py),
        2.2,
        Paint()..color = const Color(0xFFFFD166).withValues(alpha: 0.85),
      );
    }

    // 6. Futuristic 3D Cyber Tactical HUD Target Lock
    final tgt = touchPos ?? Offset(enemyX, enemyY);
    _draw3DHudTarget(canvas, tgt, t);

    // HUD Text Status
    final hudTp = TextPainter(
      text: const TextSpan(
        text: '3D SUPERLASER LOCK · DESTRUCTION MATRIX ENGAGED',
        style: TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hudTp.paint(canvas, Offset(size.width * 0.05, size.height * 0.06));

    final specTp = TextPainter(
      text: TextSpan(
        text: 'OUTPUT: ${(780 + beamPulse * 220).toStringAsFixed(0)} TERAWATTS  |  TARGET INTEGRITY: 24%',
        style: const TextStyle(
          color: Color(0xFF88CCFF),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    specTp.paint(canvas, Offset(size.width * 0.05, size.height * 0.91));
  }

  void _draw3DDreadnought(Canvas canvas, Offset center, double scale, Color col, {required bool isEnemy}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isEnemy) {
      canvas.scale(-scale, scale);
    } else {
      canvas.scale(scale, scale);
    }

    // Shaded 3D Upper Hull
    final upperHullPath = Path()
      ..moveTo(75, 0)
      ..lineTo(25, -20)
      ..lineTo(-55, -16)
      ..lineTo(-70, 0)
      ..lineTo(25, -5)
      ..close();
    canvas.drawPath(
      upperHullPath,
      Paint()..color = col.withValues(alpha: 0.95),
    );

    // Shaded 3D Lower Hull (Darker ambient shadow)
    final lowerHullPath = Path()
      ..moveTo(75, 0)
      ..lineTo(25, -5)
      ..lineTo(-70, 0)
      ..lineTo(-55, 18)
      ..lineTo(25, 22)
      ..close();
    canvas.drawPath(
      lowerHullPath,
      Paint()..color = Color.lerp(col, Colors.black, 0.45)!.withValues(alpha: 0.95),
    );

    // Metallic Hull Panel Grid Lines
    final panelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(upperHullPath, panelPaint);
    canvas.drawPath(lowerHullPath, panelPaint);

    // Superstructure Command Bridge Tower (3D elevated block)
    final bridgePath = Path()
      ..moveTo(-5, -12)
      ..lineTo(15, -12)
      ..lineTo(10, -26)
      ..lineTo(-10, -26)
      ..close();
    canvas.drawPath(
      bridgePath,
      Paint()..color = col.withValues(alpha: 0.85),
    );
    canvas.drawPath(bridgePath, panelPaint);
    // Glowing bridge window visor
    canvas.drawLine(
      const Offset(-7, -20),
      const Offset(8, -20),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Heavy Ion Engine Nacelles & Radiant Thrust Flame
    final nacellePaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-68, -28, 36, 12), const Radius.circular(3)), nacellePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-68, 16, 36, 12), const Radius.circular(3)), nacellePaint);

    // Engine Plasma Exhaust Glow
    final exhaustGlow = Paint()
      ..color = col
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(const Offset(-68, -22), 8, exhaustGlow);
    canvas.drawCircle(const Offset(-68, 22), 8, exhaustGlow);
    canvas.drawCircle(const Offset(-68, -22), 4, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(-68, 22), 4, Paint()..color = Colors.white);

    // Heavy Railgun Cannon Barrels
    final cannonPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(45, -2), const Offset(78, -2), cannonPaint);

    canvas.restore();
  }

  void _draw3DHudTarget(Canvas canvas, Offset tgt, double t) {
    final rot = t * 2 * pi;
    final hudPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.save();
    canvas.translate(tgt.dx, tgt.dy);
    canvas.rotate(rot);

    // Rotating dashed reticle ring
    canvas.drawCircle(Offset.zero, 28, hudPaint);
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(
        Offset(cos(a) * 32, sin(a) * 32),
        Offset(cos(a) * 44, sin(a) * 44),
        hudPaint..strokeWidth = 2.0,
      );
    }
    canvas.restore();

    // Corner targeting brackets
    const bSize = 14.0;
    const bDist = 38.0;
    final bPaint = Paint()
      ..color = const Color(0xFFFF2A4B).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Top-Left
    canvas.drawLine(Offset(tgt.dx - bDist, tgt.dy - bDist), Offset(tgt.dx - bDist + bSize, tgt.dy - bDist), bPaint);
    canvas.drawLine(Offset(tgt.dx - bDist, tgt.dy - bDist), Offset(tgt.dx - bDist, tgt.dy - bDist + bSize), bPaint);
    // Top-Right
    canvas.drawLine(Offset(tgt.dx + bDist, tgt.dy - bDist), Offset(tgt.dx + bDist - bSize, tgt.dy - bDist), bPaint);
    canvas.drawLine(Offset(tgt.dx + bDist, tgt.dy - bDist), Offset(tgt.dx + bDist, tgt.dy - bDist + bSize), bPaint);
    // Bottom-Left
    canvas.drawLine(Offset(tgt.dx - bDist, tgt.dy + bDist), Offset(tgt.dx - bDist + bSize, tgt.dy + bDist), bPaint);
    canvas.drawLine(Offset(tgt.dx - bDist, tgt.dy + bDist), Offset(tgt.dx - bDist, tgt.dy + bDist - bSize), bPaint);
    // Bottom-Right
    canvas.drawLine(Offset(tgt.dx + bDist, tgt.dy + bDist), Offset(tgt.dx + bDist - bSize, tgt.dy + bDist), bPaint);
    canvas.drawLine(Offset(tgt.dx + bDist, tgt.dy + bDist), Offset(tgt.dx + bDist, tgt.dy + bDist - bSize), bPaint);
  }

  @override
  bool shouldRepaint(covariant _WarshipBeamPainter old) => true;
}

// ============================================================
// WIDGET 22: Shooting Stars — 3D Meteorite & Cosmic Firestorm (7 Stages)
// ============================================================
class ShootingStarsAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const ShootingStarsAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<ShootingStarsAnimation> createState() => _ShootingStarsAnimationState();
}

class _ShootingStarsAnimationState extends State<ShootingStarsAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _twinkleCtrl;
  Offset? _touchPos;
  int _lastSoundStage = -1;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 42))..repeat();
    _twinkleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _twinkleCtrl.dispose();
    super.dispose();
  }

  void _checkStageSound(int stageIdx) {
    if (stageIdx != _lastSoundStage) {
      _lastSoundStage = stageIdx;
      if (stageIdx == 1 || stageIdx == 2 || stageIdx == 3) {
        GameSoundService().playShootingStar();
      } else if (stageIdx == 4) {
        GameSoundService().playSuperLaser();
      } else if (stageIdx == 5) {
        GameSoundService().playExplosion();
      } else if (stageIdx == 6) {
        GameSoundService().playHyperspace();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        GameSoundService().playShootingStar();
        setState(() => _touchPos = d.localPosition);
      },
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (d) {
        GameSoundService().playShootingStar();
        setState(() => _touchPos = d.localPosition);
      },
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _twinkleCtrl]),
        builder: (_, __) {
          final stageF = _mainCtrl.value * 7;
          final stageIdx = stageF.floor().clamp(0, 6);
          _checkStageSound(stageIdx);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(widget.gyroY * 0.12)
              ..rotateY(-widget.gyroX * 0.12),
            alignment: Alignment.center,
            child: CustomPaint(
              painter: _ShootingStarsPainter(
                t: _mainCtrl.value,
                twinkle: _twinkleCtrl.value,
                gyroX: widget.gyroX,
                gyroY: widget.gyroY,
                touchPos: _touchPos,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShootingStarsPainter extends CustomPainter {
  final double t;
  final double twinkle;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _ShootingStarsPainter({
    required this.t,
    required this.twinkle,
    required this.gyroX,
    required this.gyroY,
    required this.touchPos,
  });

  static const int _stages = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final stageF = t * _stages;
    final stageIdx = stageF.floor().clamp(0, _stages - 1);
    final localT = stageF - stageIdx;
    final cx = size.width * 0.5 + gyroX * 16;
    final cy = size.height * 0.5 + gyroY * 12;
    final fadeAlpha = localT < 0.12 ? localT / 0.12 : (localT > 0.88 ? (1 - localT) / 0.12 : 1.0);

    switch (stageIdx) {
      case 0: _drawCalmStarfield(canvas, size, cx, cy, localT);
      case 1: _drawFirstShooters(canvas, size, cx, cy, localT);
      case 2: _drawMeteorShower(canvas, size, cx, cy, localT);
      case 3: _drawLargeMeteors(canvas, size, cx, cy, localT);
      case 4: _drawAtmosphereEntry(canvas, size, cx, cy, localT);
      case 5: _drawImpacts(canvas, size, cx, cy, localT);
      case 6: _drawDebrisNebula(canvas, size, cx, cy, localT);
    }

    // Interactive meteor strike on tap
    if (touchPos != null) {
      _drawInteractiveMeteor(canvas, size, touchPos!);
    }

    // Stage labels
    final stageLabels = [
      'CALM STARFIELD 3D',
      'FIRST SHOOTING STARS',
      'METEOR SHOWER 3D',
      'INCANDESCENT METEORS',
      'ATMOSPHERIC RE-ENTRY',
      'HYPER-VELOCITY IMPACTS',
      'DEBRIS NEBULA & GAS',
    ];
    final subLabels = [
      '3D DEPTH SCANNING · GYRO ACTIVE',
      'SPORADIC IONIZATION DETECTED',
      'SUPERSONIC METEOR STORM IN PROGRESS',
      'THERMAL ABLATION · 4000 KELVIN',
      'ATMOSPHERIC FRICTION SHOCK CONES',
      'CRATER BLAST WAVES DETECTED',
      'EXPANDING HIGH-ENERGY PARTICLES',
    ];

    final lp = TextPainter(
      text: TextSpan(
        text: stageLabels[stageIdx],
        style: TextStyle(
          color: Colors.white.withValues(alpha: fadeAlpha * 0.95),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.8,
          fontFamily: 'monospace',
          shadows: const [Shadow(color: Color(0xFF00E5FF), blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(cx - lp.width / 2, size.height * 0.85));

    final sp = TextPainter(
      text: TextSpan(
        text: subLabels[stageIdx],
        style: TextStyle(
          color: const Color(0xFFB44FFF).withValues(alpha: fadeAlpha * 0.8),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sp.paint(canvas, Offset(cx - sp.width / 2, size.height * 0.905));

    // Progress bar & Dots
    final bw = size.width * 0.55;
    final bx = cx - bw / 2;
    final by = size.height * 0.935;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, 2.5), const Radius.circular(2)), Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw * t, 2.5), const Radius.circular(2)),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    final dotY = size.height * 0.96;
    const dotSpacing = 18.0;
    final dotsStart = cx - (_stages - 1) * dotSpacing / 2;
    for (int i = 0; i < _stages; i++) {
      final active = i == stageIdx;
      canvas.drawCircle(
        Offset(dotsStart + i * dotSpacing, dotY),
        active ? 4.5 : 2.5,
        Paint()
          ..color = active ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.2)
          ..maskFilter = active ? const MaskFilter.blur(BlurStyle.normal, 4) : null,
      );
    }
  }

  void _drawInteractiveMeteor(Canvas canvas, Size size, Offset target) {
    final start = Offset(target.dx - 120, target.dy - 200);
    _draw3DFireMeteor(canvas, start, target, 12, 1.0);
  }

  // ── STAGE 0: Calm 3D Deep Space Starfield ──
  void _drawCalmStarfield(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF02020D));

    // 3D Parallax Star Layers
    for (int layer = 1; layer <= 3; layer++) {
      final speed = layer * 4.0;
      final rng = Random(layer * 999);
      for (int i = 0; i < 60; i++) {
        final sx = (rng.nextDouble() * size.width + gyroX * speed) % size.width;
        final sy = (rng.nextDouble() * size.height + gyroY * speed * 0.7) % size.height;
        final br = rng.nextDouble();
        final tw = (i % 4 == 0) ? (twinkle * 0.3) : 0.0;
        final alpha = (0.3 + br * 0.5 + tw).clamp(0.0, 1.0);
        final col = layer == 3
            ? const Color(0xFF99EEFF)
            : (layer == 2 ? Colors.white : const Color(0xFF8888BB));
        canvas.drawCircle(
          Offset(sx, sy),
          (layer * 0.5) + br * 0.8,
          Paint()..color = col.withValues(alpha: alpha),
        );
      }
    }

    // Glowing Galactic Milky Way Dust Band
    final bandPaint = Paint()
      ..color = const Color(0xFF4C1D95).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: size.width * 1.2, height: size.height * 0.35), bandPaint);
    _hudLabel(canvas, size, 'STARWATCH 3D · DEEP SPACE ACTIVE', const Color(0xFF00E5FF));
  }

  // ── STAGE 1: First Shooting Stars ──
  void _drawFirstShooters(Canvas canvas, Size size, double cx, double cy, double t) {
    _drawCalmStarfield(canvas, size, cx, cy, t);
    final rng = Random(22222);
    for (int i = 0; i < 5; i++) {
      final phase = (t * 1.2 + i * 0.20) % 1.0;
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height * 0.5;
      final angle = pi / 4 + rng.nextDouble() * 0.25;
      final len = 120.0 + rng.nextDouble() * 100;
      final ex = sx + cos(angle) * len * phase;
      final ey = sy + sin(angle) * len * phase;
      _draw3DShootingTrail(canvas, Offset(sx, sy), Offset(ex, ey), const Color(0xFF00E5FF), (1 - phase));
    }
    _hudLabel(canvas, size, 'SPORADIC SHOOTING STARS DETECTED', const Color(0xFFB44FFF));
  }

  // ── STAGE 2: 3D Meteor Shower Radiant ──
  void _drawMeteorShower(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF02020A));
    _staticStars(canvas, size, 120, 33333);

    final radiantX = cx * 0.7;
    final radiantY = size.height * 0.18;

    // Glowing Radiant Origin Point
    canvas.drawCircle(
      Offset(radiantX, radiantY),
      18 + twinkle * 8,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // 20 Meteor Streaks Bursting Radially with 3D Depth
    final rng = Random(44444);
    for (int i = 0; i < 20; i++) {
      final offset = (t * 1.8 + i / 20.0) % 1.0;
      final zDepth = (i % 3 + 1); // 1 = far, 3 = close
      final spreadAngle = -pi / 2 + (i - 10) * 0.16 + (rng.nextDouble() - 0.5) * 0.1;
      final speed = (0.7 + rng.nextDouble() * 0.5) * zDepth;
      final dist = offset * size.height * speed * 0.8;
      final ex = radiantX + cos(spreadAngle) * dist;
      final ey = radiantY + sin(spreadAngle) * dist;
      final trailLen = (70.0 + rng.nextDouble() * 80) * (zDepth * 0.6);
      final sx = ex - cos(spreadAngle) * trailLen;
      final sy = ey - sin(spreadAngle) * trailLen;

      final col = [const Color(0xFF00E5FF), const Color(0xFFFFD700), Colors.white, const Color(0xFFFF5599)][i % 4];
      _draw3DShootingTrail(canvas, Offset(sx, sy), Offset(ex, ey), col, (1 - offset * 0.4) * (zDepth / 3));
    }
    _hudLabel(canvas, size, 'METEOR STORM · RADIANT POINT ACTIVE', const Color(0xFF00E5FF));
  }

  // ── STAGE 3: Large Incandescent Meteors ──
  void _drawLargeMeteors(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF05020A));
    _staticStars(canvas, size, 90, 55555);

    final rng = Random(66666);
    for (int i = 0; i < 5; i++) {
      final phase = (t * 0.85 + i * 0.20) % 1.0;
      final startX = rng.nextDouble() * size.width * 1.2 - size.width * 0.1;
      final endX = startX + size.width * 0.45;
      final startY = -40.0;
      final endY = size.height * (0.6 + rng.nextDouble() * 0.4);
      final px = startX + (endX - startX) * phase;
      final py = startY + (endY - startY) * phase;
      final angle = atan2(endY - startY, endX - startX);
      final trailLen = 160.0 + rng.nextDouble() * 90;
      final tx = px - cos(angle) * trailLen;
      final ty = py - sin(angle) * trailLen;

      _draw3DFireMeteor(canvas, Offset(tx, ty), Offset(px, py), 8.0 + (i % 3) * 3, 1.0);
    }
    _hudLabel(canvas, size, 'INCANDESCENT METEORITES INBOUND · 4000 K', const Color(0xFFFF9900));
  }

  // ── STAGE 4: Atmospheric Re-Entry Fireballs ──
  void _drawAtmosphereEntry(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF06030A));

    // Upper Atmospheric Ozone & Thermosphere Glow
    final atmPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E3A8A).withValues(alpha: 0.5),
          const Color(0xFF9333EA).withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.45), atmPaint);

    _staticStars(canvas, size, 70, 77777);
    final rng = Random(88888);

    for (int i = 0; i < 4; i++) {
      final phase = (t * 0.75 + i * 0.25) % 1.0;
      final sx = size.width * (0.15 + i * 0.24);
      final sy = -30.0;
      final ex = sx + size.width * 0.14;
      final ey = size.height * 0.85 * phase;

      // Atmospheric Shockwave Cone (Supersonic Bow Shock)
      final shockAlpha = phase * 0.8;
      final shockPaint = Paint()
        ..color = const Color(0xFFFF5500).withValues(alpha: shockAlpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(ex, ey), 32 * phase, shockPaint);

      // Heavy 3D Fire Meteor with plasma core
      _draw3DFireMeteor(canvas, Offset(sx, sy), Offset(ex, ey), 10.0 + rng.nextDouble() * 5, phase);

      // Breaking fragment sparks
      if (phase > 0.45) {
        final fragP = phase - 0.45;
        for (int f = 0; f < 4; f++) {
          final fa = f * pi / 2 + pi / 4;
          final fx = ex + cos(fa) * fragP * 50;
          final fy = ey + sin(fa) * fragP * 40;
          canvas.drawCircle(
            Offset(fx, fy),
            3.0,
            Paint()
              ..color = const Color(0xFFFFCC00).withValues(alpha: (1 - fragP * 1.8).clamp(0.0, 1.0))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }
    _hudLabel(canvas, size, 'ATMOSPHERIC RE-ENTRY · SUPERSONIC BOW SHOCK', const Color(0xFFFF4400));
  }

  // ── STAGE 5: Ground Impact Explosions ──
  void _drawImpacts(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF080204));

    // Dark Earth Horizon
    final horizonY = size.height * 0.72;
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, size.height * 0.28),
      Paint()..color = const Color(0xFF160A06),
    );

    _staticStars(canvas, size, 50, 99999);
    final rng = Random(12345);

    for (int i = 0; i < 4; i++) {
      final impactPhase = ((t * 1.3 + i * 0.25) % 1.0);
      final ix = size.width * (0.16 + i * 0.24);
      final iy = horizonY;

      if (impactPhase < 0.35) {
        // Incoming falling bolide
        final py = iy * impactPhase / 0.35;
        _draw3DFireMeteor(canvas, Offset(ix - 15, 0), Offset(ix, py), 9, 1.0);
      } else {
        // High-Energy Impact Detonation Bloom
        final ep = (impactPhase - 0.35) / 0.65;
        final expR = ep * 75;

        // Volumetric fireball glow
        canvas.drawCircle(
          Offset(ix, iy),
          expR,
          Paint()
            ..color = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFFF2200), ep)!.withValues(alpha: (1 - ep) * 0.9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + ep * 24),
        );
        canvas.drawCircle(
          Offset(ix, iy),
          expR * 0.4,
          Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );

        // 3D Supersonic Ground Shockwave Ring
        canvas.drawCircle(
          Offset(ix, iy),
          expR * 1.7,
          Paint()
            ..color = const Color(0xFFFF9900).withValues(alpha: (1 - ep) * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1 - ep) * 4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );

        // Ejecta debris flying outward
        for (int d = 0; d < 12; d++) {
          final da = d * pi / 6;
          final dr = ep * (50 + rng.nextDouble() * 60);
          final px = ix + cos(da) * dr;
          final py = iy - sin(da).abs() * dr * 0.8;
          canvas.drawCircle(
            Offset(px, py),
            2.5,
            Paint()..color = const Color(0xFFFFD700).withValues(alpha: (1 - ep) * 0.85),
          );
        }

        // Impact crater core
        canvas.drawCircle(
          Offset(ix, iy),
          16 + ep * 18,
          Paint()..color = const Color(0xFF2A0A00).withValues(alpha: ep.clamp(0.0, 1.0)),
        );
      }
    }
    _hudLabel(canvas, size, 'KINETIC IMPACT EVENT · SHOCKWAVES DETECTED', const Color(0xFFFF2200));
  }

  // ── STAGE 6: Expanding Cosmic Debris Nebula ──
  void _drawDebrisNebula(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF03010A));
    _staticStars(canvas, size, 120, 54321);

    // Multi-color ionized gas clouds
    final rng = Random(11223);
    for (int i = 0; i < 9; i++) {
      final nx = cx + (rng.nextDouble() - 0.5) * size.width * 0.9;
      final ny = cy + (rng.nextDouble() - 0.5) * size.height * 0.7;
      final nr = 50.0 + rng.nextDouble() * 90;
      final nebulaCol = [
        const Color(0xFF7C3AED),
        const Color(0xFF00E5FF),
        const Color(0xFFFF2A85),
        const Color(0xFF2563EB),
      ][i % 4];
      canvas.drawCircle(
        Offset(nx + cos(t * 2 * pi * 0.05 + i) * 10, ny + sin(t * 2 * pi * 0.05 + i) * 8),
        nr,
        Paint()
          ..color = nebulaCol.withValues(alpha: 0.16 + rng.nextDouble() * 0.08)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, nr * 0.7),
      );
    }

    // 3D Drifting Asteroid Debris Chunks with Shading
    for (int i = 0; i < 28; i++) {
      final rng2 = Random(i * 777);
      final dx = (rng2.nextDouble() * size.width + t * 40 * (i % 2 == 0 ? 1 : -0.7)) % size.width;
      final dy = rng2.nextDouble() * size.height;
      final ds = 2.0 + rng2.nextDouble() * 6.0;

      // 3D Lit Asteroid facet
      canvas.drawCircle(Offset(dx, dy), ds, Paint()..color = const Color(0xFF64748B));
      canvas.drawCircle(Offset(dx - ds * 0.3, dy - ds * 0.3), ds * 0.5, Paint()..color = const Color(0xFF94A3B8));
      if (ds > 4.0) {
        canvas.drawCircle(
          Offset(dx, dy),
          ds * 2,
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
    _hudLabel(canvas, size, 'POST-IMPACT NEBULA · HIGH-ENERGY EXPANSION', const Color(0xFF00E5FF));
  }

  // ─── 3D Graphics Helpers ───
  void _draw3DShootingTrail(Canvas canvas, Offset from, Offset to, Color col, double alpha) {
    // Outer volumetric ionization sheath
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = col.withValues(alpha: alpha * 0.6)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Brilliant white-hot lance
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Head spark
    canvas.drawCircle(
      to,
      4.5,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _draw3DFireMeteor(Canvas canvas, Offset from, Offset to, double radius, double intensity) {
    // Multi-segment incandescent thermal trail
    const segments = 10;
    for (int i = 0; i < segments; i++) {
      final p = i / segments;
      final pos = Offset.lerp(from, to, p)!;
      final segR = radius * (0.3 + p * 0.9);
      final col = Color.lerp(
        const Color(0xFF331100),
        const Color(0xFFFFFFEE),
        p * p,
      )!;
      canvas.drawCircle(
        pos,
        segR * 1.8,
        Paint()
          ..color = col.withValues(alpha: (0.2 + p * 0.7) * intensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + p * 8),
      );
    }

    // Molten 3D Asteroid Core
    canvas.drawCircle(to, radius, Paint()..color = const Color(0xFF451A03));
    canvas.drawCircle(
      to,
      radius * 0.7,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFB703), Color(0xFFD00000)],
        ).createShader(Rect.fromCircle(center: to, radius: radius * 0.7)),
    );
    canvas.drawCircle(
      to,
      radius * 2.2,
      Paint()
        ..color = const Color(0xFFFF7700).withValues(alpha: 0.6 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _staticStars(Canvas canvas, Size size, int count, int seed) {
    final rng = Random(seed);
    for (int i = 0; i < count; i++) {
      final sx = rng.nextDouble() * size.width + gyroX * (i % 4) * 2;
      final sy = rng.nextDouble() * size.height + gyroY * (i % 3) * 1.5;
      canvas.drawCircle(
        Offset(sx, sy),
        rng.nextDouble() * 1.5 + 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.2 + rng.nextDouble() * 0.6),
      );
    }
  }

  void _hudLabel(Canvas canvas, Size size, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.04, size.height * 0.06));
  }

  @override
  bool shouldRepaint(covariant _ShootingStarsPainter old) => true;
}

// ============================================================
// WIDGET 23: Alien Invasion — 3D Mothership & Extraterrestrial Siege (7 Stages)
// ============================================================
class AlienInvasionAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const AlienInvasionAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<AlienInvasionAnimation> createState() => _AlienInvasionAnimationState();
}

class _AlienInvasionAnimationState extends State<AlienInvasionAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _pulseCtrl;
  Offset? _touchPos;
  int _lastSoundStage = -1;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 42))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _checkStageSound(int stageIdx) {
    if (stageIdx != _lastSoundStage) {
      _lastSoundStage = stageIdx;
      if (stageIdx == 1 || stageIdx == 2) {
        GameSoundService().playAlienBeam();
      } else if (stageIdx == 3 || stageIdx == 4) {
        GameSoundService().playAlienBeam();
      } else if (stageIdx == 5) {
        GameSoundService().playLaser();
      } else if (stageIdx == 6) {
        GameSoundService().playHoloEngage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        GameSoundService().playLaser();
        setState(() => _touchPos = d.localPosition);
      },
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (d) {
        GameSoundService().playAlienBeam();
        setState(() => _touchPos = d.localPosition);
      },
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _pulseCtrl]),
        builder: (_, __) {
          final stageF = _mainCtrl.value * 7;
          final stageIdx = stageF.floor().clamp(0, 6);
          _checkStageSound(stageIdx);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(widget.gyroY * 0.15)
              ..rotateY(-widget.gyroX * 0.15),
            alignment: Alignment.center,
            child: CustomPaint(
              painter: _AlienInvasionPainter(
                t: _mainCtrl.value,
                pulse: _pulseCtrl.value,
                gyroX: widget.gyroX,
                gyroY: widget.gyroY,
                touchPos: _touchPos,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlienInvasionPainter extends CustomPainter {
  final double t;
  final double pulse;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _AlienInvasionPainter({
    required this.t,
    required this.pulse,
    required this.gyroX,
    required this.gyroY,
    required this.touchPos,
  });

  static const int _stages = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final stageF = t * _stages;
    final stageIdx = stageF.floor().clamp(0, _stages - 1);
    final localT = stageF - stageIdx;
    final cx = size.width * 0.5 + gyroX * 14;
    final cy = size.height * 0.5 + gyroY * 10;
    final fadeAlpha = localT < 0.1 ? localT / 0.1 : (localT > 0.9 ? (1 - localT) / 0.1 : 1.0);

    switch (stageIdx) {
      case 0: _drawCalmCity(canvas, size, cx, cy, localT);
      case 1: _drawStrangeLights(canvas, size, cx, cy, localT);
      case 2: _drawScoutUFO(canvas, size, cx, cy, localT);
      case 3: _drawMothership(canvas, size, cx, cy, localT);
      case 4: _drawTractorBeam(canvas, size, cx, cy, localT);
      case 5: _drawFullInvasion(canvas, size, cx, cy, localT);
      case 6: _drawAlienBroadcast(canvas, size, cx, cy, localT);
    }

    // Interactive laser strike on user tap
    if (touchPos != null) {
      _drawInteractiveLaser(canvas, size, touchPos!);
    }

    // Stage labels
    final stageLabels = [
      'PEACEFUL CITY SKYLINE 3D',
      'ANOMALOUS ION SIGNALS',
      'SCOUT INTERCEPTORS 3D',
      '3D DREADNOUGHT MOTHERSHIP',
      'VOLUMETRIC TRACTOR BEAM',
      'PLANETARY INVASION FLEET',
      'QUANTUM ALIEN BROADCAST',
    ];
    final subLabels = [
      'ATMOSPHERIC RADAR CLEAR',
      'QUANTUM RESONANCE SPIKE DETECTED',
      'UNIDENTIFIED FLIGHT PATTERN CONFIRMED',
      'CLASS-IX EXTIRPATOR MOTHERSHIP DESCENDING',
      'GRAVITATIONAL INVERSION VORTEX ACTIVE',
      'FLEET CANNON FIRE EXCHANGED · ALL DEFENSES ENGAGED',
      '  CYBERNETIC EXTRATERRESTRIAL COMM LINK ESTABLISHED',
    ];

    final lp = TextPainter(
      text: TextSpan(
        text: stageLabels[stageIdx],
        style: TextStyle(
          color: Colors.white.withValues(alpha: fadeAlpha * 0.95),
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.6,
          fontFamily: 'monospace',
          shadows: const [Shadow(color: Color(0xFF00FF66), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(cx - lp.width / 2, size.height * 0.84));

    final sp = TextPainter(
      text: TextSpan(
        text: subLabels[stageIdx],
        style: TextStyle(
          color: const Color(0xFF00FF88).withValues(alpha: fadeAlpha * 0.8),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sp.paint(canvas, Offset(cx - sp.width / 2, size.height * 0.895));

    // Progress bar & Dots
    final bw = size.width * 0.55;
    final bx = cx - bw / 2;
    final by = size.height * 0.935;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, 2.5), const Radius.circular(2)), Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw * t, 2.5), const Radius.circular(2)),
        Paint()..color = const Color(0xFF00FF66).withValues(alpha: 0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    final dotY = size.height * 0.96;
    const dotSpacing = 18.0;
    final dotsStart = cx - (_stages - 1) * dotSpacing / 2;
    for (int i = 0; i < _stages; i++) {
      final active = i == stageIdx;
      canvas.drawCircle(
        Offset(dotsStart + i * dotSpacing, dotY),
        active ? 4.5 : 2.5,
        Paint()
          ..color = active ? const Color(0xFF00FF66) : Colors.white.withValues(alpha: 0.2)
          ..maskFilter = active ? const MaskFilter.blur(BlurStyle.normal, 4) : null,
      );
    }
  }

  void _drawInteractiveLaser(Canvas canvas, Size size, Offset target) {
    final start = Offset(size.width * 0.5, size.height * 0.2);
    canvas.drawLine(
      start,
      target,
      Paint()
        ..color = const Color(0xFF00FF88)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      target,
      12,
      Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  // ── STAGE 0: Calm 3D City Night ──
  void _drawCalmCity(Canvas canvas, Size size, double cx, double cy, double t) {
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF010414), const Color(0xFF061033), const Color(0xFF0D1B44)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
    _cityStars(canvas, size, 90, 11111);
    _hudLabel(canvas, size, 'SURVEILLANCE MODE  ·  NO THREATS DETECTED', const Color(0xFF66AAFF));
  }

  // ── STAGE 1: Strange Lights / Power Flickers ──
  void _drawStrangeLights(Canvas canvas, Size size, double cx, double cy, double t) {
    // Sky flickers (darker intermittent)
    final flicker = (sin(t * 2 * pi * 12) + 1) / 2;
    final skyPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF001020), const Color(0xFF050A30).withValues(alpha: 0.9 + flicker * 0.1), const Color(0xFF04143A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
    _cityStars(canvas, size, 70, 22222);

    // Weird pulsing orbs in sky
    for (int i = 0; i < 4; i++) {
      final orbX = size.width * (0.18 + i * 0.22) + sin(t * 2 * pi * 0.4 + i) * 20;
      final orbY = size.height * (0.12 + i % 2 * 0.12) + cos(t * 2 * pi * 0.3 + i) * 15;
      canvas.drawCircle(Offset(orbX, orbY), 8 + pulse * 5,
          Paint()..color = const Color(0xFF44FF88).withValues(alpha: 0.2 + pulse * 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      canvas.drawCircle(Offset(orbX, orbY), 4, Paint()..color = const Color(0xFF88FFAA).withValues(alpha: 0.85));
    }

    // Power flicker overlay
    if (flicker < 0.2) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.black.withValues(alpha: 0.6 * (0.2 - flicker) / 0.2));
    }

    _drawCitySilhouetteGlow(canvas, size, false, t);
    _hudLabel(canvas, size, 'WARNING: ELECTROMAGNETIC ANOMALY', const Color(0xFFFFAA44));
  }

  // ── STAGE 2: Scout UFO appears ──
  void _drawScoutUFO(Canvas canvas, Size size, double cx, double cy, double t) {
    final skyPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF000A18), const Color(0xFF010A22), const Color(0xFF020D2A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
    _cityStars(canvas, size, 60, 33333);

    // Scout craft — enters from top right, hovers
    final scoutX = size.width * 0.72 + cos(t * 2 * pi * 0.5) * 30;
    final scoutY = size.height * (0.08 + t * 0.14) + sin(t * 2 * pi * 0.4) * 12;

    // Cloaking shimmer (entering)
    if (t < 0.3) {
      canvas.drawOval(Rect.fromCenter(center: Offset(scoutX, scoutY), width: 80 * (t / 0.3), height: 30 * (t / 0.3)),
          Paint()..color = const Color(0xFF44FFAA).withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }

    _drawSaucer(canvas, Offset(scoutX, scoutY), 35, const Color(0xFF88BBCC), false);

    // Search beam pointing down
    final beamPath = Path()
      ..moveTo(scoutX - 12, scoutY + 16)
      ..lineTo(scoutX + 12, scoutY + 16)
      ..lineTo(scoutX + 50, scoutY + 110)
      ..lineTo(scoutX - 50, scoutY + 110)
      ..close();
    canvas.drawPath(beamPath, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF44FF88).withValues(alpha: 0.4), Colors.transparent]).createShader(Rect.fromLTWH(scoutX - 50, scoutY + 16, 100, 100)));

    _drawCitySilhouetteGlow(canvas, size, false, t);
    _hudLabel(canvas, size, 'UNIDENTIFIED CRAFT DETECTED  ·  TRACKING', const Color(0xFFFFCC44));
  }

  // ── STAGE 3: Mothership Descending ──
  void _drawMothership(Canvas canvas, Size size, double cx, double cy, double t) {
    // Sky darkening as mothership blocks light
    final darken = t * 0.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Color.lerp(const Color(0xFF000A18), const Color(0xFF000005), darken)!);
    _cityStars(canvas, size, 40, 44444);

    // Mothership entering from top
    final msY = -120.0 + t * size.height * 0.36;
    final msW = size.width * (0.6 + t * 0.2);

    // Shadow cast on scene
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.7), width: msW * 0.8, height: 60),
        Paint()..color = Colors.black.withValues(alpha: t * 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    // Mothership hull
    _drawMothershipHull(canvas, Offset(cx, msY), msW);

    // Corona glow (heat of entry)
    if (t < 0.4) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, msY), width: msW * 1.1, height: msW * 0.35),
          Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.06 + t * 0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    }

    _drawCitySilhouetteGlow(canvas, size, true, t);
    _hudLabel(canvas, size, 'MOTHERSHIP DETECTED  ·  CLASS: EXTINCTION', const Color(0xFFFF4444));
  }

  // ── STAGE 4: Tractor Beam Abducting City ──
  void _drawTractorBeam(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000003));
    _cityStars(canvas, size, 30, 55555);

    final msY = size.height * 0.18;
    _drawMothershipHull(canvas, Offset(cx, msY), size.width * 0.78);

    // Tractor beam — cone from ship to ground
    final beamW = size.width * 0.22;
    for (int layer = 0; layer < 4; layer++) {
      final scale = 1.0 - layer * 0.18;
      final bPath = Path()
        ..moveTo(cx - beamW * 0.2 * scale, msY + 30)
        ..lineTo(cx + beamW * 0.2 * scale, msY + 30)
        ..lineTo(cx + beamW * scale, size.height * 0.74)
        ..lineTo(cx - beamW * scale, size.height * 0.74)
        ..close();
      canvas.drawPath(bPath, Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF00FF88).withValues(alpha: 0.25 - layer * 0.04), Colors.transparent]).createShader(Rect.fromLTWH(cx - beamW, msY + 30, beamW * 2, size.height * 0.55)));
    }

    // Scan line moving in beam
    final scanY = msY + 30 + (t * 2 * pi * 1.5 % 1.0) * (size.height * 0.74 - msY - 30);
    final scanAlpha = 0.5 + pulse * 0.4;
    canvas.drawLine(Offset(cx - beamW * (scanY - msY - 30) / (size.height * 0.74 - msY - 30), scanY),
        Offset(cx + beamW * (scanY - msY - 30) / (size.height * 0.74 - msY - 30), scanY),
        Paint()..color = const Color(0xFF00FF88).withValues(alpha: scanAlpha)..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Objects being lifted up in beam
    for (int i = 0; i < 5; i++) {
      final liftPhase = (t * 1.4 + i * 0.2) % 1.0;
      final liftX = cx + (i - 2) * 22.0;
      final liftY = size.height * 0.73 - liftPhase * (size.height * 0.52);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(liftX, liftY),
          width: 8.0 + i * 2.0,
          height: 5.0 + i.toDouble(),
        ),
        Paint()..color = const Color(0xFF888888).withValues(alpha: 0.8 - liftPhase * 0.4),
      );
    }

    // Lightning crackle
    if (pulse > 0.7) {
      for (int i = 0; i < 3; i++) {
        final lx1 = cx + (Random(i * 100 + (t * 50).toInt()).nextDouble() - 0.5) * beamW;
        final ly1 = msY + 40 + Random(i * 200).nextDouble() * 80;
        final lx2 = lx1 + (Random(i * 300).nextDouble() - 0.5) * 40;
        final ly2 = ly1 + 30 + Random(i * 400).nextDouble() * 40;
        canvas.drawLine(Offset(lx1, ly1), Offset(lx2, ly2),
            Paint()..color = const Color(0xFF88FFCC).withValues(alpha: (pulse - 0.7) * 3)..strokeWidth = 1.5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    _drawCitySilhouetteGlow(canvas, size, true, t);
    _hudLabel(canvas, size, 'TRACTOR BEAM  ·  ABDUCTION ACTIVE', const Color(0xFF00FF66));
  }

  // ── STAGE 5: Full Invasion Fleet ──
  void _drawFullInvasion(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000005));
    _cityStars(canvas, size, 20, 66666);

    // 3 mid-size saucers flanking
    final saucerPositions = [
      Offset(cx - size.width * 0.35, size.height * 0.12 + sin(t * 2 * pi * 0.35) * 15),
      Offset(cx + size.width * 0.33, size.height * 0.10 + sin(t * 2 * pi * 0.4 + 1) * 12),
      Offset(cx - size.width * 0.12, size.height * 0.22 + sin(t * 2 * pi * 0.3 + 2) * 10),
    ];
    for (final pos in saucerPositions) {
      _drawSaucer(canvas, pos, 40, const Color(0xFF8899AA), false);
      // Laser shots
      if (pulse > 0.5) {
        canvas.drawLine(
          Offset(pos.dx, pos.dy + 20),
          Offset(pos.dx + (Random((pos.dx * 100).toInt()).nextDouble() - 0.5) * 60, size.height * 0.72),
          Paint()..color = const Color(0xFFFF3300).withValues(alpha: (pulse - 0.5) * 2)..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // Main mothership at top
    _drawMothershipHull(canvas, Offset(cx, size.height * 0.08), size.width * 0.85);

    // Explosions on city
    final rng = Random((t * 60).toInt());
    for (int i = 0; i < 5; i++) {
      final ex = size.width * (0.1 + rng.nextDouble() * 0.8);
      final ey = size.height * (0.65 + rng.nextDouble() * 0.08);
      final er = 10 + rng.nextDouble() * 25;
      canvas.drawCircle(Offset(ex, ey), er, Paint()
        ..color = const Color(0xFFFF6600).withValues(alpha: 0.6 + pulse * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, er * 0.5));
    }

    // Red atmosphere glow (fire from ground)
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.15),
        Paint()..color = const Color(0xFFFF3300).withValues(alpha: 0.12 + pulse * 0.08)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));

    _drawCitySilhouetteGlow(canvas, size, true, t);
    _hudLabel(canvas, size, 'INVASION FLEET ENGAGED  ·  ALL SECTORS HIT', const Color(0xFFFF3300));
  }

  // ── STAGE 6: Alien Broadcast ──
  void _drawAlienBroadcast(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000008));

    // Signal wave pattern (alien carrier wave)
    for (int w = 0; w < 7; w++) {
      final waveY = size.height * (0.15 + w * 0.1);
      final path = Path()..moveTo(0, waveY);
      for (int x = 0; x < size.width.toInt(); x += 3) {
        final freq = 3.0 + w * 0.5;
        path.lineTo(x.toDouble(), waveY + sin(x / size.width * 2 * pi * freq + t * 2 * pi * 0.8 + w) * (8 + w * 3));
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF00FF66).withValues(alpha: 0.08 + w * 0.02)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Mothership silhouette faint in background
    _drawMothershipHull(canvas, Offset(cx, -size.height * 0.1 + sin(t * 2 * pi * 0.2) * 8), size.width * 0.9);

    // Signal broadcast rings from mothership
    for (int r = 0; r < 5; r++) {
      final ringPhase = (t * 2.5 + r * 0.2) % 1.0;
      final ringR = ringPhase * size.width * 0.55;
      canvas.drawCircle(Offset(cx, size.height * 0.08), ringR,
          Paint()..color = const Color(0xFF00FF66).withValues(alpha: (1 - ringPhase) * 0.3)
            ..style = PaintingStyle.stroke..strokeWidth = 1.8..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // "We come in peace" text rendered in alien glyphs style
    final msgPaint = TextPainter(
      text: TextSpan(
        text: '▓▒░ TRANSMISSION RECEIVED ░▒▓',
        style: TextStyle(color: const Color(0xFF00FF66).withValues(alpha: 0.75 + pulse * 0.2), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    msgPaint.paint(canvas, Offset(cx - msgPaint.width / 2, cy - 10));

    // Scan lines overlay
    for (int sl = 0; sl < size.height.toInt(); sl += 4) {
      canvas.drawLine(Offset(0, sl.toDouble()), Offset(size.width, sl.toDouble()),
          Paint()..color = Colors.black.withValues(alpha: 0.08));
    }

    // Power-down city (dark, only faint outlines)
    _drawCitySilhouetteGlow(canvas, size, false, 0);

    _hudLabel(canvas, size, '  ALIEN SIGNAL  ·  DECODING IN PROGRESS', const Color(0xFF00FF66));
  }

  // ─── Shared Drawing Helpers ───
  void _drawSaucer(Canvas canvas, Offset pos, double r, Color color, bool large) {
    // Hull body
    canvas.drawOval(Rect.fromCenter(center: pos, width: r * 2.5, height: r * 0.65),
        Paint()..shader = RadialGradient(center: const Alignment(0, -0.5), radius: 0.9,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.6)]).createShader(
            Rect.fromCenter(center: pos, width: r * 2.5, height: r * 0.65)));
    // Dome
    canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, pos.dy - r * 0.18), width: r, height: r * 0.65),
        Paint()..color = const Color(0xFF99CCEE).withValues(alpha: 0.85));
    // Alien eyes in dome
    for (int e = 0; e < 3; e++) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(pos.dx + (e - 1) * r * 0.28, pos.dy - r * 0.22), width: r * 0.14, height: r * 0.2),
        Paint()..color = const Color(0xFF001100).withValues(alpha: 0.9),
      );
    }
    // Rotating rim lights
    for (int l = 0; l < 10; l++) {
      final la = l * 2 * pi / 10 + t * 2 * pi * 0.7;
      final lx = pos.dx + cos(la) * r * 1.05;
      final ly = pos.dy + sin(la) * r * 0.25;
      final lColor = [const Color(0xFF00FF88), const Color(0xFF00AAFF), const Color(0xFFFF8800), const Color(0xFFFF00FF)][l % 4];
      canvas.drawCircle(Offset(lx, ly), 3, Paint()..color = lColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    // Bottom strobe
    canvas.drawCircle(Offset(pos.dx, pos.dy + r * 0.3), 5 + pulse * 3,
        Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.5 + pulse * 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  }

  void _drawMothershipHull(Canvas canvas, Offset center, double width) {
    final h = width * 0.22;
    // Shadow underside
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, center.dy + h * 0.3), width: width, height: h * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    // Main hull
    canvas.drawOval(Rect.fromCenter(center: center, width: width, height: h),
        Paint()..shader = RadialGradient(center: const Alignment(0, -0.6), radius: 0.85,
          colors: [const Color(0xFF7799AA), const Color(0xFF445566), const Color(0xFF223344)]).createShader(
            Rect.fromCenter(center: center, width: width, height: h)));
    // Hull stripes/panels
    for (int p = 0; p < 6; p++) {
      canvas.drawLine(
        Offset(center.dx - width * 0.4 + p * width * 0.16, center.dy - h * 0.4),
        Offset(center.dx - width * 0.4 + p * width * 0.16, center.dy + h * 0.4),
        Paint()..color = Colors.black.withValues(alpha: 0.15)..strokeWidth = 1.5,
      );
    }
    // Command dome
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, center.dy - h * 0.5), width: width * 0.28, height: h * 0.9),
        Paint()..color = const Color(0xFF99BBCC).withValues(alpha: 0.7));
    // Rotating hull lights
    for (int l = 0; l < 14; l++) {
      final la = l * 2 * pi / 14 + t * 2 * pi * 0.4;
      final lx = center.dx + cos(la) * width * 0.45;
      final ly = center.dy + sin(la) * h * 0.3;
      final lColor = [const Color(0xFF00FF88), const Color(0xFFFF4400), const Color(0xFF0088FF)][l % 3];
      canvas.drawCircle(Offset(lx, ly), 3.5, Paint()..color = lColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    // Underside engine glow
    for (int e = 0; e < 5; e++) {
      final ex = center.dx - width * 0.35 + e * width * 0.175;
      canvas.drawCircle(Offset(ex, center.dy + h * 0.35), 8 + pulse * 4,
          Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.35 + pulse * 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
  }

  void _drawCitySilhouetteGlow(Canvas canvas, Size size, bool withGlow, double t) {
    if (withGlow) {
      // Orange fire glow on horizon
      canvas.drawRect(Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.08),
          Paint()..color = const Color(0xFFFF4400).withValues(alpha: 0.18 + pulse * 0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    }
    final buildingPaint = Paint()..color = const Color(0xFF060C04);
    final rng = Random(77777);
    double bx = 0;
    while (bx < size.width) {
      final bw = 14.0 + rng.nextDouble() * 28;
      final bh = 38.0 + rng.nextDouble() * 95;
      canvas.drawRect(Rect.fromLTWH(bx, size.height * 0.75 - bh, bw, bh + size.height * 0.25), buildingPaint);
      // Window lights
      for (int wy = 0; wy < (bh / 14).floor(); wy++) {
        for (int wx = 0; wx < (bw / 8).floor(); wx++) {
          if (rng.nextDouble() > 0.55) {
            final wAlpha = withGlow ? rng.nextDouble() * 0.2 : 0.2 + rng.nextDouble() * 0.25;
            canvas.drawRect(
              Rect.fromLTWH(bx + 2 + wx * 8, size.height * 0.75 - bh + wy * 14 + 4, 4, 5),
              Paint()..color = const Color(0xFFFFCC44).withValues(alpha: wAlpha),
            );
          }
        }
      }
      bx += bw + 2;
    }
  }

  void _cityStars(Canvas canvas, Size size, int count, int seed) {
    final rng = Random(seed);
    for (int i = 0; i < count; i++) {
      final sx = rng.nextDouble() * size.width + gyroX * (i % 4) * 2.5;
      final sy = rng.nextDouble() * size.height * 0.65 + gyroY * (i % 3) * 1.5;
      canvas.drawCircle(Offset(sx, sy), rng.nextDouble() * 1.2 + 0.3, Paint()..color = Colors.white.withValues(alpha: 0.2 + rng.nextDouble() * 0.55));
    }
  }

  void _hudLabel(Canvas canvas, Size size, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.04, size.height * 0.06));
  }

  @override
  bool shouldRepaint(covariant _AlienInvasionPainter old) => true;
}

// ============================================================
// WIDGET 24: Cosmic Zoom — 3D Macroverse to Quantum Singularity (8 Stages)
// ============================================================
class CosmicZoomAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const CosmicZoomAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<CosmicZoomAnimation> createState() => _CosmicZoomAnimationState();
}

class _CosmicZoomAnimationState extends State<CosmicZoomAnimation>
    with TickerProviderStateMixin {
  late AnimationController _zoomCtrl;
  late AnimationController _pulseCtrl;
  Offset? _touchPos;
  int _lastSoundStage = -1;

  @override
  void initState() {
    super.initState();
    // 48 seconds total for 8 stages = 6s per stage
    _zoomCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 48))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _checkStageSound(int stageIdx) {
    if (stageIdx != _lastSoundStage) {
      _lastSoundStage = stageIdx;
      GameSoundService().playHyperspace();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        GameSoundService().playHyperspace();
        setState(() => _touchPos = d.localPosition);
      },
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (d) {
        GameSoundService().playHyperspace();
        setState(() => _touchPos = d.localPosition);
      },
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_zoomCtrl, _pulseCtrl]),
        builder: (_, __) {
          final stageF = _zoomCtrl.value * 8;
          final stageIdx = stageF.floor().clamp(0, 7);
          _checkStageSound(stageIdx);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(widget.gyroY * 0.12)
              ..rotateY(-widget.gyroX * 0.12),
            alignment: Alignment.center,
            child: CustomPaint(
              painter: _CosmicZoomPainter(
                t: _zoomCtrl.value,
                pulse: _pulseCtrl.value,
                gyroX: widget.gyroX,
                gyroY: widget.gyroY,
                touchPos: _touchPos,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CosmicZoomPainter extends CustomPainter {
  final double t;
  final double pulse;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _CosmicZoomPainter({
    required this.t,
    required this.pulse,
    required this.gyroX,
    required this.gyroY,
    required this.touchPos,
  });

  static const int _stages = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final stageF = t * _stages;
    final stageIdx = stageF.floor().clamp(0, _stages - 1);
    final localT = stageF - stageIdx;
    final cx = size.width * 0.5 + gyroX * 14;
    final cy = size.height * 0.46 + gyroY * 10;
    final fadeAlpha = localT < 0.12 ? localT / 0.12 : (localT > 0.88 ? (1 - localT) / 0.12 : 1.0);

    switch (stageIdx) {
      case 0: _draw3DEarthSurface(canvas, size, cx, cy, localT);
      case 1: _draw3DEarthOrbit(canvas, size, cx, cy, localT);
      case 2: _draw3DSolarSystem(canvas, size, cx, cy, localT);
      case 3: _draw3DMilkyWay(canvas, size, cx, cy, localT);
      case 4: _draw3DLocalGroup(canvas, size, cx, cy, localT);
      case 5: _draw3DObservableUniverse(canvas, size, cx, cy, localT);
      case 6: _draw3DCosmicHorizon(canvas, size, cx, cy, localT);
      case 7: _draw3DBigBangSingularity(canvas, size, cx, cy, localT);
    }

    // Stage labels
    final titles = [
      'EARTH SURFACE & ATMOSPHERE 3D',
      'EARTH FROM ORBIT 3D',
      '3D SOLAR SYSTEM',
      'MILKY WAY SPIRAL GALAXY',
      'LOCAL GALACTIC GROUP 3D',
      'LANIAKEA COSMIC WEB',
      'COSMIC MICROWAVE HORIZON',
      'T=0 QUANTUM BIG BANG',
    ];
    final subtitles = [
      '10⁰ m · MESOSPHERE STRATA BOUNDARY',
      '10⁷ m · RAYLEIGH ATMOSPHERIC SCATTERING',
      '10¹² m · HELIOSPHERIC GRAVITATIONAL ORBITS',
      '10²¹ m · SAGITTARIUS A* ACCRETION DISC',
      '10²³ m · ANDROMEDA & TRIANGULUM CLUSTERS',
      '10²⁶ m · SUPERCLUSTER FILAMENT NETWORK',
      '10²⁷ m · 2.725 K PRIMORDIAL THERMAL GLOW',
      '10⁻³⁵ m · PLANCK EPOCH SINGULARITY',
    ];

    final lp = TextPainter(
      text: TextSpan(
        text: titles[stageIdx],
        style: TextStyle(
          color: Colors.white.withValues(alpha: fadeAlpha * 0.95),
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.6,
          fontFamily: 'monospace',
          shadows: const [Shadow(color: Color(0xFF00E5FF), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(cx - lp.width / 2, size.height * 0.84));

    final sp = TextPainter(
      text: TextSpan(
        text: subtitles[stageIdx],
        style: TextStyle(
          color: const Color(0xFF00E5FF).withValues(alpha: fadeAlpha * 0.85),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sp.paint(canvas, Offset(cx - sp.width / 2, size.height * 0.895));

    // Progress bar & Dots
    final bw = size.width * 0.55;
    final bx = cx - bw / 2;
    final by = size.height * 0.935;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, 2.5), const Radius.circular(2)), Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw * t, 2.5), const Radius.circular(2)),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    final dotY = size.height * 0.96;
    const dotSpacing = 16.0;
    final dotsStart = cx - (_stages - 1) * dotSpacing / 2;
    for (int i = 0; i < _stages; i++) {
      final active = i == stageIdx;
      canvas.drawCircle(
        Offset(dotsStart + i * dotSpacing, dotY),
        active ? 4.5 : 2.5,
        Paint()
          ..color = active ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.2)
          ..maskFilter = active ? const MaskFilter.blur(BlurStyle.normal, 4) : null,
      );
    }
  }

  // ── STAGE 0: 3D Earth Surface / Mesosphere ──
  void _draw3DEarthSurface(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF02091A));

    final atmPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF010614), const Color(0xFF0055D4), const Color(0xFF00CCFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.65), atmPaint);

    final horizonPath = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(cx, size.height * 0.52 - t * 25, size.width, size.height * 0.6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      horizonPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E7490), Color(0xFF1E3A8A), Color(0xFF040B1A)],
        ).createShader(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5)),
    );

    canvas.drawPath(
      horizonPath,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10⁰ m · EARTH STRATOSPHERE ASCENT', const Color(0xFF00E5FF));
  }

  // ── STAGE 1: 3D Earth from Orbit ──
  void _draw3DEarthOrbit(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF01020A));
    _drawStarField(canvas, size, 80, 11111);

    final r = (size.width * 0.38) * (1 - t * 0.45);

    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.12,
      Paint()
        ..color = const Color(0xFF00BFFF).withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );

    final earthPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.95,
        colors: const [
          Color(0xFF0099FF),
          Color(0xFF0044AA),
          Color(0xFF001A4D),
          Color(0xFF010511),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, earthPaint);

    final landPaint = Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.65);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.25, cy - r * 0.1), width: r * 0.9, height: r * 0.65), landPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.3, cy + r * 0.2), width: r * 0.8, height: r * 0.5), landPaint);

    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + sin(t * pi) * 20, cy - r * 0.2), width: r * 1.2, height: r * 0.25), cloudPaint);
    canvas.restore();

    final issAngle = t * 2 * pi;
    final issX = cx + cos(issAngle) * (r * 1.35);
    final issY = cy + sin(issAngle) * (r * 0.7);
    canvas.drawCircle(Offset(issX, issY), 3.5, Paint()..color = const Color(0xFFFFD700));
    canvas.drawCircle(Offset(issX, issY), 8, Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10⁷ m · PLANET EARTH 3D', const Color(0xFF00E5FF));
  }

  // ── STAGE 2: 3D Solar System ──
  void _draw3DSolarSystem(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF01010A));
    _drawStarField(canvas, size, 110, 22222);

    final sunR = 24.0 + pulse * 4.0;
    canvas.drawCircle(
      Offset(cx, cy),
      sunR * 2.5,
      Paint()
        ..color = const Color(0xFFFFB703).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sunR * 1.8),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      sunR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEE55), Color(0xFFFF4400)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: sunR)),
    );

    final planets = [
      {'r': 48.0, 'speed': 2.4, 'col': const Color(0xFF94A3B8), 'size': 2.5, 'name': 'Mercury'},
      {'r': 75.0, 'speed': 1.8, 'col': const Color(0xFFF59E0B), 'size': 4.0, 'name': 'Venus'},
      {'r': 110.0, 'speed': 1.2, 'col': const Color(0xFF00E5FF), 'size': 4.5, 'name': 'Earth'},
      {'r': 145.0, 'speed': 0.9, 'col': const Color(0xFFEF4444), 'size': 3.5, 'name': 'Mars'},
      {'r': 195.0, 'speed': 0.6, 'col': const Color(0xFFF97316), 'size': 9.0, 'name': 'Jupiter'},
      {'r': 255.0, 'speed': 0.4, 'col': const Color(0xFFFBBF24), 'size': 7.5, 'hasRings': true, 'name': 'Saturn'},
    ];

    for (final p in planets) {
      final or = (p['r'] as double) * (1 - t * 0.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: or * 2, height: or * 1.1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      final pa = (t * (p['speed'] as double) * 2 * pi);
      final px = cx + cos(pa) * or;
      final py = cy + sin(pa) * (or * 0.55);
      final pSize = p['size'] as double;
      final pCol = p['col'] as Color;

      canvas.drawCircle(Offset(px, py), pSize, Paint()..color = pCol);

      if (p['hasRings'] == true) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(px, py), width: pSize * 4.2, height: pSize * 1.6),
          Paint()
            ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10¹² m · HELIOSPHERE & PLANETARY ORBITS', const Color(0xFF00E5FF));
  }

  // ── STAGE 3: 3D Milky Way Spiral Galaxy ──
  void _draw3DMilkyWay(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010108));
    _drawStarField(canvas, size, 140, 33333);

    final coreR = 28.0 + pulse * 6;
    canvas.drawCircle(
      Offset(cx, cy),
      coreR * 2.2,
      Paint()
        ..color = const Color(0xFFFF8800).withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreR * 1.5),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFD700), Color(0xFFFF4400)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR)),
    );

    final rotAngle = t * 2 * pi * 0.3;
    const numArms = 4;
    const starsPerArm = 60;

    for (int arm = 0; arm < numArms; arm++) {
      final armOffset = arm * (2 * pi / numArms);
      for (int s = 0; s < starsPerArm; s++) {
        final p = s / starsPerArm.toDouble();
        final dist = 30.0 + p * (size.width * 0.42);
        final theta = armOffset + (p * 4.5) + rotAngle;
        final sx = cx + cos(theta) * dist;
        final sy = cy + sin(theta) * (dist * 0.48);

        final col = Color.lerp(
          const Color(0xFF00FFFF),
          const Color(0xFFFF66CC),
          p,
        )!;
        final starSize = (1 - p) * 2.5 + 0.8;
        canvas.drawCircle(
          Offset(sx, sy),
          starSize,
          Paint()..color = col.withValues(alpha: (0.4 + (1 - p) * 0.5)),
        );
      }
    }

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10²¹ m · MILKY WAY SPIRAL GALAXY', const Color(0xFF00E5FF));
  }

  // ── STAGE 4: 3D Local Galactic Group ──
  void _draw3DLocalGroup(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000108));
    _drawStarField(canvas, size, 160, 44444);

    _drawMiniGalaxy(canvas, Offset(cx + 40, cy + 30), 45, 0.4, const Color(0xFF00E5FF));
    _drawMiniGalaxy(canvas, Offset(cx - 70, cy - 50), 65, 0.85, const Color(0xFFFF88BB));
    _drawMiniGalaxy(canvas, Offset(cx - 90, cy + 70), 32, -0.3, const Color(0xFFB44FFF));

    canvas.drawLine(
      Offset(cx + 40, cy + 30),
      Offset(cx - 70, cy - 50),
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10²³ m · LOCAL GALACTIC GROUP (ANDROMEDA / MW)', const Color(0xFF00E5FF));
  }

  // ── STAGE 5: 3D Observable Universe / Laniakea Cosmic Web ──
  void _draw3DObservableUniverse(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010006));

    final rng = Random(55555);
    final nodes = <Offset>[];
    for (int i = 0; i < 28; i++) {
      nodes.add(Offset(
        size.width * (0.1 + rng.nextDouble() * 0.8) + gyroX * 8,
        size.height * (0.15 + rng.nextDouble() * 0.7) + gyroY * 6,
      ));
    }

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist < 90) {
          canvas.drawLine(
            nodes[i],
            nodes[j],
            Paint()
              ..color = const Color(0xFF9333EA).withValues(alpha: (1 - dist / 90) * 0.45)
              ..strokeWidth = 1.6
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      }
      // Supercluster Galaxy Cluster Node
      canvas.drawCircle(
        nodes[i],
        3.5,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10²⁶ m · LANIAKEA SUPERCLUSTER FILAMENT WEB', const Color(0xFF00E5FF));
  }

  // ── STAGE 6: 3D Cosmic Horizon & Cosmic Microwave Background (CMB) ──
  void _draw3DCosmicHorizon(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF040108));

    // Spherical CMB Horizon Circle with Einstein Gravitational Lens Ring
    final cmbR = size.width * 0.42;

    // Einstein Ring Warping Horizon
    canvas.drawCircle(
      Offset(cx, cy),
      cmbR,
      Paint()
        ..color = const Color(0xFFFF7700).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Multi-color Planck Satellite CMB Temperature Fluctuations (2.725 Kelvin)
    final rng = Random(66666);
    for (int i = 0; i < 70; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * cmbR * 0.95;
      final col = [
        const Color(0xFF1E3A8A), // Cold blue
        const Color(0xFF00E5FF),
        const Color(0xFFF59E0B), // Warm orange
        const Color(0xFFEF4444), // Hot red
      ][rng.nextInt(4)];
      canvas.drawCircle(
        Offset(cx + cos(a) * r, cy + sin(a) * r),
        12.0 + rng.nextDouble() * 18.0,
        Paint()
          ..color = col.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    _drawHudLabel(canvas, size, 'ZOOM LEVEL: 10²⁷ m · COSMIC HORIZON & 2.7K CMB', const Color(0xFFFF7700));
  }

  // ── STAGE 7: 3D The Big Bang / Quantum Singularity ──
  void _draw3DBigBangSingularity(Canvas canvas, Size size, double cx, double cy, double t) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000000));

    // Hyperspace 3D Warp Speed Lines Bursting toward camera (x/z, y/z projection)
    final rng = Random(77777);
    for (int i = 0; i < 70; i++) {
      final a = (i / 70.0) * 2 * pi;
      final speed = 0.5 + rng.nextDouble() * 0.8;
      final dist = (t * size.width * speed * 1.2) % (size.width * 0.8);
      final trailLen = 30.0 + t * 90.0;
      final sx = cx + cos(a) * dist;
      final sy = cy + sin(a) * dist;
      final ex = cx + cos(a) * (dist + trailLen);
      final ey = cy + sin(a) * (dist + trailLen);

      canvas.drawLine(
        Offset(sx, sy),
        Offset(ex, ey),
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: (1 - dist / (size.width * 0.8)).clamp(0.0, 1.0))
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Primordial Quantum Singularity Explosion Bloom
    final expR = 15.0 + t * 120.0;
    canvas.drawCircle(
      Offset(cx, cy),
      expR * 2.0,
      Paint()
        ..color = const Color(0xFFFF0055).withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, expR),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      expR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFF88), Color(0xFFFF5500)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: expR)),
    );

    _drawHudLabel(canvas, size, 'T=0 · QUANTUM SINGULARITY · THE BIG BANG', const Color(0xFFFF5500));
  }

  void _drawMiniGalaxy(Canvas canvas, Offset center, double radius, double tilt, Color col) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 0.8),
      Paint()
        ..color = col.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4),
    );
    canvas.drawCircle(Offset.zero, radius * 0.25, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.restore();
  }

  void _drawStarField(Canvas canvas, Size size, int count, int seed) {
    final rng = Random(seed);
    for (int i = 0; i < count; i++) {
      final sx = (rng.nextDouble() * size.width + gyroX * (i % 3 + 1) * 2) % size.width;
      final sy = (rng.nextDouble() * size.height + gyroY * (i % 2 + 1) * 1.5) % size.height;
      canvas.drawCircle(
        Offset(sx, sy),
        rng.nextDouble() * 1.3 + 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.25 + rng.nextDouble() * 0.55),
      );
    }
  }

  void _drawHudLabel(Canvas canvas, Size size, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.04, size.height * 0.06));
  }

  @override
  bool shouldRepaint(covariant _CosmicZoomPainter old) => true;
}

// ============================================================
// WIDGET 25: Space Battle War — 3D Imperial Fleet Siege
// ============================================================
class SpaceBattleAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const SpaceBattleAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<SpaceBattleAnimation> createState() => _SpaceBattleAnimationState();
}

class _SpaceBattleAnimationState extends State<SpaceBattleAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _explCtrl;
  final _rng = Random(99999);
  late List<_BattleShip> _friendlies;
  late List<_BattleShip> _enemies;
  late List<_Missile> _missiles;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))..repeat();
    _explCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat();
    _friendlies = List.generate(4, (i) => _BattleShip(_rng, true, i));
    _enemies = List.generate(5, (i) => _BattleShip(_rng, false, i));
    _missiles = [];
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _explCtrl.dispose();
    super.dispose();
  }

  void _spawnMissiles() {
    for (final ship in _friendlies) {
      if (_rng.nextDouble() > 0.95) {
        _missiles.add(_Missile(Offset(ship.x, ship.y), true));
        if (_rng.nextDouble() > 0.6) GameSoundService().playSpaceBattle();
      }
    }
    for (final ship in _enemies) {
      if (_rng.nextDouble() > 0.96) {
        _missiles.add(_Missile(Offset(ship.x, ship.y), false));
      }
    }
    _missiles.removeWhere((m) => m.isDead);
    if (_missiles.length > 30) _missiles.removeRange(0, _missiles.length - 30);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        GameSoundService().playSpaceBattle();
        setState(() => _touchPos = d.localPosition);
      },
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (d) {
        GameSoundService().playSpaceBattle();
        setState(() => _touchPos = d.localPosition);
      },
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _explCtrl]),
        builder: (_, __) {
          for (final s in _friendlies) s.update();
          for (final s in _enemies) s.update();
          for (final m in _missiles) m.update();
          _spawnMissiles();
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(widget.gyroY * 0.15)
              ..rotateY(-widget.gyroX * 0.15),
            alignment: Alignment.center,
            child: CustomPaint(
              painter: _SpaceBattlePainter(
                friendlies: _friendlies,
                enemies: _enemies,
                missiles: _missiles,
                explT: _explCtrl.value,
                gyroX: widget.gyroX,
                gyroY: widget.gyroY,
                touchPos: _touchPos,
                rng: _rng,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BattleShip {
  late double x, y, vx, vy;
  final bool isFriendly;
  final int index;
  late double wobble;

  _BattleShip(Random rng, this.isFriendly, this.index) {
    wobble = rng.nextDouble() * 2 * pi;
    if (isFriendly) {
      x = 0.08 + rng.nextDouble() * 0.18;
      y = 0.2 + index * 0.15 + rng.nextDouble() * 0.05;
    } else {
      x = 0.72 + rng.nextDouble() * 0.2;
      y = 0.18 + index * 0.13 + rng.nextDouble() * 0.05;
    }
    vx = 0;
    vy = 0;
  }

  void update() {
    wobble += 0.03;
    y += sin(wobble) * 0.0004;
    x = x.clamp(0.05, 0.95);
    y = y.clamp(0.05, 0.95);
  }
}

class _Missile {
  double x, y;
  final bool fromFriendly;
  bool isDead = false;
  final double speed = 0.013;
  double explodeAlpha = 0.0;
  bool exploding = false;
  int life = 0;

  _Missile(Offset start, this.fromFriendly)
      : x = start.dx,
        y = start.dy;

  void update() {
    if (exploding) {
      explodeAlpha -= 0.06;
      if (explodeAlpha <= 0) isDead = true;
      return;
    }
    x += fromFriendly ? speed : -speed;
    life++;
    final boundary = fromFriendly ? 0.72 : 0.28;
    if ((fromFriendly && x > boundary) || (!fromFriendly && x < boundary)) {
      exploding = true;
      explodeAlpha = 1.0;
      GameSoundService().playExplosion();
    }
    if (life > 90) isDead = true;
  }
}

class _SpaceBattlePainter extends CustomPainter {
  final List<_BattleShip> friendlies;
  final List<_BattleShip> enemies;
  final List<_Missile> missiles;
  final double explT;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;
  final Random rng;

  const _SpaceBattlePainter({
    required this.friendlies,
    required this.enemies,
    required this.missiles,
    required this.explT,
    required this.gyroX,
    required this.gyroY,
    required this.touchPos,
    required this.rng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Deep cosmic space background with interstellar dust
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.2 + gyroX * 0.1, -0.3 + gyroY * 0.1),
        radius: 1.4,
        colors: const [
          Color(0xFF0C102A),
          Color(0xFF050816),
          Color(0xFF01020A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 3D Parallax Stars with depth tiers
    for (int tier = 1; tier <= 3; tier++) {
      final sPaint = Paint();
      for (int i = 0; i < 40; i++) {
        final srng = Random(tier * 500 + i * 29);
        final sx = (srng.nextDouble() * size.width + gyroX * tier * 5) % size.width;
        final sy = (srng.nextDouble() * size.height + gyroY * tier * 3) % size.height;
        sPaint.color = Colors.white.withValues(alpha: 0.25 + srng.nextDouble() * 0.65);
        canvas.drawCircle(Offset(sx, sy), srng.nextDouble() * 1.5 + 0.3, sPaint);
      }
    }

    // Distant 3D Gas Giant Planet in Background
    final planetCenter = Offset(size.width * 0.82 + gyroX * 8, size.height * 0.22 + gyroY * 5);
    canvas.drawCircle(
      planetCenter,
      60,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A), Color(0xFF0F172A)],
        ).createShader(Rect.fromCircle(center: planetCenter, radius: 60)),
    );
    // Planet 3D Rings
    canvas.drawOval(
      Rect.fromCenter(center: planetCenter, width: 160, height: 42),
      Paint()
        ..color = const Color(0xFF93C5FD).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Volumetric battlefield nebula gas
    final nebPaint = Paint()
      ..color = const Color(0xFF4C1D95).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.65), 210, nebPaint);

    // Draw Missiles & 3D Detonation Shockwaves
    for (final m in missiles) {
      final mx = m.x * size.width + gyroX * 8;
      final my = m.y * size.height + gyroY * 4;

      if (m.exploding) {
        // High-Energy Blast Fireball
        canvas.drawCircle(
          Offset(mx, my),
          32 * m.explodeAlpha,
          Paint()
            ..color = const Color(0xFFFF9900).withValues(alpha: m.explodeAlpha * 0.85)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * m.explodeAlpha),
        );
        canvas.drawCircle(
          Offset(mx, my),
          14 * m.explodeAlpha,
          Paint()..color = Colors.white.withValues(alpha: m.explodeAlpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );

        // 3D Expanding Shockwave Ring
        canvas.drawCircle(
          Offset(mx, my),
          48 * (1 - m.explodeAlpha),
          Paint()
            ..color = const Color(0xFFFFCC00).withValues(alpha: m.explodeAlpha * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      } else {
        // High-Speed Torpedo Lance
        final mColor = m.fromFriendly ? const Color(0xFF00E5FF) : const Color(0xFFFF2A4B);
        canvas.drawLine(
          Offset(mx - (m.fromFriendly ? 16 : -16), my),
          Offset(mx, my),
          Paint()
            ..color = mColor.withValues(alpha: 0.85)
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(Offset(mx, my), 4.0, Paint()..color = Colors.white);
      }
    }

    // Draw 3D Friendly Capital Fleet (Alliance / Cyan)
    for (final ship in friendlies) {
      _draw3DBattlecruiser(
        canvas,
        Offset(ship.x * size.width + gyroX * 12, ship.y * size.height + gyroY * 6),
        0.85,
        const Color(0xFF00E5FF),
        isFriendly: true,
      );
    }

    // Draw 3D Enemy Dreadnought Fleet (Imperial / Red)
    for (final ship in enemies) {
      _draw3DBattlecruiser(
        canvas,
        Offset(ship.x * size.width + gyroX * 8, ship.y * size.height + gyroY * 4),
        0.80,
        const Color(0xFFFF2A4B),
        isFriendly: false,
      );
    }

    // Quad-Laser Salvos Exchanged Across Fleet
    final lRng = Random((explT * 150).toInt());
    if (lRng.nextDouble() > 0.3) {
      final fShip = friendlies[lRng.nextInt(friendlies.length)];
      final eShip = enemies[lRng.nextInt(enemies.length)];
      final sx = fShip.x * size.width + gyroX * 12 + 35;
      final sy = fShip.y * size.height + gyroY * 6;
      final ex = eShip.x * size.width + gyroX * 8 - 30;
      final ey = eShip.y * size.height + gyroY * 4;

      canvas.drawLine(
        Offset(sx, sy),
        Offset(ex, ey),
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    if (lRng.nextDouble() > 0.4) {
      final eShip = enemies[lRng.nextInt(enemies.length)];
      final fShip = friendlies[lRng.nextInt(friendlies.length)];
      final sx = eShip.x * size.width + gyroX * 8 - 30;
      final sy = eShip.y * size.height + gyroY * 4;
      final ex = fShip.x * size.width + gyroX * 12 + 35;
      final ey = fShip.y * size.height + gyroY * 6;

      canvas.drawLine(
        Offset(sx, sy),
        Offset(ex, ey),
        Paint()
          ..color = const Color(0xFFFF2A4B).withValues(alpha: 0.8)
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Touch Lock Targeting HUD
    if (touchPos != null) {
      canvas.drawCircle(
        touchPos!,
        32,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      final tpHud = TextPainter(
        text: const TextSpan(
          text: 'LOCK ACTIVE · TARGET LOCKED',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpHud.paint(canvas, Offset(touchPos!.dx - tpHud.width / 2, touchPos!.dy - 46));
    }

    // HUD Status
    final tpHud = TextPainter(
      text: const TextSpan(
        text: '3D FLEET ENGAGEMENT · SECTOR DEFENSE MATRIX',
        style: TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpHud.paint(canvas, Offset(size.width * 0.04, size.height * 0.06));

    final specTp = TextPainter(
      text: const TextSpan(
        text: 'ALLIANCE CARRIERS: 4  |  IMPERIAL BATTLECRUISERS: 5',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    specTp.paint(canvas, Offset(size.width * 0.04, size.height * 0.91));
  }

  void _draw3DBattlecruiser(Canvas canvas, Offset pos, double scale, Color col, {required bool isFriendly}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (!isFriendly) {
      canvas.scale(-scale, scale);
    } else {
      canvas.scale(scale, scale);
    }

    // 3D Upper Hull Wedge
    final upperPath = Path()
      ..moveTo(48, 0)
      ..lineTo(14, -14)
      ..lineTo(-34, -10)
      ..lineTo(-44, 0)
      ..lineTo(14, -3)
      ..close();
    canvas.drawPath(upperPath, Paint()..color = col.withValues(alpha: 0.95));

    // 3D Lower Hull (Ambient Shadow)
    final lowerPath = Path()
      ..moveTo(48, 0)
      ..lineTo(14, -3)
      ..lineTo(-44, 0)
      ..lineTo(-34, 12)
      ..lineTo(14, 15)
      ..close();
    canvas.drawPath(
      lowerPath,
      Paint()..color = Color.lerp(col, Colors.black, 0.45)!.withValues(alpha: 0.95),
    );

    // Armor Panels Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(upperPath, gridPaint);
    canvas.drawPath(lowerPath, gridPaint);

    // Ion Engines Thrust Glow
    final engGlow = Paint()
      ..color = col
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(const Offset(-42, -5), 5.5, engGlow);
    canvas.drawCircle(const Offset(-42, 5), 5.5, engGlow);
    canvas.drawCircle(const Offset(-42, -5), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(-42, 5), 2.5, Paint()..color = Colors.white);

    // Command Tower Bridge
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -18, 16, 12), const Radius.circular(2)),
      Paint()..color = col.withValues(alpha: 0.85),
    );
    canvas.drawLine(const Offset(-2, -12), const Offset(10, -12), Paint()..color = Colors.white..strokeWidth = 2.0);

    // Heavy Turbolaser Cannons
    canvas.drawLine(const Offset(32, -1), const Offset(55, -1), Paint()..color = Colors.white70..strokeWidth = 3.0..strokeCap = StrokeCap.square);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpaceBattlePainter old) => true;
}

// ============================================================
// Factory: Build animation widget by ID
// ============================================================
Widget buildSciFiAnimation(String id, {double gyroX = 0, double gyroY = 0}) {
  switch (id) {
    case 'terminator_endoskeleton': return TerminatorAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'iron_man_arc': return IronManAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'matrix_rain': return MatrixRainAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'lightsaber_duel': return LightsaberAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'xenomorph_shadow': return XenomorphAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'predator_cloak': return PredatorAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'optimus_transform': return OptimusAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'tron_grid': return TronGridAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'dune_sandworm': return DuneSandwormAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'interstellar_wormhole': return WormholeAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'avatar_banshee': return AvatarBansheeAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'robocop_hud': return RobocopHudAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'mandalorian_jetpack': return MandalorianAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'groot_growth': return GrootAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'exosuit_powerup': return ExosuitAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'fury_road_fire': return MadMaxAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'multipass_holo': return MultipassAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'blade_runner_spinner': return BladeRunnerAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'district9_mech': return District9Animation(gyroX: gyroX, gyroY: gyroY);
    case 'tesseract_cascade': return TesseractAnimation(gyroX: gyroX, gyroY: gyroY);
    // === NEW 5 GYRO SCI-FI ANIMATIONS ===
    case 'warship_beam_cannon': return WarshipBeamAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'shooting_stars_field': return ShootingStarsAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'alien_invasion_ship': return AlienInvasionAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'cosmic_zoom_bigbang': return CosmicZoomAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'space_battle_war': return SpaceBattleAnimation(gyroX: gyroX, gyroY: gyroY);
    // === CINEMATIC NEW ANIMATIONS ===
    case 'quantum_blackhole': return QuantumBlackHoleAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'cyberpunk_neon_rain': return CyberpunkNeonRainAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'galactic_nebula': return GalacticNebulaAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'time_warp_vortex': return TimeWarpVortexAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'nanobot_swarm': return NanobotSwarmAnimation(gyroX: gyroX, gyroY: gyroY);
    default: return const SizedBox.shrink();
  }
}

// ============================================================
// WIDGET 26: Quantum Black Hole Singularity
// ============================================================
class QuantumBlackHoleAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const QuantumBlackHoleAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<QuantumBlackHoleAnimation> createState() => _QuantumBlackHoleState();
}

class _QuantumBlackHoleState extends State<QuantumBlackHoleAnimation> with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _touchPos = d.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      onTapDown: (d) => setState(() => _touchPos = d.localPosition),
      onTapUp: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_spinCtrl, _pulseCtrl, _waveCtrl]),
        builder: (context, _) => CustomPaint(
          painter: _QuantumBlackHolePainter(
            spin: _spinCtrl.value,
            pulse: _pulseCtrl.value,
            wave: _waveCtrl.value,
            gyroX: widget.gyroX,
            gyroY: widget.gyroY,
            touchPos: _touchPos,
          ),
        ),
      ),
    );
  }
}

class _QuantumBlackHolePainter extends CustomPainter {
  final double spin;
  final double pulse;
  final double wave;
  final double gyroX;
  final double gyroY;
  final Offset? touchPos;

  const _QuantumBlackHolePainter({
    required this.spin, required this.pulse, required this.wave,
    required this.gyroX, required this.gyroY, this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + gyroX * 18, size.height / 2 + gyroY * 18);

    // Gravitational lensing rings
    for (int i = 0; i < 6; i++) {
      final r = 40.0 + i * 28.0 + (pulse * 12);
      final alpha = (0.85 - i * 0.12).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..color = Color.lerp(const Color(0xFF9C27B0), const Color(0xFF00E5FF), i / 6)!.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 - i * 0.3;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(spin * 2 * pi + i * 0.3);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.55), ringPaint);
      canvas.restore();
    }

    // Hawking radiation particles spiraling outward
    final rng = Random(42);
    for (int p = 0; p < 60; p++) {
      final angle = rng.nextDouble() * 2 * pi + spin * 4 * pi;
      final dist = 30.0 + rng.nextDouble() * 180 + ((wave + p * 0.017) % 1.0) * 80;
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist * 0.4;
      final particleAlpha = (1.0 - dist / 250).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(px, py), 1.5 + rng.nextDouble() * 2.5,
        Paint()..color = const Color(0xFFE040FB).withValues(alpha: particleAlpha * 0.9),
      );
    }

    // Singularity core — deep black with purple corona glow
    final coronaGlow = Paint()
      ..color = const Color(0xFF7B1FA2).withValues(alpha: 0.45 + pulse * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, 38 + pulse * 8, coronaGlow);

    final corePaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, 30, corePaint);

    // Jet beams shooting out from poles
    final jetPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF00E5FF).withValues(alpha: 0.8), Colors.transparent],
      ).createShader(Rect.fromCenter(center: center, width: 20, height: 200));
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy - 90), width: 8, height: 120), jetPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy + 90), width: 8, height: 120), jetPaint);

    // Touch distortion ripple
    if (touchPos != null) {
      for (int r = 1; r <= 3; r++) {
        canvas.drawCircle(
          touchPos!,
          r * 22.0 * (0.5 + pulse * 0.5),
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4 / r)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QuantumBlackHolePainter old) => true;
}

// ============================================================
// WIDGET 27: Cyberpunk City Neon Rain
// ============================================================
class CyberpunkNeonRainAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const CyberpunkNeonRainAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<CyberpunkNeonRainAnimation> createState() => _CyberpunkNeonRainState();
}

class _CyberpunkNeonRainState extends State<CyberpunkNeonRainAnimation> with TickerProviderStateMixin {
  late AnimationController _rainCtrl;
  late AnimationController _cityCtrl;
  late AnimationController _glitchCtrl;
  Offset? _touchPos;
  final List<_NeonDrop> _drops = [];

  @override
  void initState() {
    super.initState();
    _rainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _cityCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _glitchCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..repeat(reverse: true);
    final rng = Random(7);
    for (int i = 0; i < 55; i++) {
      _drops.add(_NeonDrop(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.4 + rng.nextDouble() * 0.6,
        length: 0.04 + rng.nextDouble() * 0.08,
        color: [
          const Color(0xFF00E5FF),
          const Color(0xFFB44FFF),
          const Color(0xFFFF2A6D),
          const Color(0xFF00FF88),
        ][rng.nextInt(4)],
      ));
    }
  }

  @override
  void dispose() {
    _rainCtrl.dispose();
    _cityCtrl.dispose();
    _glitchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _touchPos = d.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_rainCtrl, _cityCtrl, _glitchCtrl]),
        builder: (context, _) => CustomPaint(
          painter: _CyberpunkNeonRainPainter(
            rain: _rainCtrl.value,
            city: _cityCtrl.value,
            glitch: _glitchCtrl.value,
            drops: _drops,
            gyroX: widget.gyroX,
            gyroY: widget.gyroY,
            touchPos: _touchPos,
          ),
        ),
      ),
    );
  }
}

class _NeonDrop {
  double x, y, speed, length;
  Color color;
  _NeonDrop({required this.x, required this.y, required this.speed, required this.length, required this.color});
}

class _CyberpunkNeonRainPainter extends CustomPainter {
  final double rain;
  final double city;
  final double glitch;
  final List<_NeonDrop> drops;
  final double gyroX, gyroY;
  final Offset? touchPos;

  const _CyberpunkNeonRainPainter({
    required this.rain, required this.city, required this.glitch,
    required this.drops, required this.gyroX, required this.gyroY, this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dark neon city background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050014), Color(0xFF0A0020), Color(0xFF150030)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // City skyline silhouette
    final rng = Random(12);
    final skylinePaint = Paint()..color = const Color(0xFF0D0020);
    final groundY = h * 0.62;
    for (int b = 0; b < 16; b++) {
      final bx = (b / 16) * w + gyroX * 10;
      final bw = 18.0 + rng.nextDouble() * 30;
      final bh = 50.0 + rng.nextDouble() * (h * 0.35);
      canvas.drawRect(Rect.fromLTWH(bx, groundY - bh, bw, bh), skylinePaint);

      // Neon window lights
      for (int wy = 0; wy < 5; wy++) {
        for (int wx = 0; wx < 2; wx++) {
          if (rng.nextBool()) {
            final windowColor = [
              const Color(0xFF00E5FF), const Color(0xFFFF2A6D),
              const Color(0xFFFFD600), const Color(0xFFB44FFF),
            ][rng.nextInt(4)];
            canvas.drawRect(
              Rect.fromLTWH(bx + wx * 10 + 4, groundY - bh + wy * 18 + 10, 5, 5),
              Paint()..color = windowColor.withValues(alpha: 0.6 + city * 0.4),
            );
          }
        }
      }
    }

    // Neon rain streaks
    for (final drop in drops) {
      final dy = (drop.y + rain * drop.speed) % 1.0;
      final dx = drop.x * w + gyroX * 14;
      final startY = dy * h;
      final endY = (dy + drop.length) * h;
      canvas.drawLine(
        Offset(dx, startY),
        Offset(dx - 4, endY),
        Paint()
          ..color = drop.color.withValues(alpha: 0.8)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Glitch scan line
    if (glitch > 0.6) {
      final scanY = h * (glitch * 0.9);
      canvas.drawRect(
        Rect.fromLTWH(0, scanY, w, 3),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.25),
      );
    }

    // Ground neon reflection strip
    final reflectPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.4),
          const Color(0xFFB44FFF).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, groundY, w, 30));
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, 30), reflectPaint);

    // Touch neon splash
    if (touchPos != null) {
      for (int i = 1; i <= 4; i++) {
        canvas.drawCircle(
          touchPos!,
          i * 18.0,
          Paint()
            ..color = const Color(0xFFFF2A6D).withValues(alpha: 0.5 / i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberpunkNeonRainPainter old) => true;
}

// ============================================================
// WIDGET 28: Galactic Nebula Drift
// ============================================================
class GalacticNebulaAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const GalacticNebulaAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<GalacticNebulaAnimation> createState() => _GalacticNebulaState();
}

class _GalacticNebulaState extends State<GalacticNebulaAnimation> with TickerProviderStateMixin {
  late AnimationController _driftCtrl;
  late AnimationController _twinkleCtrl;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _twinkleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    _twinkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _touchPos = d.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_driftCtrl, _twinkleCtrl]),
        builder: (context, _) => CustomPaint(
          painter: _GalacticNebulaPainter(
            drift: _driftCtrl.value,
            twinkle: _twinkleCtrl.value,
            gyroX: widget.gyroX,
            gyroY: widget.gyroY,
            touchPos: _touchPos,
          ),
        ),
      ),
    );
  }
}

class _GalacticNebulaPainter extends CustomPainter {
  final double drift;
  final double twinkle;
  final double gyroX, gyroY;
  final Offset? touchPos;

  const _GalacticNebulaPainter({
    required this.drift, required this.twinkle,
    required this.gyroX, required this.gyroY, this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + gyroX * 20;
    final cy = size.height / 2 + gyroY * 20;

    // Deep space background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF01000A),
    );

    // Nebula cloud layers using radial gradients
    final nebulaColors = [
      [const Color(0xFF6A0DAD), const Color(0xFF1A0050)],
      [const Color(0xFF0D47A1), const Color(0xFF01000A)],
      [const Color(0xFF00695C), const Color(0xFF01000A)],
      [const Color(0xFFAD1457), const Color(0xFF01000A)],
    ];
    final offsets = [
      Offset(cx - 60 + drift * 30, cy - 40),
      Offset(cx + 50 - drift * 20, cy + 30),
      Offset(cx - 30, cy + 60 - drift * 25),
      Offset(cx + 40 + drift * 15, cy - 60),
    ];
    final radii = [180.0, 150.0, 130.0, 120.0];

    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        offsets[i],
        radii[i],
        Paint()
          ..shader = RadialGradient(
            colors: [nebulaColors[i][0].withValues(alpha: 0.35), nebulaColors[i][1].withValues(alpha: 0.0)],
          ).createShader(Rect.fromCircle(center: offsets[i], radius: radii[i]))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }

    // Star field
    final rng = Random(99);
    for (int s = 0; s < 120; s++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final sr = 0.5 + rng.nextDouble() * 1.8;
      final alpha = 0.4 + (twinkle * 0.6) * rng.nextDouble();
      canvas.drawCircle(Offset(sx, sy), sr, Paint()..color = Colors.white.withValues(alpha: alpha));
    }

    // Bright star cluster at center
    final clusterPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 + twinkle * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), 6, clusterPaint);

    // Shooting star
    final ssProgress = drift % 1.0;
    final ssX = size.width * (0.1 + ssProgress * 0.8);
    final ssY = size.height * (0.15 + ssProgress * 0.3);
    if (ssProgress < 0.4) {
      canvas.drawLine(
        Offset(ssX, ssY),
        Offset(ssX - 60, ssY - 20),
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white, Colors.transparent],
          ).createShader(Rect.fromLTWH(ssX - 60, ssY - 20, 60, 20))
          ..strokeWidth = 2.0,
      );
    }

    // Touch starburst
    if (touchPos != null) {
      for (int i = 0; i < 8; i++) {
        final angle = (i / 8) * 2 * pi + drift * pi;
        canvas.drawLine(
          touchPos!,
          Offset(touchPos!.dx + cos(angle) * 28, touchPos!.dy + sin(angle) * 28),
          Paint()
            ..color = const Color(0xFFFFD600).withValues(alpha: 0.8)
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalacticNebulaPainter old) => true;
}

// ============================================================
// WIDGET 29: Time Warp Vortex
// ============================================================
class TimeWarpVortexAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const TimeWarpVortexAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TimeWarpVortexAnimation> createState() => _TimeWarpVortexState();
}

class _TimeWarpVortexState extends State<TimeWarpVortexAnimation> with TickerProviderStateMixin {
  late AnimationController _vortexCtrl;
  late AnimationController _pulseCtrl;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _vortexCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _vortexCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _touchPos = d.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_vortexCtrl, _pulseCtrl]),
        builder: (context, _) => CustomPaint(
          painter: _TimeWarpVortexPainter(
            vortex: _vortexCtrl.value,
            pulse: _pulseCtrl.value,
            gyroX: widget.gyroX,
            gyroY: widget.gyroY,
            touchPos: _touchPos,
          ),
        ),
      ),
    );
  }
}

class _TimeWarpVortexPainter extends CustomPainter {
  final double vortex;
  final double pulse;
  final double gyroX, gyroY;
  final Offset? touchPos;

  const _TimeWarpVortexPainter({
    required this.vortex, required this.pulse,
    required this.gyroX, required this.gyroY, this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + gyroX * 15;
    final cy = size.height / 2 + gyroY * 15;
    final center = Offset(cx, cy);

    // Space-time background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000814),
    );

    // Vortex spiral arms — 24 concentric spiral segments
    for (int arm = 0; arm < 3; arm++) {
      final armOffset = arm * (2 * pi / 3);
      for (int seg = 0; seg < 24; seg++) {
        final t = seg / 24.0;
        final angle = vortex * 2 * pi * 3 + t * 2 * pi * 2 + armOffset;
        final radius = 15.0 + t * 160.0;
        final x = cx + cos(angle) * radius;
        final y = cy + sin(angle) * radius * 0.6;
        final alpha = (1.0 - t).clamp(0.0, 1.0);
        final color = Color.lerp(
          const Color(0xFF00E5FF),
          const Color(0xFFB44FFF),
          t,
        )!.withValues(alpha: alpha * 0.8);
        canvas.drawCircle(Offset(x, y), 3.5 - t * 2.5, Paint()..color = color);
      }
    }

    // Concentric distortion rings
    for (int r = 1; r <= 7; r++) {
      final ringR = r * 28.0 + pulse * 10;
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..color = const Color(0xFF4FC3F7).withValues(alpha: (0.5 - r * 0.05).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Core temporal rift
    final coreGlow = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5 + pulse * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, 14 + pulse * 6, coreGlow);

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, const Color(0xFF00E5FF), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: 18));
    canvas.drawCircle(center, 18, corePaint);

    // Time shockwave from touch
    if (touchPos != null) {
      for (int w = 1; w <= 5; w++) {
        canvas.drawCircle(
          touchPos!,
          w * 16.0 * (0.5 + pulse * 0.5),
          Paint()
            ..color = const Color(0xFF80DEEA).withValues(alpha: 0.5 / w)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimeWarpVortexPainter old) => true;
}

// ============================================================
// WIDGET 30: Nanobot Swarm Assembly
// ============================================================
class NanobotSwarmAnimation extends StatefulWidget {
  final double gyroX;
  final double gyroY;
  const NanobotSwarmAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<NanobotSwarmAnimation> createState() => _NanobotSwarmState();
}

class _NanobotSwarmState extends State<NanobotSwarmAnimation> with TickerProviderStateMixin {
  late AnimationController _assembleCtrl;
  late AnimationController _glowCtrl;
  Offset? _touchPos;
  late List<_Nanobot> _bots;

  @override
  void initState() {
    super.initState();
    _assembleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    final rng = Random(55);
    _bots = List.generate(80, (i) => _Nanobot(
      startX: rng.nextDouble(),
      startY: rng.nextDouble(),
      speed: 0.3 + rng.nextDouble() * 0.7,
      size: 2.0 + rng.nextDouble() * 3.5,
      angle: rng.nextDouble() * 2 * pi,
    ));
  }

  @override
  void dispose() {
    _assembleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _touchPos = d.localPosition),
      onPanEnd: (_) => setState(() => _touchPos = null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_assembleCtrl, _glowCtrl]),
        builder: (context, _) => CustomPaint(
          painter: _NanobotSwarmPainter(
            assemble: _assembleCtrl.value,
            glow: _glowCtrl.value,
            bots: _bots,
            gyroX: widget.gyroX,
            gyroY: widget.gyroY,
            touchPos: _touchPos,
          ),
        ),
      ),
    );
  }
}

class _Nanobot {
  final double startX, startY, speed, size, angle;
  _Nanobot({required this.startX, required this.startY, required this.speed, required this.size, required this.angle});
}

class _NanobotSwarmPainter extends CustomPainter {
  final double assemble;
  final double glow;
  final List<_Nanobot> bots;
  final double gyroX, gyroY;
  final Offset? touchPos;

  const _NanobotSwarmPainter({
    required this.assemble, required this.glow, required this.bots,
    required this.gyroX, required this.gyroY, this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2 + gyroX * 12;
    final cy = h / 2 + gyroY * 12;

    // Dark tech background grid
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF020C16),
    );
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (double gx = 0; gx < w; gx += 28) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, h), gridPaint);
    }
    for (double gy = 0; gy < h; gy += 28) {
      canvas.drawLine(Offset(0, gy), Offset(w, gy), gridPaint);
    }

    // Assemble phase: bots converge into NEX hexagon formation
    final assemblePhase = (sin(assemble * pi * 2) + 1) / 2; // 0→1→0 cycle

    for (int i = 0; i < bots.length; i++) {
      final bot = bots[i];
      // Target position: hexagon ring
      final hexAngle = (i / bots.length) * 2 * pi;
      final hexRadius = 90.0 + (i % 3) * 30.0;
      final targetX = cx + cos(hexAngle) * hexRadius;
      final targetY = cy + sin(hexAngle) * hexRadius * 0.7;

      // Random scatter position
      final scatterX = bot.startX * w;
      final scatterY = bot.startY * h;

      final bx = scatterX + (targetX - scatterX) * assemblePhase;
      final by = scatterY + (targetY - scatterY) * assemblePhase;

      // Draw connection lines when assembled
      if (assemblePhase > 0.6 && i < bots.length - 1) {
        canvas.drawLine(
          Offset(bx, by),
          Offset(
            cx + cos((i + 1) / bots.length * 2 * pi) * (90 + (i % 3) * 30),
            cy + sin((i + 1) / bots.length * 2 * pi) * (90 + (i % 3) * 30) * 0.7,
          ),
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.12 * assemblePhase)
            ..strokeWidth = 0.7,
        );
      }

      // Nanobot particle
      final botGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: (0.4 + glow * 0.4) * assemblePhase + 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bot.size * 1.5);
      canvas.drawCircle(Offset(bx, by), bot.size * 0.6, botGlow);
      canvas.drawCircle(Offset(bx, by), bot.size * 0.35, Paint()..color = const Color(0xFF80DEEA));
    }

    // Central assembly core
    final corePulse = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3 + glow * 0.4 * assemblePhase)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(cx, cy), 22 + glow * 8, corePulse);
    canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = Colors.white);

    // Touch repulsion burst
    if (touchPos != null) {
      canvas.drawCircle(
        touchPos!,
        40,
        Paint()
          ..color = const Color(0xFFFF2A6D).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NanobotSwarmPainter old) => true;
}

