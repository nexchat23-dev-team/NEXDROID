import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ============================================================================
// LIGHTWEIGHT 3D VECTOR FOR HARDWARE-ACCELERATED HOLOGRAPHIC RENDERING
// ============================================================================

class _Vec3D {
  double x, y, z;
  _Vec3D(this.x, this.y, this.z);

  _Vec3D rotateX(double a) {
    final c = math.cos(a), s = math.sin(a);
    return _Vec3D(x, y * c - z * s, y * s + z * c);
  }

  _Vec3D rotateY(double a) {
    final c = math.cos(a), s = math.sin(a);
    return _Vec3D(x * c + z * s, y, -x * s + z * c);
  }

  _Vec3D rotateZ(double a) {
    final c = math.cos(a), s = math.sin(a);
    return _Vec3D(x * c - y * s, x * s + y * c, z);
  }
}

/// Military-Grade Tactical Holographic 3D Loading Component
class Realistic3DCosmicLoadingWidget extends StatefulWidget {
  final String statusText;
  final double progress; // 0.0 to 1.0, null for indeterminate
  final bool isWarping;
  final VoidCallback? onComplete;

  const Realistic3DCosmicLoadingWidget({
    super.key,
    this.statusText = 'SYSTEM INITIALIZING // QUANTUM CORE ARMED',
    this.progress = 0.5,
    this.isWarping = false,
    this.onComplete,
  });

  @override
  State<Realistic3DCosmicLoadingWidget> createState() =>
      _Realistic3DCosmicLoadingWidgetState();
}

