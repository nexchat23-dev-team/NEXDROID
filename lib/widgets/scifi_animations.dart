import 'dart:math';
import 'package:flutter/material.dart';

// ============================================================================
// HARDWARE-ACCELERATED HIGH-PERFORMANCE 3D VECTOR MATH ENGINE
// ============================================================================

class _P3D {
  double x, y, z;
  _P3D(this.x, this.y, this.z);

  _P3D rotateX(double a) {
    final c = cos(a), s = sin(a);
    return _P3D(x, y * c - z * s, y * s + z * c);
  }

  _P3D rotateY(double a) {
    final c = cos(a), s = sin(a);
    return _P3D(x * c + z * s, y, -x * s + z * c);
  }

  _P3D rotateZ(double a) {
    final c = cos(a), s = sin(a);
    return _P3D(x * c - y * s, x * s + y * c, z);
  }

  Offset project(Offset center, {double focal = 360.0, double camDist = 420.0}) {
    final pz = z + camDist;
    final scale = focal / (pz <= 10.0 ? 10.0 : pz);
    return Offset(center.dx + x * scale, center.dy + y * scale);
  }

  double scaleFactor({double focal = 360.0, double camDist = 420.0}) {
    final pz = z + camDist;
    return focal / (pz <= 10.0 ? 10.0 : pz);
  }
}

void _draw3DLine(Canvas canvas, _P3D p1, _P3D p2, Offset center, Paint paint,
    {double rotX = 0, double rotY = 0, double rotZ = 0, double focal = 360.0, double camDist = 420.0}) {
  final r1 = p1.rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
  final r2 = p2.rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
  canvas.drawLine(
    r1.project(center, focal: focal, camDist: camDist),
    r2.project(center, focal: focal, camDist: camDist),
    paint,
  );
}

// ============================================================================
// WIDGET 1: Terminator Endoskeleton (True 3D Wireframe Skull & Laser Scanner)
// ============================================================================
class TerminatorAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const TerminatorAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TerminatorAnimation> createState() => _TerminatorAnimationState();
}

class _TerminatorAnimationState extends State<TerminatorAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0, _dragY = 0;

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
      onPanUpdate: (d) => setState(() {
        _dragX += d.delta.dx * 0.01;
        _dragY += d.delta.dy * 0.01;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _Terminator3DPainter(
            progress: _ctrl.value,
            rotX: widget.gyroY * 0.4 + _dragY,
            rotY: widget.gyroX * 0.4 + _dragX + sin(_ctrl.value * pi * 2) * 0.25,
          ),
        ),
      ),
    );
  }
}

class _Terminator3DPainter extends CustomPainter {
  final double progress, rotX, rotY;
  _Terminator3DPainter({required this.progress, required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF040000));

    // 3D Skull Geometry
    final chromePaint = Paint()
      ..color = const Color(0xFFFF2200).withValues(alpha: 0.85)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final dimPaint = Paint()
      ..color = const Color(0xFFFF2200).withValues(alpha: 0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Cranium rings
    for (double y = -80; y <= 40; y += 20) {
      final r = sqrt(max(0, 80 * 80 - y * y)) * 0.9;
      final pts = List.generate(16, (i) {
        final a = (i / 16) * pi * 2;
        return _P3D(cos(a) * r, y, sin(a) * r);
      });
      for (int i = 0; i < 16; i++) {
        _draw3DLine(canvas, pts[i], pts[(i + 1) % 16], center, dimPaint, rotX: rotX, rotY: rotY);
      }
    }

    // Jaw / Mandible 3D Box
    final jaw = [
      _P3D(-24, 60, 20), _P3D(24, 60, 20), _P3D(30, 60, -20), _P3D(-30, 60, -20),
      _P3D(-18, 90, 25), _P3D(18, 90, 25), _P3D(22, 90, -15), _P3D(-22, 90, -15),
    ];
    const jawEdges = [
      [0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]
    ];
    for (final e in jawEdges) {
      _draw3DLine(canvas, jaw[e[0]], jaw[e[1]], center, chromePaint, rotX: rotX, rotY: rotY);
    }

    // 3D Red Eyes (Ocular Nodes)
    final eyeLeft = _P3D(-22, -10, 55).rotateX(rotX).rotateY(rotY).project(center);
    final eyeRight = _P3D(22, -10, 55).rotateX(rotX).rotateY(rotY).project(center);

    final eyeGlow = Paint()..color = const Color(0xFFFF0000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(eyeLeft, 8, eyeGlow);
    canvas.drawCircle(eyeRight, 8, eyeGlow);
    canvas.drawCircle(eyeLeft, 3, Paint()..color = Colors.white);
    canvas.drawCircle(eyeRight, 3, Paint()..color = Colors.white);

    // 3D Laser Scanning Sweep Plane
    final scanY = center.dy + (progress * 2 - 1) * (size.height * 0.45);
    canvas.drawLine(
      Offset(0, scanY), Offset(size.width, scanY),
      Paint()..color = const Color(0xFFFF1100).withValues(alpha: 0.6)..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _Terminator3DPainter old) => true;
}

// ============================================================
// WIDGET 2: Iron Man Arc Reactor (3D Holographic Coils & Core)
// ============================================================
class IronManAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const IronManAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<IronManAnimation> createState() => _IronManAnimationState();
}

class _IronManAnimationState extends State<IronManAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0, _dragY = 0;

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
      onPanUpdate: (d) => setState(() {
        _dragX += d.delta.dx * 0.01;
        _dragY += d.delta.dy * 0.01;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _IronMan3DPainter(
            t: _ctrl.value,
            rotX: widget.gyroY * 0.5 + _dragY,
            rotY: widget.gyroX * 0.5 + _dragX + _ctrl.value * pi * 2,
          ),
        ),
      ),
    );
  }
}

class _IronMan3DPainter extends CustomPainter {
  final double t, rotX, rotY;
  _IronMan3DPainter({required this.t, required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010610));

    final cyanPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 1.4..style = PaintingStyle.stroke;
    final goldPaint = Paint()..color = const Color(0xFFFFD700)..strokeWidth = 1.8..style = PaintingStyle.stroke;

    // 10 3D Magnetic Copper Coils around Torus
    const coilCount = 10;
    for (int i = 0; i < coilCount; i++) {
      final a = (i / coilCount) * pi * 2;
      final cx = cos(a) * 90.0;
      final cy = sin(a) * 90.0;

      // 3D Prism for each coil
      final p1 = _P3D(cx - 8, cy - 8, -12);
      final p2 = _P3D(cx + 8, cy - 8, -12);
      final p3 = _P3D(cx + 8, cy + 8, -12);
      final p4 = _P3D(cx - 8, cy + 8, -12);
      final p5 = _P3D(cx - 6, cy - 6, 12);
      final p6 = _P3D(cx + 6, cy - 6, 12);
      final p7 = _P3D(cx + 6, cy + 6, 12);
      final p8 = _P3D(cx - 6, cy + 6, 12);

      const coilEdges = [
        [0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]
      ];
      for (final e in coilEdges) {
        final box = [p1, p2, p3, p4, p5, p6, p7, p8];
        _draw3DLine(canvas, box[e[0]], box[e[1]], center, goldPaint, rotX: rotX, rotY: rotY);
      }
    }

