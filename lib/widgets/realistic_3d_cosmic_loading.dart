import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Hyper-Realistic 3D Cosmic Particle & Physics Entities

class Star3D {
  double x;
  double y;
  double z;
  double prevZ;
  double radius;
  Color color;
  double pulsePhase;
  double pulseSpeed;

  Star3D({
    required this.x,
    required this.y,
    required this.z,
    required this.prevZ,
    required this.radius,
    required this.color,
    required this.pulsePhase,
    required this.pulseSpeed,
  });
}

class ShootingStar3D {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double length;
  double radius;
  double life;
  double maxLife;
  Color coreColor;
  Color tailColor;
  List<Offset> prevScreenPositions = [];
  List<double> prevZDepths = [];

  ShootingStar3D({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.length,
    required this.radius,
    required this.life,
    required this.maxLife,
    required this.coreColor,
    required this.tailColor,
  });
}

class Ember3D {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double radius;
  double life;
  double maxLife;
  Color color;

  Ember3D({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.radius,
    required this.life,
    required this.maxLife,
    required this.color,
  });
}

/// Photorealistic 3D Space Loading Animation Component
class Realistic3DCosmicLoadingWidget extends StatefulWidget {
  final String statusText;
  final double progress; // 0.0 to 1.0, null for indeterminate
  final bool isWarping;
  final VoidCallback? onComplete;

  const Realistic3DCosmicLoadingWidget({
    super.key,
    this.statusText = 'INITIALIZING 3D QUANTUM CORE...',
    this.progress = 0.5,
    this.isWarping = false,
    this.onComplete,
  });

  @override
  State<Realistic3DCosmicLoadingWidget> createState() => _Realistic3DCosmicLoadingWidgetState();
}