class _Realistic3DCosmicLoadingWidgetState
    extends State<Realistic3DCosmicLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickerCtrl;
  final math.Random _rnd = math.Random(42);

  // 3D Particles
  final List<_Vec3D> _deepStars = [];
  final List<double> _starSpeeds = [];

  // Gyro / Tilt Camera Physics
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Offset _tiltOffset = Offset.zero;
  Offset _smoothedTilt = Offset.zero;

  // 3D Gyroscope Gimbal Angles
  double _angleX = 0.0;
  double _angleY = 0.0;
  double _angleZ = 0.0;
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _init3DEnvironment();
    _setupSensors();

    _tickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickerCtrl.addListener(_updatePhysics);
  }

  void _init3DEnvironment() {
    _deepStars.clear();
    _starSpeeds.clear();
    for (int i = 0; i < 180; i++) {
      _deepStars.add(_Vec3D(
        (_rnd.nextDouble() - 0.5) * 1200.0,
        (_rnd.nextDouble() - 0.5) * 1200.0,
        100.0 + _rnd.nextDouble() * 900.0,
      ));
      _starSpeeds.add(0.8 + _rnd.nextDouble() * 2.2);
    }
  }

  void _setupSensors() {
    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      final rawX = -event.x * 6.0;
      final rawY = event.y * 6.0;
      setState(() {
        _tiltOffset = Offset(rawX, rawY);
      });
    }, onError: (_) {});
  }

  void _updatePhysics() {
    if (!mounted) return;
    _tickCount++;

    // Smooth gyro camera interpolation with critical damping
    _smoothedTilt = Offset(
      _smoothedTilt.dx + (_tiltOffset.dx - _smoothedTilt.dx) * 0.08,
      _smoothedTilt.dy + (_tiltOffset.dy - _smoothedTilt.dy) * 0.08,
    );

    // Continuous 3D Gyroscope Gimbal Rotations
    final speed = widget.isWarping ? 0.08 : 0.02;
    _angleX += speed * 0.7;
    _angleY += speed * 1.0;
    _angleZ += speed * 0.5;

    // Advance 3D Starfield
    final starWarpSpeed = widget.isWarping ? 18.0 : 2.0;
    for (int i = 0; i < _deepStars.length; i++) {
      final s = _deepStars[i];
      s.z -= _starSpeeds[i] * starWarpSpeed;
      if (s.z <= 10.0) {
        s.z = 1000.0;
        s.x = (_rnd.nextDouble() - 0.5) * 1200.0;
        s.y = (_rnd.nextDouble() - 0.5) * 1200.0;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _tickerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressVal = widget.progress.clamp(0.0, 1.0);
    final percentInt = (progressVal * 100).toInt();

    return Stack(
      children: [
        // 1. Hardware 3D Hologram Canvas
        Positioned.fill(
          child: CustomPaint(
            painter: _TacticalHologram3DPainter(
              deepStars: _deepStars,
              tiltOffset: _smoothedTilt,
              angleX: _angleX,
              angleY: _angleY,
              angleZ: _angleZ,
              isWarping: widget.isWarping,
              progress: progressVal,
              tick: _tickCount,
            ),
          ),
        ),

        // 2. High-Precision Tactical HUD Telemetry
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28.0, left: 24.0, right: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Diagnostic Telemetry Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00FF88),
                              boxShadow: [
                                BoxShadow(color: Color(0xFF00FF88), blurRadius: 8),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SYS::LIVE // LATENCY: 0.8ms',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '0x7F${(percentInt * 255 ~/ 100).toRadixString(16).padLeft(2, '0').toUpperCase()} // READY',
                        style: TextStyle(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Status Console Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B16).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Scanning Reticle Glyph
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.statusText.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$percentInt%',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Industrial Segmented Laser Gauge
                  Row(
                    children: List.generate(24, (index) {
                      final segProgress = (index + 1) / 24.0;
                      final isActive = progressVal >= segProgress;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF00E5FF)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HARDWARE-ACCELERATED MILITARY 3D HOLOGRAPHIC PAINTER
// ============================================================================

class _TacticalHologram3DPainter extends CustomPainter {
  final List<_Vec3D> deepStars;
  final Offset tiltOffset;
  final double angleX, angleY, angleZ;
  final bool isWarping;
  final double progress;
  final int tick;

  _TacticalHologram3DPainter({
    required this.deepStars,
    required this.tiltOffset,
    required this.angleX,
    required this.angleY,
    required this.angleZ,
    required this.isWarping,
    required this.progress,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + tiltOffset.dx;
    final cy = size.height * 0.44 + tiltOffset.dy;
    final center = Offset(cx, cy);

    // Deep Void Obsidian Background
    final bgPaint = Paint()..color = const Color(0xFF03050C);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 1. Perspective 3D Infinite Grid Floor
    _draw3DGridFloor(canvas, size, center);

    // 2. 3D Stars / Depth Data Stream
    _draw3DStarStream(canvas, size, center);

    // 3. Central Holographic 3D Gyroscope Gimbal Rings
    _draw3DGimbalRings(canvas, center, size.width * 0.32);

    // 4. Central 3D Floating Polyhedral Core (Icosahedron / Quantum Crystal)
    _draw3DQuantumPolyhedron(canvas, center, size.width * 0.14);

    // 5. Targeting Radar Sweep Ring
    _drawRadarSweep(canvas, center, size.width * 0.36);
  }

  void _draw3DGridFloor(Canvas canvas, Size size, Offset center) {
    final floorY = size.height * 0.65;
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    // Horizon Line
    canvas.drawLine(
      Offset(0, floorY),
      Offset(size.width, floorY),
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
        ..strokeWidth = 1.2,
    );

    // Vanishing Point Grid Rays
    const numRays = 16;
    for (int i = 0; i <= numRays; i++) {
      final bottomX = (size.width / numRays) * i;
      canvas.drawLine(Offset(center.dx, floorY), Offset(bottomX, size.height), gridPaint);
    }

    // Depth-Receding Transverse Lines
    for (double z = 1.0; z <= 6.0; z += 1.0) {
      final y = floorY + (size.height - floorY) * math.pow(z / 6.0, 1.8);
      final alpha = (0.02 + (z / 6.0) * 0.07).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
          ..strokeWidth = 0.8,
      );
    }
  }

  void _draw3DStarStream(Canvas canvas, Size size, Offset center) {
    const focalLength = 400.0;
    final starPaint = Paint()..strokeCap = StrokeCap.round;

    for (final s in deepStars) {
      if (s.z <= 10.0) continue;
      final scale = focalLength / s.z;
      final px = center.dx + s.x * scale;
      final py = center.dy + s.y * scale;

      if (px < -10 || px > size.width + 10 || py < -10 || py > size.height + 10) continue;

      final normZ = (1000.0 - s.z) / 1000.0;
      final alpha = (normZ * 0.7).clamp(0.05, 0.8);
      starPaint
        ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
        ..strokeWidth = (scale * 2.2).clamp(0.8, 4.0);

      canvas.drawCircle(Offset(px, py), starPaint.strokeWidth * 0.5, starPaint);
    }
  }

  void _draw3DGimbalRings(Canvas canvas, Offset center, double radius) {
    const numPoints = 36;

    // Ring 1: Outer Primary Gimbal (Rotates on X & Y)
    _render3DRing(
      canvas,
      center,
      radius: radius,
      rotX: angleX,
      rotY: angleY,
      rotZ: 0,
      color: const Color(0xFF00E5FF),
      strokeWidth: 1.4,
      dashAlpha: 0.75,
      numPoints: numPoints,
    );

    // Ring 2: Intermediate Gimbal (Counter-rotates on Y & Z)
    _render3DRing(
      canvas,
      center,
      radius: radius * 0.82,
      rotX: 0,
      rotY: -angleY * 1.2,
      rotZ: angleZ,
      color: const Color(0xFF00FF88),
      strokeWidth: 1.2,
      dashAlpha: 0.65,
      numPoints: numPoints,
    );

    // Ring 3: Inner Core Ring (Rotates on X & Z)
    _render3DRing(
      canvas,
      center,
      radius: radius * 0.64,
      rotX: angleX * 1.4,
      rotY: 0,
      rotZ: -angleZ * 0.8,
      color: const Color(0xFF7000FF),
      strokeWidth: 1.0,
      dashAlpha: 0.5,
      numPoints: numPoints,
    );
  }

  void _render3DRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double rotX,
    required double rotY,
    required double rotZ,
    required Color color,
    required double strokeWidth,
    required double dashAlpha,
    required int numPoints,
  }) {
    const focal = 350.0;
    const cameraDist = 450.0;
    final List<Offset> projected = [];
    final List<double> depths = [];

    for (int i = 0; i <= numPoints; i++) {
      final theta = (i / numPoints) * math.pi * 2;
      final raw = _Vec3D(radius * math.cos(theta), radius * math.sin(theta), 0.0);
      final rotated = raw.rotateX(rotX).rotateY(rotY).rotateZ(rotZ);

      final z = rotated.z + cameraDist;
      final scale = focal / z;
      projected.add(Offset(center.dx + rotated.x * scale, center.dy + rotated.y * scale));
      depths.add(rotated.z);
    }

    final path = Path()..moveTo(projected[0].dx, projected[0].dy);
    for (int i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }

    // Depth-aware glow paint
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: dashAlpha);

    canvas.drawPath(path, ringPaint);
  }

  void _draw3DQuantumPolyhedron(Canvas canvas, Offset center, double size) {
    const focal = 350.0;
    const cameraDist = 450.0;

    // 3D Octahedron Vertices
    final vertices = [
      _Vec3D(0, -size, 0),  // Top
      _Vec3D(size, 0, 0),   // Right
      _Vec3D(0, 0, size),   // Front
      _Vec3D(-size, 0, 0),  // Left
      _Vec3D(0, 0, -size),  // Back
      _Vec3D(0, size, 0),   // Bottom
    ];

    // Rotated vertices
    final transformed = vertices.map((v) {
      return v.rotateX(angleX * 1.5).rotateY(angleY * 2.0).rotateZ(angleZ * 0.8);
    }).toList();

    // Projected to 2D
    final projected = transformed.map((v) {
      final z = v.z + cameraDist;
      final scale = focal / z;
      return Offset(center.dx + v.x * scale, center.dy + v.y * scale);
    }).toList();

    // Octahedron Edges (12 edges)
    const edges = [
      [0, 1], [0, 2], [0, 3], [0, 4], // Top to equator
      [5, 1], [5, 2], [5, 3], [5, 4], // Bottom to equator
      [1, 2], [2, 3], [3, 4], [4, 1], // Equator ring
    ];

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85);

    for (final e in edges) {
      final p1 = projected[e[0]];
      final p2 = projected[e[1]];
      canvas.drawLine(p1, p2, edgePaint);
    }

    // Glowing Core Node
    final coreGlow = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, 12.0, coreGlow);
    canvas.drawCircle(center, 4.0, Paint()..color = Colors.white);
  }

  void _drawRadarSweep(Canvas canvas, Offset center, double radius) {
    final sweepAngle = (tick * 0.04) % (math.pi * 2);

    final radarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.12);

    canvas.drawCircle(center, radius, radarPaint);

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - radius * 1.1, center.dy),
      Offset(center.dx + radius * 1.1, center.dy),
      Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 1.1),
      Offset(center.dx, center.dy + radius * 1.1),
      Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)..strokeWidth = 0.8,
    );

    // Rotating Sweep Line
    final sweepEnd = Offset(
      center.dx + math.cos(sweepAngle) * radius,
      center.dy + math.sin(sweepAngle) * radius,
    );
    canvas.drawLine(
      center,
      sweepEnd,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _TacticalHologram3DPainter old) => true;
}