    // Inner 3D Counter-Rotating Rings
    for (int ring = 0; ring < 3; ring++) {
      final r = 40.0 + ring * 18.0;
      final pts = List.generate(24, (i) {
        final a = (i / 24) * pi * 2 + (ring.isEven ? t * 2 : -t * 2);
        return _P3D(cos(a) * r, sin(a) * r, (ring - 1) * 14.0);
      });
      for (int i = 0; i < 24; i++) {
        _draw3DLine(canvas, pts[i], pts[(i + 1) % 24], center, cyanPaint, rotX: rotX, rotY: rotY);
      }
    }

    // Glowing Central 3D Core
    final corePos = _P3D(0, 0, 0).rotateX(rotX).rotateY(rotY).project(center);
    canvas.drawCircle(corePos, 28, Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawCircle(corePos, 16, Paint()..color = const Color(0xFF00E5FF));
    canvas.drawCircle(corePos, 8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _IronMan3DPainter old) => true;
}

// ============================================================
// WIDGET 3: Matrix Digital Rain (KEPT AS 2D AS REQUESTED)
// ============================================================
class MatrixRainAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const MatrixRainAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MatrixRainAnimation> createState() => _MatrixRainAnimationState();
}

class _MatrixRainAnimationState extends State<MatrixRainAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<double> _drops = [];
  final Random _rnd = Random(1337);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    for (int i = 0; i < 40; i++) {
      _drops.add(_rnd.nextDouble() * 800.0);
    }
    _ctrl.addListener(() {
      for (int i = 0; i < _drops.length; i++) {
        _drops[i] += 6.0;
        if (_drops[i] > 900.0) _drops[i] = -_rnd.nextDouble() * 200.0;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MatrixRainPainter(drops: _drops, gyroX: widget.gyroX),
    );
  }
}

class _MatrixRainPainter extends CustomPainter {
  final List<double> drops;
  final double gyroX;
  _MatrixRainPainter({required this.drops, required this.gyroX});

  static const _chars = '日ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ0123456789';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000500));
    final colW = size.width / drops.length;

    for (int i = 0; i < drops.length; i++) {
      final x = i * colW + gyroX * 10;
      final y = drops[i];

      for (int j = 0; j < 12; j++) {
        final cy = y - j * 16;
        if (cy < -20 || cy > size.height + 20) continue;
        final alpha = (1.0 - j / 12.0).clamp(0.05, 1.0);
        final isHead = j == 0;
        final char = _chars[(i * 7 + j * 3) % _chars.length];

        final tp = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: isHead ? Colors.white : const Color(0xFF00FF41).withValues(alpha: alpha),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: isHead ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, cy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter old) => true;
}

// ============================================================
// WIDGET 4: Lightsaber Duel (3D Crossed Blades & Plasma Particles)
// ============================================================
class LightsaberAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const LightsaberAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<LightsaberAnimation> createState() => _LightsaberAnimationState();
}

class _LightsaberAnimationState extends State<LightsaberAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0, _dragY = 0;

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
      onPanUpdate: (d) => setState(() {
        _dragX += d.delta.dx * 0.01;
        _dragY += d.delta.dy * 0.01;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _Lightsaber3DPainter(
            t: _ctrl.value,
            rotX: widget.gyroY * 0.4 + _dragY,
            rotY: widget.gyroX * 0.4 + _dragX + sin(_ctrl.value * pi * 2) * 0.35,
          ),
        ),
      ),
    );
  }
}

class _Lightsaber3DPainter extends CustomPainter {
  final double t, rotX, rotY;
  _Lightsaber3DPainter({required this.t, required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF03030A));

    // Blade 1: Skywalker Blue in 3D
    final b1Hilt = _P3D(-120, 100, -40);
    final b1Tip = _P3D(80, -130, 40);

    // Blade 2: Sith Crimson Red in 3D
    final b2Hilt = _P3D(120, 100, 40);
    final b2Tip = _P3D(-80, -130, -40);

    // Draw Blue Blade
    final bluePaint = Paint()..color = const Color(0xFF0088FF)..strokeWidth = 8..strokeCap = StrokeCap.round;
    final blueCore = Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round;
    _draw3DLine(canvas, b1Hilt, b1Tip, center, bluePaint, rotX: rotX, rotY: rotY);
    _draw3DLine(canvas, b1Hilt, b1Tip, center, blueCore, rotX: rotX, rotY: rotY);

    // Draw Red Blade
    final redPaint = Paint()..color = const Color(0xFFFF1133)..strokeWidth = 8..strokeCap = StrokeCap.round;
    final redCore = Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round;
    _draw3DLine(canvas, b2Hilt, b2Tip, center, redPaint, rotX: rotX, rotY: rotY);
    _draw3DLine(canvas, b2Hilt, b2Tip, center, redCore, rotX: rotX, rotY: rotY);

    // 3D Clash Point Sparks
    final clashPoint = _P3D(0, -15, 0).rotateX(rotX).rotateY(rotY).project(center);
    final clashGlow = Paint()..color = const Color(0xFFFFD700)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(clashPoint, 20, clashGlow);
    canvas.drawCircle(clashPoint, 6, Paint()..color = Colors.white);

    // Radiating 3D Spark Lines
    final rng = Random(42);
    for (int i = 0; i < 20; i++) {
      final a = rng.nextDouble() * pi * 2;
      final dist = 20.0 + rng.nextDouble() * 50.0;
      final sp = _P3D(cos(a) * dist, -15 + sin(a) * dist, (rng.nextDouble() - 0.5) * 60);
      _draw3DLine(canvas, _P3D(0, -15, 0), sp, center, Paint()..color = const Color(0xFFFFEE55)..strokeWidth = 1.5, rotX: rotX, rotY: rotY);
    }
  }

  @override
  bool shouldRepaint(covariant _Lightsaber3DPainter old) => true;
}

// ============================================================
// WIDGET 5: Xenomorph Rising (3D Biomechanical Skull & Ribs)
// ============================================================
class XenomorphAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const XenomorphAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<XenomorphAnimation> createState() => _XenomorphAnimationState();
}

class _XenomorphAnimationState extends State<XenomorphAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0, _dragY = 0;

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() {
        _dragX += d.delta.dx * 0.01;
        _dragY += d.delta.dy * 0.01;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _Xenomorph3DPainter(
            t: _ctrl.value,
            rotX: widget.gyroY * 0.4 + _dragY,
            rotY: widget.gyroX * 0.4 + _dragX + sin(_ctrl.value * pi) * 0.25,
          ),
        ),
      ),
    );
  }
}

class _Xenomorph3DPainter extends CustomPainter {
  final double t, rotX, rotY;
  _Xenomorph3DPainter({required this.t, required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010602));

    final bioPaint = Paint()..color = const Color(0xFF00FF66).withValues(alpha: 0.8)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final acidPaint = Paint()..color = const Color(0xFF76FF03)..strokeWidth = 2.0;