class _Realistic3DCosmicLoadingWidgetState extends State<Realistic3DCosmicLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickerCtrl;
  final Random _rnd = Random();

  // 3D Physics World
  final List<Star3D> _stars = [];
  final List<ShootingStar3D> _shootingStars = [];
  final List<Ember3D> _embers = [];

  // Gyro / Tilt Camera Physics
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Offset _tiltOffset = Offset.zero;
  Offset _smoothedTilt = Offset.zero;

  // Accretion Disk / Black Hole Rotation
  double _blackHoleAngle = 0.0;
  double _shootingStarTimer = 0.0;

  @override
  void initState() {
    super.initState();
    _init3DStarfield();
    _setupSensors();

    _tickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickerCtrl.addListener(_update3DPhysics);
  }

  void _init3DStarfield() {
    _stars.clear();
    for (int i = 0; i < 220; i++) {
      final double z = 10.0 + _rnd.nextDouble() * 990.0;
      final colorRoll = _rnd.nextDouble();
      Color c;
      if (colorRoll > 0.85) {
        c = const Color(0xFF00E5FF); // Electric Cyan
      } else if (colorRoll > 0.70) {
        c = const Color(0xFFC084FC); // Quantum Purple
      } else if (colorRoll > 0.55) {
        c = const Color(0xFFFFD700); // Solar Gold
      } else {
        c = Colors.white;
      }

      _stars.add(Star3D(
        x: (_rnd.nextDouble() - 0.5) * 1600.0,
        y: (_rnd.nextDouble() - 0.5) * 1600.0,
        z: z,
        prevZ: z,
        radius: 0.8 + _rnd.nextDouble() * 2.2,
        color: c,
        pulsePhase: _rnd.nextDouble() * pi * 2,
        pulseSpeed: 1.5 + _rnd.nextDouble() * 3.5,
      ));
    }
  }

  void _setupSensors() {
    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      final rawX = -event.x * 12.0;
      final rawY = event.y * 12.0;
      setState(() {
        _tiltOffset = Offset(rawX, rawY);
      });
    }, onError: (_) {});
  }

  void _spawnShootingStar() {
    final startZ = 200.0 + _rnd.nextDouble() * 400.0;
    final angle = _rnd.nextDouble() * pi * 2;
    final speed = 18.0 + _rnd.nextDouble() * 22.0;

    final colorRoll = _rnd.nextDouble();
    Color coreColor = colorRoll > 0.5 ? const Color(0xFF00E5FF) : const Color(0xFFFF2A85);
    Color tailColor = colorRoll > 0.5 ? const Color(0xFF3B82F6) : const Color(0xFF9333EA);

    _shootingStars.add(ShootingStar3D(
      x: cos(angle) * (300.0 + _rnd.nextDouble() * 200.0),
      y: sin(angle) * (300.0 + _rnd.nextDouble() * 200.0),
      z: startZ,
      vx: -cos(angle + 0.3) * speed,
      vy: -sin(angle + 0.3) * speed,
      vz: -speed * 0.8,
      length: 120.0 + _rnd.nextDouble() * 100.0,
      radius: 2.5 + _rnd.nextDouble() * 1.5,
      life: 0.0,
      maxLife: 1.2 + _rnd.nextDouble() * 0.8,
      coreColor: coreColor,
      tailColor: tailColor,
    ));
  }

  void _update3DPhysics() {
    if (!mounted) return;

    // Smooth gyro camera interpolation
    _smoothedTilt = Offset(
      _smoothedTilt.dx + (_tiltOffset.dx - _smoothedTilt.dx) * 0.08,
      _smoothedTilt.dy + (_tiltOffset.dy - _smoothedTilt.dy) * 0.08,
    );

    _blackHoleAngle += 0.025;
    _shootingStarTimer += 0.016;

    if (_shootingStarTimer > 0.8) {
      _shootingStarTimer = 0.0;
      if (_shootingStars.length < 4) {
        _spawnShootingStar();
      }
    }

    final double speedFactor = widget.isWarping ? 18.0 : 2.5;

    // 1. Update 3D Stars
    for (final star in _stars) {
      star.prevZ = star.z;
      star.z -= speedFactor;
      star.pulsePhase += 0.02 * star.pulseSpeed;

      // Wrap around when star flies past camera
      if (star.z <= 5.0) {
        star.z = 1000.0;
        star.prevZ = 1000.0;
        star.x = (_rnd.nextDouble() - 0.5) * 1600.0;
        star.y = (_rnd.nextDouble() - 0.5) * 1600.0;
      }
    }

    // 2. Update 3D Shooting Stars
    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      final ss = _shootingStars[i];
      ss.life += 0.016;

      // Add to position history for 3D volumetric trail
      ss.prevScreenPositions.add(Offset(ss.x, ss.y));
      ss.prevZDepths.add(ss.z);
      if (ss.prevScreenPositions.length > 12) {
        ss.prevScreenPositions.removeAt(0);
        ss.prevZDepths.removeAt(0);
      }

      ss.x += ss.vx;
      ss.y += ss.vy;
      ss.z += ss.vz;

      // Spawn trail embers
      if (_rnd.nextDouble() > 0.4) {
        _embers.add(Ember3D(
          x: ss.x + (_rnd.nextDouble() - 0.5) * 15.0,
          y: ss.y + (_rnd.nextDouble() - 0.5) * 15.0,
          z: ss.z,
          vx: ss.vx * 0.2 + (_rnd.nextDouble() - 0.5) * 4.0,
          vy: ss.vy * 0.2 + (_rnd.nextDouble() - 0.5) * 4.0,
          vz: ss.vz * 0.2,
          radius: 1.0 + _rnd.nextDouble() * 1.5,
          life: 0.0,
          maxLife: 0.4 + _rnd.nextDouble() * 0.4,
          color: ss.coreColor,
        ));
      }

      if (ss.life >= ss.maxLife || ss.z <= 10.0) {
        _shootingStars.removeAt(i);
      }
    }

    // 3. Update 3D Embers
    for (int i = _embers.length - 1; i >= 0; i--) {
      final e = _embers[i];
      e.life += 0.016;
      e.x += e.vx;
      e.y += e.vy;
      e.z += e.vz;

      if (e.life >= e.maxLife || e.z <= 5.0) {
        _embers.removeAt(i);
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
    return Stack(
      children: [
        // 3D Canvas Visualizer
        Positioned.fill(
          child: CustomPaint(
            painter: _Realistic3DCosmicPainter(
              stars: _stars,
              shootingStars: _shootingStars,
              embers: _embers,
              tiltOffset: _smoothedTilt,
              blackHoleAngle: _blackHoleAngle,
              isWarping: widget.isWarping,
            ),
          ),
        ),

        // Cyber / Quantum Loading Overlay HUD
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60.0, left: 32.0, right: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status message with glowing cyan border box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030712).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Quantum 3D Progress Bar
                Container(
                  height: 6,
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.progress.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Color(0xFF8B5CF6),
                            Color(0xFFFF2A85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hardware-Accelerated 3D Custom Painter
class _Realistic3DCosmicPainter extends CustomPainter {
  final List<Star3D> stars;
  final List<ShootingStar3D> shootingStars;
  final List<Ember3D> embers;
  final Offset tiltOffset;
  final double blackHoleAngle;
  final bool isWarping;

  _Realistic3DCosmicPainter({
    required this.stars,
    required this.shootingStars,
    required this.embers,
    required this.tiltOffset,
    required this.blackHoleAngle,
    required this.isWarping,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double focalLength = size.width * 0.85;
    final Offset center = Offset(size.width / 2 + tiltOffset.dx, size.height / 2 + tiltOffset.dy);

    // Deep cosmic space background gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width * 0.9,
        [
          const Color(0xFF090D24),
          const Color(0xFF040612),
          const Color(0xFF020206),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 1. Draw 3D Gravitational Singularity Core & Accretion Lensing Ring
    _draw3DAccretionDisk(canvas, center, size);

    // 2. Draw 3D Stars with Perspective Motion Streaks
    for (final star in stars) {
      if (star.z <= 1.0) continue;

      final double scale = focalLength / star.z;
      final double sx = center.dx + star.x * scale;
      final double sy = center.dy + star.y * scale;

      if (sx < -20 || sx > size.width + 20 || sy < -20 || sy > size.height + 20) continue;

      // Distance fog & pulse opacity
      final double normZ = (1000.0 - star.z).clamp(0.0, 1000.0) / 1000.0;
      final double pulse = (sin(star.pulsePhase) + 1.0) / 2.0;
      final double alpha = (0.2 + 0.8 * normZ * (0.7 + 0.3 * pulse)).clamp(0.0, 1.0);
      final double renderRadius = (star.radius * scale * 1.8).clamp(0.6, 6.5);

      if (isWarping) {
        // Warp motion stretch line
        final double prevScale = focalLength / star.prevZ;
        final double psx = center.dx + star.x * prevScale;
        final double psy = center.dy + star.y * prevScale;

        final warpLinePaint = Paint()
          ..color = star.color.withValues(alpha: alpha)
          ..strokeWidth = renderRadius
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(psx, psy), Offset(sx, sy), warpLinePaint);
      } else {
        // Soft glowing star point
        final starPaint = Paint()..color = star.color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(sx, sy), renderRadius, starPaint);

        if (renderRadius > 2.5) {
          final glowPaint = Paint()
            ..color = star.color.withValues(alpha: alpha * 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
          canvas.drawCircle(Offset(sx, sy), renderRadius * 2.2, glowPaint);
        }
      }
    }

    // 3. Draw 3D Volumetric Shooting Stars
    for (final ss in shootingStars) {
      if (ss.z <= 1.0) continue;

      final double scale = focalLength / ss.z;
      final double sx = center.dx + ss.x * scale;
      final double sy = center.dy + ss.y * scale;

      // Draw Volumetric Trail from previous 3D positions
      if (ss.prevScreenPositions.isNotEmpty) {
        for (int i = 0; i < ss.prevScreenPositions.length - 1; i++) {
          final double pZ = ss.prevZDepths[i];
          final double pScale = focalLength / pZ;
          final Offset p1 = Offset(
            center.dx + ss.prevScreenPositions[i].dx * pScale,
            center.dy + ss.prevScreenPositions[i].dy * pScale,
          );
          final Offset p2 = Offset(
            center.dx + ss.prevScreenPositions[i + 1].dx * (focalLength / ss.prevZDepths[i + 1]),
            center.dy + ss.prevScreenPositions[i + 1].dy * (focalLength / ss.prevZDepths[i + 1]),
          );

          final double trailProgress = i / ss.prevScreenPositions.length;
          final double trailAlpha = (trailProgress * (1.0 - ss.life / ss.maxLife)).clamp(0.0, 1.0);

          final trailPaint = Paint()
            ..shader = ui.Gradient.linear(
              p1,
              p2,
              [
                ss.tailColor.withValues(alpha: 0.0),
                ss.coreColor.withValues(alpha: trailAlpha),
              ],
            )
            ..strokeWidth = (ss.radius * scale * 2.2 * trailProgress).clamp(1.0, 8.0)
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(p1, p2, trailPaint);
        }
      }

      // Shooting star plasma head flare
      final headPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(sx, sy), ss.radius * scale * 2.0, headPaint);

      final headGlow = Paint()
        ..color = ss.coreColor.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawCircle(Offset(sx, sy), ss.radius * scale * 4.5, headGlow);
    }

    // 4. Draw 3D Spark Embers
    for (final e in embers) {
      if (e.z <= 1.0) continue;
      final double scale = focalLength / e.z;
      final double sx = center.dx + e.x * scale;
      final double sy = center.dy + e.y * scale;
      final double alpha = (1.0 - e.life / e.maxLife).clamp(0.0, 1.0);

      final emberPaint = Paint()..color = e.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), (e.radius * scale).clamp(0.8, 3.5), emberPaint);
    }
  }

  /// Interstellar-Style 3D Accretion Disk around Black Hole Void
  void _draw3DAccretionDisk(Canvas canvas, Offset center, Size size) {
    final double radius = size.width * 0.28;

    // Outer Einstein Gravitational Lensing Glow
    final lensPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF00E5FF).withValues(alpha: 0.15),
          const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          const Color(0xFFFF2A85).withValues(alpha: 0.20),
          const Color(0xFF00E5FF).withValues(alpha: 0.15),
        ],
        null,
        TileMode.clamp,
        blackHoleAngle,
        blackHoleAngle + pi * 2,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24.0);

    canvas.drawCircle(center, radius * 1.35, lensPaint);

    // Relativistic Doppler Accretion Ring Ellipse
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.35); // 3D Perspective Tilt Angle

    final Rect diskRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.4, height: radius * 0.7);

    final diskPaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [
          const Color(0xFF00E5FF).withValues(alpha: 0.85), // Oncoming blue-shifted gas
          const Color(0xFF8B5CF6).withValues(alpha: 0.65),
          const Color(0xFFFF2A85).withValues(alpha: 0.35), // Receding red-shifted gas
          const Color(0xFF00E5FF).withValues(alpha: 0.85),
        ],
        null,
        TileMode.clamp,
        blackHoleAngle * 1.5,
        blackHoleAngle * 1.5 + pi * 2,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawOval(diskRect, diskPaint);
    canvas.restore();

    // Event Horizon Core Void (Black Hole Center)
    final voidPaint = Paint()..color = const Color(0xFF010104);
    canvas.drawCircle(center, radius * 0.52, voidPaint);

    final eventHorizonBorder = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(center, radius * 0.53, eventHorizonBorder);
  }

  @override
  bool shouldRepaint(covariant _Realistic3DCosmicPainter oldDelegate) => true;
}