    // 3D Elongated Biomechanical Cranium (Series of receding rings)
    for (int i = 0; i < 18; i++) {
      final z = -120.0 + i * 16.0;
      final w = 20.0 + sin(i / 18 * pi) * 35.0;
      final h = 18.0 + sin(i / 18 * pi) * 28.0;

      final p1 = _P3D(-w, -h, z);
      final p2 = _P3D(w, -h, z);
      final p3 = _P3D(w * 0.7, h, z);
      final p4 = _P3D(-w * 0.7, h, z);

      final pts = [p1, p2, p3, p4];
      for (int k = 0; k < 4; k++) {
        _draw3DLine(canvas, pts[k], pts[(k + 1) % 4], center, bioPaint, rotX: rotX, rotY: rotY);
      }
    }

    // 3D Secondary Inner Pharyngeal Jaw Extension
    final jawExtend = t * 40.0;
    final innerJaw = [
      _P3D(-8, 10, 100 + jawExtend), _P3D(8, 10, 100 + jawExtend),
      _P3D(8, 25, 100 + jawExtend), _P3D(-8, 25, 100 + jawExtend),
      _P3D(-6, 12, 130 + jawExtend), _P3D(6, 12, 130 + jawExtend),
      _P3D(6, 22, 130 + jawExtend), _P3D(-6, 22, 130 + jawExtend),
    ];
    const jawEdges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
    for (final e in jawEdges) {
      _draw3DLine(canvas, innerJaw[e[0]], innerJaw[e[1]], center, acidPaint, rotX: rotX, rotY: rotY);
    }
  }

  @override
  bool shouldRepaint(covariant _Xenomorph3DPainter old) => true;
}

// ============================================================
// WIDGET 6: Predator Cloak & HUD (3D Targeting Sphere & Tri-Laser)
// ============================================================
class PredatorAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const PredatorAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<PredatorAnimation> createState() => _PredatorAnimationState();
}

class _PredatorAnimationState extends State<PredatorAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0, _dragY = 0;

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
      onPanUpdate: (d) => setState(() {
        _dragX += d.delta.dx * 0.01;
        _dragY += d.delta.dy * 0.01;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _Predator3DPainter(
            t: _ctrl.value,
            rotX: widget.gyroY * 0.5 + _dragY,
            rotY: widget.gyroX * 0.5 + _dragX + _ctrl.value * pi * 2,
          ),
        ),
      ),
    );
  }
}

class _Predator3DPainter extends CustomPainter {
  final double t, rotX, rotY;
  _Predator3DPainter({required this.t, required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF030101));

    // 3D Spherical Coordinate Wireframe Cage
    final spherePaint = Paint()..color = const Color(0xFFFF1100).withValues(alpha: 0.35)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    for (double lat = -pi / 2; lat <= pi / 2; lat += pi / 6) {
      final r = cos(lat) * 110.0;
      final y = sin(lat) * 110.0;
      final pts = List.generate(24, (i) {
        final a = (i / 24) * pi * 2;
        return _P3D(cos(a) * r, y, sin(a) * r);
      });
      for (int i = 0; i < 24; i++) {
        _draw3DLine(canvas, pts[i], pts[(i + 1) % 24], center, spherePaint, rotX: rotX, rotY: rotY);
      }
    }

    // Iconic 3-Dot Triangular Tri-Laser Target
    const triR = 24.0;
    final dot1 = _P3D(0, -triR, 120).rotateX(rotX).rotateY(rotY).project(center);
    final dot2 = _P3D(-triR * 0.866, triR * 0.5, 120).rotateX(rotX).rotateY(rotY).project(center);
    final dot3 = _P3D(triR * 0.866, triR * 0.5, 120).rotateX(rotX).rotateY(rotY).project(center);

    final laserPaint = Paint()..color = const Color(0xFFFF0000);
    final glow = Paint()..color = const Color(0xFFFF0000).withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (final d in [dot1, dot2, dot3]) {
      canvas.drawCircle(d, 6, glow);
      canvas.drawCircle(d, 2.5, laserPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Predator3DPainter old) => true;
}

// ============================================================
// WIDGET 7: Optimus Matrix of Leadership (3D Energon Polyhedron)
// ============================================================
class OptimusAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const OptimusAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<OptimusAnimation> createState() => _OptimusAnimationState();
}

class _OptimusAnimationState extends State<OptimusAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0, _dragY = 0;

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
      onPanUpdate: (d) => setState(() {
        _dragX += d.delta.dx * 0.01;
        _dragY += d.delta.dy * 0.01;
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _Optimus3DPainter(
            t: _ctrl.value,
            rotX: widget.gyroY * 0.4 + _dragY,
            rotY: widget.gyroX * 0.4 + _dragX + _ctrl.value * pi * 2,
          ),
        ),
      ),
    );
  }
}

class _Optimus3DPainter extends CustomPainter {
  final double t, rotX, rotY;
  _Optimus3DPainter({required this.t, required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000814));

    final goldPaint = Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final bluePaint = Paint()..color = const Color(0xFF00BFFF)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    // 3D Matrix Outer Shell Handles
    for (int side = -1; side <= 1; side += 2) {
      final pts = [
        _P3D(side * 60.0, -30, 0), _P3D(side * 110.0, -20, 10),
        _P3D(side * 120.0, 0, 0), _P3D(side * 110.0, 20, -10),
        _P3D(side * 60.0, 30, 0),
      ];
      for (int i = 0; i < 4; i++) {
        _draw3DLine(canvas, pts[i], pts[i + 1], center, goldPaint, rotX: rotX, rotY: rotY);
      }
    }

    // Central 3D Rotating Crystal (Double Pyramidal Octahedron)
    const s = 45.0;
    final crystal = [
      _P3D(0, -s * 1.3, 0), _P3D(s, 0, 0), _P3D(0, 0, s), _P3D(-s, 0, 0), _P3D(0, 0, -s), _P3D(0, s * 1.3, 0)
    ];
    const edges = [[0,1],[0,2],[0,3],[0,4],[5,1],[5,2],[5,3],[5,4],[1,2],[2,3],[3,4],[4,1]];
    for (final e in edges) {
      _draw3DLine(canvas, crystal[e[0]], crystal[e[1]], center, bluePaint, rotX: rotX * 1.2, rotY: rotY * 1.5);
    }

    // Pure Energon Radiant Core
    final core = _P3D(0, 0, 0).project(center);
    canvas.drawCircle(core, 24, Paint()..color = const Color(0xFF00BFFF).withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(core, 8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _Optimus3DPainter old) => true;
}

// ============================================================
// WIDGET 8: TRON Grid Lightcycle (3D Infinite Grid & Vehicle)
// ============================================================
class TronGridAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const TronGridAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TronGridAnimation> createState() => _TronGridAnimationState();
}

class _TronGridAnimationState extends State<TronGridAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Tron3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Tron3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Tron3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + gyroX * 14, size.height * 0.42 + gyroY * 14);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020914));

    final cyanPaint = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)..strokeWidth = 1.0;

    // 3D Receding Floor Grid
    for (double x = -400; x <= 400; x += 50) {
      _draw3DLine(canvas, _P3D(x, 120, 20), _P3D(x, 120, 800), center, cyanPaint);
    }
    for (int zIdx = 0; zIdx < 16; zIdx++) {
      final z = ((zIdx + t) % 16) * 50.0 + 20.0;
      _draw3DLine(canvas, _P3D(-400, 120, z), _P3D(400, 120, z), center, cyanPaint);
    }

    // 3D Lightcycle Wireframe Chassis
    final bikeCenter = Offset(size.width / 2, size.height * 0.68);
    final bikePaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final bikePoints = [
      _P3D(-14, 0, 30), _P3D(14, 0, 30), _P3D(18, -12, -20), _P3D(-18, -12, -20),
      _P3D(-10, -22, -10), _P3D(10, -22, -10),
    ];
    const bikeEdges = [[0,1],[1,2],[2,3],[3,0],[0,4],[1,5],[4,5],[2,5],[3,4]];
    for (final e in bikeEdges) {
      _draw3DLine(canvas, bikePoints[e[0]], bikePoints[e[1]], bikeCenter, bikePaint);
    }

    // Trailing 3D Neon Wall
    canvas.drawLine(
      bikeCenter + const Offset(0, -5),
      Offset(size.width / 2, size.height),
      Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 4.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _Tron3DPainter old) => true;
}

// ============================================================
// WIDGET 9: Dune Sandworm (3D Serpentine Undulating Segment Body)
// ============================================================
class DuneSandwormAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const DuneSandwormAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<DuneSandwormAnimation> createState() => _DuneSandwormAnimationState();
}

class _DuneSandwormAnimationState extends State<DuneSandwormAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _DuneSandworm3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _DuneSandworm3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _DuneSandworm3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF160A00));

    final wormPaint = Paint()..color = const Color(0xFFFF9900).withValues(alpha: 0.75)..strokeWidth = 1.6..style = PaintingStyle.stroke;
    final teethPaint = Paint()..color = const Color(0xFF33CCFF)..strokeWidth = 1.2;

    // 16 Undulating 3D Segment Rings
    const segCount = 16;
    for (int i = 0; i < segCount; i++) {
      final z = i * 28.0;
      final waveX = sin(t * pi * 2 + i * 0.4) * 40.0;
      final waveY = cos(t * pi * 2 + i * 0.4) * 20.0;
      final r = (1.0 - i / segCount * 0.6) * 75.0;

      final pts = List.generate(12, (k) {
        final a = (k / 12) * pi * 2;
        return _P3D(waveX + cos(a) * r, waveY + sin(a) * r, z);
      });
      for (int k = 0; k < 12; k++) {
        _draw3DLine(canvas, pts[k], pts[(k + 1) % 12], center, wormPaint, rotX: gyroY * 0.3, rotY: gyroX * 0.3);
      }
    }

    // Maw Crystalline Teeth (Front Ring)
    final frontWaveX = sin(t * pi * 2) * 40.0;
    final frontWaveY = cos(t * pi * 2) * 20.0;
    for (int k = 0; k < 8; k++) {
      final a = (k / 8) * pi * 2;
      final p1 = _P3D(frontWaveX + cos(a) * 75.0, frontWaveY + sin(a) * 75.0, 0);
      final p2 = _P3D(frontWaveX + cos(a) * 35.0, frontWaveY + sin(a) * 35.0, 20);
      _draw3DLine(canvas, p1, p2, center, teethPaint, rotX: gyroY * 0.3, rotY: gyroX * 0.3);
    }
  }

  @override
  bool shouldRepaint(covariant _DuneSandworm3DPainter old) => true;
}

// ============================================================
// WIDGET 10: Gargantua Accretion Disk / Wormhole (3D Relativistic Physics)
// ============================================================
class WormholeAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const WormholeAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<WormholeAnimation> createState() => _WormholeAnimationState();
}

class _WormholeAnimationState extends State<WormholeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Wormhole3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Wormhole3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Wormhole3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020005));

    final diskPaint = Paint()..strokeWidth = 1.4..style = PaintingStyle.stroke;

    // Relativistic Tilted 3D Accretion Rings
    for (int ring = 0; ring < 12; ring++) {
      final r = 60.0 + ring * 12.0;
      final alpha = (1.0 - ring / 12.0).clamp(0.1, 0.9);
      diskPaint.color = const Color(0xFFFFCC00).withValues(alpha: alpha);

      final pts = List.generate(32, (i) {
        final a = (i / 32) * pi * 2 + t * (2.0 - ring * 0.1);
        return _P3D(cos(a) * r, sin(a) * r * 0.35, sin(a) * r * 0.85);
      });
      for (int i = 0; i < 32; i++) {
        _draw3DLine(canvas, pts[i], pts[(i + 1) % 32], center, diskPaint, rotX: 0.35 + gyroY * 0.2, rotY: gyroX * 0.2);
      }
    }

    // Black Hole Event Horizon (Central Void)
    canvas.drawCircle(center, 42, Paint()..color = Colors.black);
    canvas.drawCircle(center, 44, Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 2.0);
  }

  @override
  bool shouldRepaint(covariant _Wormhole3DPainter old) => true;
}

// ============================================================
// WIDGET 11: Avatar Banshee (3D Articulated Flying Wings)
// ============================================================
class AvatarBansheeAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const AvatarBansheeAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<AvatarBansheeAnimation> createState() => _AvatarBansheeAnimationState();
}

class _AvatarBansheeAnimationState extends State<AvatarBansheeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Banshee3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Banshee3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Banshee3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000810));

    final wingFlap = sin(t * pi * 2) * 35.0;
    final cyanBio = Paint()..color = const Color(0xFF00FFCC)..strokeWidth = 2.0..style = PaintingStyle.stroke;

    // 3D Banshee Body & Wings
    final nose = _P3D(0, -20, 60);
    final tail = _P3D(0, 30, -60);
    final leftTip = _P3D(-140, wingFlap, 0);
    final rightTip = _P3D(140, wingFlap, 0);

    final skeleton = [
      [nose, tail],
      [nose, leftTip],
      [leftTip, tail],
      [nose, rightTip],
      [rightTip, tail],
    ];
    for (final pair in skeleton) {
      _draw3DLine(canvas, pair[0], pair[1], center, cyanBio, rotX: gyroY * 0.4, rotY: gyroX * 0.4);
    }
  }

  @override
  bool shouldRepaint(covariant _Banshee3DPainter old) => true;
}

// ============================================================
// WIDGET 12: RoboCop HUD (3D Target Prisms & Depth Compass)
// ============================================================
class RobocopHudAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const RobocopHudAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<RobocopHudAnimation> createState() => _RobocopHudAnimationState();
}

class _RobocopHudAnimationState extends State<RobocopHudAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Robocop3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Robocop3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Robocop3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000800));

    final ocpGreen = Paint()..color = const Color(0xFF00FF44)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    // 3D Target Acquisition Box Rotating in Perspective
    const s = 45.0;
    final box = [
      _P3D(-s, -s, -s), _P3D(s, -s, -s), _P3D(s, s, -s), _P3D(-s, s, -s),
      _P3D(-s, -s, s), _P3D(s, -s, s), _P3D(s, s, s), _P3D(-s, s, s)
    ];
    const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
    for (final e in edges) {
      _draw3DLine(canvas, box[e[0]], box[e[1]], center, ocpGreen, rotX: gyroY * 0.4, rotY: t * pi * 2 + gyroX * 0.4);
    }

    // Telemetry Crossbars
    canvas.drawLine(Offset(center.dx - 120, center.dy), Offset(center.dx + 120, center.dy), Paint()..color = const Color(0xFF00FF44).withValues(alpha: 0.3));
    canvas.drawLine(Offset(center.dx, center.dy - 120), Offset(center.dx, center.dy + 120), Paint()..color = const Color(0xFF00FF44).withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant _Robocop3DPainter old) => true;
}

// ============================================================
// WIDGET 13: Mandalorian Beskar Jetpack (3D Ingot & Conical Thrusters)
// ============================================================
class MandalorianAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const MandalorianAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MandalorianAnimation> createState() => _MandalorianAnimationState();
}

class _MandalorianAnimationState extends State<MandalorianAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Mandalorian3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Mandalorian3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Mandalorian3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF0A0802));

    final beskarPaint = Paint()..color = const Color(0xFFB0C4DE)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final flamePaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 3.0;

    // 3D Beskar Ingot Box
    final ingot = [
      _P3D(-50, -30, -15), _P3D(50, -30, -15), _P3D(50, 30, -15), _P3D(-50, 30, -15),
      _P3D(-40, -25, 15), _P3D(40, -25, 15), _P3D(40, 25, 15), _P3D(-40, 25, 15),
    ];
    const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
    for (final e in edges) {
      _draw3DLine(canvas, ingot[e[0]], ingot[e[1]], center, beskarPaint, rotX: gyroY * 0.4, rotY: t * pi * 2 + gyroX * 0.4);
    }

    // 3D Conical Blue Thruster Exhaust Flames
    final leftJet = _P3D(-35, 30, 0);
    final rightJet = _P3D(35, 30, 0);
    final flameTip1 = _P3D(-35, 90 + sin(t * pi * 8) * 15, 0);
    final flameTip2 = _P3D(35, 90 + cos(t * pi * 8) * 15, 0);

    _draw3DLine(canvas, leftJet, flameTip1, center, flamePaint, rotX: gyroY * 0.4, rotY: gyroX * 0.4);
    _draw3DLine(canvas, rightJet, flameTip2, center, flamePaint, rotX: gyroY * 0.4, rotY: gyroX * 0.4);
  }

  @override
  bool shouldRepaint(covariant _Mandalorian3DPainter old) => true;
}

// ============================================================
// WIDGET 14: Groot Cosmic Spores (3D Double Helix Flora)
// ============================================================
class GrootAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const GrootAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<GrootAnimation> createState() => _GrootAnimationState();
}

class _GrootAnimationState extends State<GrootAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Groot3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Groot3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Groot3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF030700));

    final vinePaint = Paint()..color = const Color(0xFF76FF03)..strokeWidth = 1.8..style = PaintingStyle.stroke;
    final sporePaint = Paint()..color = const Color(0xFFCCFF00);

    // 3D Double Helix Branch Twisting in Perspective
    for (int strand = 0; strand < 2; strand++) {
      final offset = strand * pi;
      for (double y = -140; y <= 140; y += 10) {
        final a = y * 0.04 + t * pi * 2 + offset;
        final p = _P3D(cos(a) * 45.0, y, sin(a) * 45.0);
        final proj = p.rotateX(gyroY * 0.3).rotateY(gyroX * 0.3).project(center);
        canvas.drawCircle(proj, 3.5, vinePaint);

        // Spores orbiting in 3D
        if (y.toInt() % 20 == 0) {
          final sp = _P3D(cos(a + 1.2) * 75.0, y + sin(t * pi * 4) * 8, sin(a + 1.2) * 75.0);
          final spProj = sp.rotateX(gyroY * 0.3).rotateY(gyroX * 0.3).project(center);
          canvas.drawCircle(spProj, 2.5, sporePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Groot3DPainter old) => true;
}

// ============================================================
// WIDGET 15: Valkyrie Exosuit (3D Actuator Framework)
// ============================================================
class ExosuitAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const ExosuitAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<ExosuitAnimation> createState() => _ExosuitAnimationState();
}

class _ExosuitAnimationState extends State<ExosuitAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Exosuit3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Exosuit3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Exosuit3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF0A0400));

    final orangePaint = Paint()..color = const Color(0xFFFF6600)..strokeWidth = 2.0..style = PaintingStyle.stroke;

    // 3D Spinal Column Actuators
    for (double y = -100; y <= 100; y += 25) {
      final box = [
        _P3D(-25, y - 8, -15), _P3D(25, y - 8, -15), _P3D(25, y + 8, -15), _P3D(-25, y + 8, -15),
        _P3D(-20, y - 6, 15), _P3D(20, y - 6, 15), _P3D(20, y + 6, 15), _P3D(-20, y + 6, 15),
      ];
      const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
      for (final e in edges) {
        _draw3DLine(canvas, box[e[0]], box[e[1]], center, orangePaint, rotX: gyroY * 0.3, rotY: t * pi * 2 + gyroX * 0.3);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Exosuit3DPainter old) => true;
}

// ============================================================
// WIDGET 16: Doof Wagon Fire Storm (Mad Max 3D Exhaust Pipes)
// ============================================================
class MadMaxAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const MadMaxAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MadMaxAnimation> createState() => _MadMaxAnimationState();
}

class _MadMaxAnimationState extends State<MadMaxAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _MadMax3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _MadMax3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _MadMax3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF140200));

    final exhaustPaint = Paint()..color = const Color(0xFFFF5500)..strokeWidth = 2.5;

    // Dual 3D Angled Exhaust Tubes
    for (int side = -1; side <= 1; side += 2) {
      final base = _P3D(side * 50.0, 40, 0);
      final tip = _P3D(side * 70.0, -80, 20);
      _draw3DLine(canvas, base, tip, center, exhaustPaint, rotX: gyroY * 0.3, rotY: gyroX * 0.3);

      // 3D Fire Blast Particles
      for (int i = 0; i < 15; i++) {
        final flameY = -80.0 - i * 14.0 - t * 40.0;
        final flameP = _P3D(side * 70.0 + sin(t * pi * 8 + i) * 12.0, flameY, (i % 3) * 15.0);
        final proj = flameP.rotateX(gyroY * 0.3).rotateY(gyroX * 0.3).project(center);
        canvas.drawCircle(proj, max(2, (15 - i) * 1.5), Paint()..color = const Color(0xFFFF2200).withValues(alpha: 0.8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MadMax3DPainter old) => true;
}

// ============================================================
// WIDGET 17: MultiPass Holo (Fifth Element 3D Rotating ID Card)
// ============================================================
class MultipassAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const MultipassAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<MultipassAnimation> createState() => _MultipassAnimationState();
}

class _MultipassAnimationState extends State<MultipassAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Multipass3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Multipass3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Multipass3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010814));

    final holoPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 1.8..style = PaintingStyle.stroke;
    final yellowPaint = Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.0..style = PaintingStyle.stroke;

    // 3D Card Polyhedron
    final card = [
      _P3D(-70, -45, -4), _P3D(70, -45, -4), _P3D(70, 45, -4), _P3D(-70, 45, -4),
      _P3D(-70, -45, 4), _P3D(70, -45, 4), _P3D(70, 45, 4), _P3D(-70, 45, 4),
    ];
    const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
    for (final e in edges) {
      _draw3DLine(canvas, card[e[0]], card[e[1]], center, yellowPaint, rotX: gyroY * 0.4 + sin(t * pi * 2) * 0.3, rotY: t * pi * 2 + gyroX * 0.4);
    }

    // Photo Box & Holographic Text lines on 3D Card
    final pPhoto1 = _P3D(-50, -25, 4);
    final pPhoto2 = _P3D(-15, 25, 4);
    _draw3DLine(canvas, pPhoto1, _P3D(-15, -25, 4), center, holoPaint, rotX: gyroY * 0.4 + sin(t * pi * 2) * 0.3, rotY: t * pi * 2 + gyroX * 0.4);
    _draw3DLine(canvas, _P3D(-15, -25, 4), pPhoto2, center, holoPaint, rotX: gyroY * 0.4 + sin(t * pi * 2) * 0.3, rotY: t * pi * 2 + gyroX * 0.4);
  }

  @override
  bool shouldRepaint(covariant _Multipass3DPainter old) => true;
}

// ============================================================
// WIDGET 18: Blade Runner Spinner (3D Flying Police Car Wireframe)
// ============================================================
class BladeRunnerAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const BladeRunnerAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<BladeRunnerAnimation> createState() => _BladeRunnerAnimationState();
}

class _BladeRunnerAnimationState extends State<BladeRunnerAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _BladeRunner3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _BladeRunner3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _BladeRunner3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF030510));

    final spinnerPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 1.6..style = PaintingStyle.stroke;

    // 3D Police Spinner Hull
    final hull = [
      _P3D(0, -10, 60), _P3D(-45, -5, -40), _P3D(45, -5, -40), // Top tri
      _P3D(0, 15, 50), _P3D(-40, 15, -40), _P3D(40, 15, -40), // Bottom tri
      _P3D(-15, -25, 0), _P3D(15, -25, 0), // Cabin roof
    ];
    const edges = [[0,1],[1,2],[2,0],[3,4],[4,5],[5,3],[0,3],[1,4],[2,5],[6,7],[0,6],[0,7],[1,6],[2,7]];
    for (final e in edges) {
      _draw3DLine(canvas, hull[e[0]], hull[e[1]], center, spinnerPaint, rotX: 0.2 + gyroY * 0.3, rotY: sin(t * pi * 2) * 0.5 + gyroX * 0.3);
    }
  }

  @override
  bool shouldRepaint(covariant _BladeRunner3DPainter old) => true;
}

// ============================================================
// WIDGET 19: District 9 Mech (3D Alien Exosuit Chassis)
// ============================================================
class District9Animation extends StatefulWidget {
  final double gyroX, gyroY;
  const District9Animation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<District9Animation> createState() => _District9AnimationState();
}

class _District9AnimationState extends State<District9Animation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _District93DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _District93DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _District93DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF080603));

    final mechPaint = Paint()..color = const Color(0xFFFF9900)..strokeWidth = 1.8..style = PaintingStyle.stroke;

    // 3D Mech Cockpit Dome & Torso
    final torso = [
      _P3D(-40, -40, -30), _P3D(40, -40, -30), _P3D(35, 40, -20), _P3D(-35, 40, -20),
      _P3D(-30, -35, 30), _P3D(30, -35, 30), _P3D(25, 35, 20), _P3D(-25, 35, 20),
    ];
    const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
    for (final e in edges) {
      _draw3DLine(canvas, torso[e[0]], torso[e[1]], center, mechPaint, rotX: gyroY * 0.3, rotY: sin(t * pi * 2) * 0.4 + gyroX * 0.3);
    }
  }

  @override
  bool shouldRepaint(covariant _District93DPainter old) => true;
}

// ============================================================
// WIDGET 20: Tesseract 4D-to-3D Hypercube
// ============================================================
class TesseractAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const TesseractAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TesseractAnimation> createState() => _TesseractAnimationState();
}

class _TesseractAnimationState extends State<TesseractAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Tesseract3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Tesseract3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Tesseract3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020412));

    final hyperPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final innerPaint = Paint()..color = const Color(0xFF8B5CF6)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    // 4D Hypercube projected to dual 3D nested cubes
    const s1 = 80.0;
    const s2 = 40.0;

    final outer = [
      _P3D(-s1, -s1, -s1), _P3D(s1, -s1, -s1), _P3D(s1, s1, -s1), _P3D(-s1, s1, -s1),
      _P3D(-s1, -s1, s1), _P3D(s1, -s1, s1), _P3D(s1, s1, s1), _P3D(-s1, s1, s1),
    ];
    final inner = [
      _P3D(-s2, -s2, -s2), _P3D(s2, -s2, -s2), _P3D(s2, s2, -s2), _P3D(-s2, s2, -s2),
      _P3D(-s2, -s2, s2), _P3D(s2, -s2, s2), _P3D(s2, s2, s2), _P3D(-s2, s2, s2),
    ];

    const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
    for (final e in edges) {
      _draw3DLine(canvas, outer[e[0]], outer[e[1]], center, hyperPaint, rotX: t * pi * 2 + gyroY * 0.3, rotY: t * pi * 2 + gyroX * 0.3);
      _draw3DLine(canvas, inner[e[0]], inner[e[1]], center, innerPaint, rotX: t * pi * 2 + gyroY * 0.3, rotY: t * pi * 2 + gyroX * 0.3);
      _draw3DLine(canvas, outer[e[0]], inner[e[0]], center, Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 0.8, rotX: t * pi * 2 + gyroY * 0.3, rotY: t * pi * 2 + gyroX * 0.3);
    }
  }

  @override
  bool shouldRepaint(covariant _Tesseract3DPainter old) => true;
}

// ============================================================
// WIDGET 21: Warship Beam Cannon (3D Battlecruiser & Laser)
// ============================================================
class WarshipBeamAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const WarshipBeamAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<WarshipBeamAnimation> createState() => _WarshipBeamAnimationState();
}

class _WarshipBeamAnimationState extends State<WarshipBeamAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _Warship3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _Warship3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _Warship3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020610));

    final shipPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2.0..style = PaintingStyle.stroke;

    // 3D Battlecruiser Nose & Conduits
    final bow = _P3D(0, 0, 100);
    final pLeft = _P3D(-70, -20, -50);
    final pRight = _P3D(70, -20, -50);
    final pTop = _P3D(0, -50, -30);

    final shipEdges = [[bow, pLeft], [bow, pRight], [bow, pTop], [pLeft, pRight], [pLeft, pTop], [pRight, pTop]];
    for (final pair in shipEdges) {
      _draw3DLine(canvas, pair[0], pair[1], center, shipPaint, rotX: gyroY * 0.3, rotY: gyroX * 0.3);
    }

    // Converging 3D Giant Beam Cannon
    final beamStart = bow.rotateX(gyroY * 0.3).rotateY(gyroX * 0.3).project(center);
    canvas.drawLine(
      beamStart,
      Offset(size.width / 2, size.height),
      Paint()..color = const Color(0xFF00FF66)..strokeWidth = 14.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawLine(
      beamStart,
      Offset(size.width / 2, size.height),
      Paint()..color = Colors.white..strokeWidth = 4.0,
    );
  }

  @override
  bool shouldRepaint(covariant _Warship3DPainter old) => true;
}

// ============================================================
// WIDGET 22: Shooting Stars Field (3D Warp Velocity Stream)
// ============================================================
class ShootingStarsAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const ShootingStarsAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<ShootingStarsAnimation> createState() => _ShootingStarsAnimationState();
}

class _ShootingStarsAnimationState extends State<ShootingStarsAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_P3D> _stars = [];
  final Random _rnd = Random(99);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    for (int i = 0; i < 120; i++) {
      _stars.add(_P3D((_rnd.nextDouble() - 0.5) * 800, (_rnd.nextDouble() - 0.5) * 800, _rnd.nextDouble() * 800));
    }
    _ctrl.addListener(() {
      for (final s in _stars) {
        s.z -= 18.0;
        if (s.z < 20.0) s.z = 800.0;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Stars3DPainter(stars: _stars, gyroX: widget.gyroX, gyroY: widget.gyroY),
    );
  }
}

class _Stars3DPainter extends CustomPainter {
  final List<_P3D> stars;
  final double gyroX, gyroY;
  _Stars3DPainter({required this.stars, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010208));

    for (final s in stars) {
      final p1 = s.rotateX(gyroY * 0.3).rotateY(gyroX * 0.3);
      final p2 = _P3D(s.x, s.y, s.z + 40).rotateX(gyroY * 0.3).rotateY(gyroX * 0.3);
      final scale = p1.scaleFactor();

      canvas.drawLine(
        p1.project(center), p2.project(center),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: (scale * 0.8).clamp(0.1, 1.0))..strokeWidth = (scale * 2.0).clamp(1.0, 4.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Stars3DPainter old) => true;
}

// ============================================================
// WIDGET 23: Alien Invasion Ship (3D Saucer & Ventral Tractor Beam)
// ============================================================
class AlienInvasionAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const AlienInvasionAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<AlienInvasionAnimation> createState() => _AlienInvasionAnimationState();
}

class _AlienInvasionAnimationState extends State<AlienInvasionAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _AlienSaucer3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _AlienSaucer3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _AlienSaucer3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010604));

    final saucerPaint = Paint()..color = const Color(0xFF00FF88)..strokeWidth = 1.8..style = PaintingStyle.stroke;

    // 3D Concentric Spinning Saucer Rings
    for (int ring = 0; ring < 4; ring++) {
      final r = 30.0 + ring * 25.0;
      final pts = List.generate(24, (i) {
        final a = (i / 24) * pi * 2 + t * (ring.isEven ? 2 : -2);
        return _P3D(cos(a) * r, ring * 6.0 - 15.0, sin(a) * r);
      });
      for (int i = 0; i < 24; i++) {
        _draw3DLine(canvas, pts[i], pts[(i + 1) % 24], center, saucerPaint, rotX: 0.35 + gyroY * 0.3, rotY: gyroX * 0.3);
      }
    }

    // 3D Conical Tractor Beam
    final beamBase = Offset(center.dx, size.height);
    final path = Path()
      ..moveTo(center.dx - 15, center.dy)
      ..lineTo(beamBase.dx - 110, beamBase.dy)
      ..lineTo(beamBase.dx + 110, beamBase.dy)
      ..lineTo(center.dx + 15, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(covariant _AlienSaucer3DPainter old) => true;
}

// ============================================================
// WIDGET 24: Cosmic Zoom Big Bang (3D Exploding Particle Sphere)
// ============================================================
class CosmicZoomAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const CosmicZoomAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<CosmicZoomAnimation> createState() => _CosmicZoomAnimationState();
}

class _CosmicZoomAnimationState extends State<CosmicZoomAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _BigBang3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _BigBang3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _BigBang3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF040008));

    // 3D Expanding Particle Cluster
    final r = t * 180.0;
    final rng = Random(42);
    for (int i = 0; i < 90; i++) {
      final theta = rng.nextDouble() * pi * 2;
      final phi = rng.nextDouble() * pi - pi / 2;
      final p = _P3D(cos(theta) * cos(phi) * r, sin(phi) * r, sin(theta) * cos(phi) * r);
      final proj = p.rotateX(gyroY * 0.4).rotateY(gyroX * 0.4 + t * pi).project(center);
      canvas.drawCircle(proj, max(1.5, 5.0 * (1.0 - t)), Paint()..color = const Color(0xFFFF2A85));
    }
  }

  @override
  bool shouldRepaint(covariant _BigBang3DPainter old) => true;
}

// ============================================================
// WIDGET 25: Space Battle War (3D Dogfighting Starfighters)
// ============================================================
class SpaceBattleAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const SpaceBattleAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<SpaceBattleAnimation> createState() => _SpaceBattleAnimationState();
}

class _SpaceBattleAnimationState extends State<SpaceBattleAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _SpaceBattle3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _SpaceBattle3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _SpaceBattle3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF000510));

    final bluePaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final redPaint = Paint()..color = const Color(0xFFFF2200)..strokeWidth = 2.0..style = PaintingStyle.stroke;

    // Fighter 1 (Blue Ally) Circling in 3D
    final a1 = t * pi * 2;
    final pos1 = _P3D(cos(a1) * 110, sin(a1) * 30, sin(a1) * 90);
    _drawFighter(canvas, pos1, center, bluePaint, a1 + pi / 2);

    // Fighter 2 (Red Enemy) Pursuing in 3D
    final a2 = a1 - 0.7;
    final pos2 = _P3D(cos(a2) * 110, sin(a2) * 30, sin(a2) * 90);
    _drawFighter(canvas, pos2, center, redPaint, a2 + pi / 2);

    // Laser Tracer between them
    _draw3DLine(canvas, pos2, pos1, center, Paint()..color = const Color(0xFFFF2200)..strokeWidth = 2.5);
  }

  void _drawFighter(Canvas canvas, _P3D pos, Offset center, Paint paint, double heading) {
    final nose = _P3D(pos.x + cos(heading) * 20, pos.y, pos.z + sin(heading) * 20);
    final leftW = _P3D(pos.x - sin(heading) * 16, pos.y, pos.z + cos(heading) * 16);
    final rightW = _P3D(pos.x + sin(heading) * 16, pos.y, pos.z - cos(heading) * 16);
    _draw3DLine(canvas, nose, leftW, center, paint);
    _draw3DLine(canvas, nose, rightW, center, paint);
    _draw3DLine(canvas, leftW, rightW, center, paint);
  }

  @override
  bool shouldRepaint(covariant _SpaceBattle3DPainter old) => true;
}

// ============================================================
// WIDGET 26: Quantum Black Hole Singularity
// ============================================================
class QuantumBlackHoleAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const QuantumBlackHoleAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<QuantumBlackHoleAnimation> createState() => _QuantumBlackHoleState();
}

class _QuantumBlackHoleState extends State<QuantumBlackHoleAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _BlackHole3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _BlackHole3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _BlackHole3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black);

    // 3D Inward Spiraling Event Horizon Particles
    final pPaint = Paint()..strokeWidth = 2.0;
    for (int i = 0; i < 70; i++) {
      final spiral = (i / 70.0 + t) % 1.0;
      final dist = spiral * 140.0;
      final angle = i * 0.4 + t * pi * 4;
      final p = _P3D(cos(angle) * dist, sin(angle) * dist * 0.4, (1.0 - spiral) * 50);
      final proj = p.rotateX(gyroY * 0.3).rotateY(gyroX * 0.3).project(center);
      pPaint.color = const Color(0xFF00E5FF).withValues(alpha: spiral);
      canvas.drawCircle(proj, max(1.0, spiral * 3.5), pPaint);
    }
    canvas.drawCircle(center, 30, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant _BlackHole3DPainter old) => true;
}

// ============================================================
// WIDGET 27: Cyberpunk Neon Rain (3D City Canyon Skyline)
// ============================================================
class CyberpunkNeonRainAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const CyberpunkNeonRainAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<CyberpunkNeonRainAnimation> createState() => _CyberpunkNeonRainState();
}

class _CyberpunkNeonRainState extends State<CyberpunkNeonRainAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _NeonRain3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _NeonRain3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _NeonRain3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF05010A));

    final bldgPaint = Paint()..color = const Color(0xFFFF2A85).withValues(alpha: 0.4)..strokeWidth = 1.4..style = PaintingStyle.stroke;

    // 3D Wireframe Skyscraper Canyon (Left & Right)
    for (int side = -1; side <= 1; side += 2) {
      for (int zIdx = 0; zIdx < 6; zIdx++) {
        final z = zIdx * 60.0 + 30.0;
        final x = side * 110.0;
        final bldg = [
          _P3D(x, 150, z), _P3D(x + side * 40, 150, z), _P3D(x + side * 40, -120, z), _P3D(x, -120, z)
        ];
        for (int k = 0; k < 4; k++) {
          _draw3DLine(canvas, bldg[k], bldg[(k + 1) % 4], center, bldgPaint, rotX: gyroY * 0.2, rotY: gyroX * 0.2);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeonRain3DPainter old) => true;
}

// ============================================================
// WIDGET 28: Galactic Nebula (3D Logarithmic Spiral Galaxy)
// ============================================================
class GalacticNebulaAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const GalacticNebulaAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<GalacticNebulaAnimation> createState() => _GalacticNebulaState();
}

class _GalacticNebulaState extends State<GalacticNebulaAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _GalacticNebula3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _GalacticNebula3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _GalacticNebula3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF03010A));

    // Dual 3D Spiral Arms
    for (int arm = 0; arm < 2; arm++) {
      final offset = arm * pi;
      for (double r = 10; r <= 140; r += 5) {
        final a = r * 0.05 + t * pi * 2 + offset;
        final p = _P3D(cos(a) * r, (r / 140.0) * 20.0, sin(a) * r);
        final proj = p.rotateX(0.45 + gyroY * 0.3).rotateY(gyroX * 0.3).project(center);
        final color = Color.lerp(const Color(0xFF00E5FF), const Color(0xFFFF2A85), r / 140.0)!;
        canvas.drawCircle(proj, 2.0, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalacticNebula3DPainter old) => true;
}

// ============================================================
// WIDGET 29: Time Warp Vortex (3D Temporal Cylindrical Tunnel)
// ============================================================
class TimeWarpVortexAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const TimeWarpVortexAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<TimeWarpVortexAnimation> createState() => _TimeWarpVortexState();
}

class _TimeWarpVortexState extends State<TimeWarpVortexAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _TimeWarp3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _TimeWarp3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _TimeWarp3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF010208));

    final tunnelPaint = Paint()..strokeWidth = 1.5..style = PaintingStyle.stroke;

    // 3D Receding Time Tunnel Rings
    for (int i = 0; i < 14; i++) {
      final z = ((i + t) % 14) * 45.0 + 10.0;
      final r = (z / 600.0) * 160.0 + 30.0;
      final alpha = (1.0 - z / 630.0).clamp(0.1, 0.9);
      tunnelPaint.color = const Color(0xFF00E5FF).withValues(alpha: alpha);

      final pts = List.generate(16, (k) {
        final a = (k / 16) * pi * 2 + z * 0.01;
        return _P3D(cos(a) * r, sin(a) * r, z);
      });
      for (int k = 0; k < 16; k++) {
        _draw3DLine(canvas, pts[k], pts[(k + 1) % 16], center, tunnelPaint, rotX: gyroY * 0.3, rotY: gyroX * 0.3);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimeWarp3DPainter old) => true;
}

// ============================================================
// WIDGET 30: Nanobot Swarm (3D Geodesic Assembling Cloud)
// ============================================================
class NanobotSwarmAnimation extends StatefulWidget {
  final double gyroX, gyroY;
  const NanobotSwarmAnimation({super.key, this.gyroX = 0, this.gyroY = 0});
  @override
  State<NanobotSwarmAnimation> createState() => _NanobotSwarmState();
}

class _NanobotSwarmState extends State<NanobotSwarmAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _NanobotSwarm3DPainter(t: _ctrl.value, gyroX: widget.gyroX, gyroY: widget.gyroY),
      ),
    );
  }
}

class _NanobotSwarm3DPainter extends CustomPainter {
  final double t, gyroX, gyroY;
  _NanobotSwarm3DPainter({required this.t, required this.gyroX, required this.gyroY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020C16));

    final botPaint = Paint()..color = const Color(0xFF00E5FF);

    // 3D Spherical Nanobot Cloud Assembling & Dispersing
    final r = 60.0 + sin(t * pi * 2) * 25.0;
    const count = 64;
    for (int i = 0; i < count; i++) {
      final theta = (i / count) * pi * 2 + t * pi;
      final phi = (i % 8 - 4) * (pi / 8);
      final p = _P3D(cos(theta) * cos(phi) * r, sin(phi) * r, sin(theta) * cos(phi) * r);
      final proj = p.rotateX(gyroY * 0.4).rotateY(gyroX * 0.4).project(center);
      canvas.drawCircle(proj, 2.5, botPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NanobotSwarm3DPainter old) => true;
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
    case 'warship_beam_cannon': return WarshipBeamAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'shooting_stars_field': return ShootingStarsAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'alien_invasion_ship': return AlienInvasionAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'cosmic_zoom_bigbang': return CosmicZoomAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'space_battle_war': return SpaceBattleAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'quantum_blackhole': return QuantumBlackHoleAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'cyberpunk_neon_rain': return CyberpunkNeonRainAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'galactic_nebula': return GalacticNebulaAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'time_warp_vortex': return TimeWarpVortexAnimation(gyroX: gyroX, gyroY: gyroY);
    case 'nanobot_swarm': return NanobotSwarmAnimation(gyroX: gyroX, gyroY: gyroY);
    default: return const SizedBox.shrink();
  }
}
