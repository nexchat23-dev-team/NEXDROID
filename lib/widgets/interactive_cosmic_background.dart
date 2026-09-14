import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class InteractiveCosmicBackground extends StatefulWidget {
  final Widget child;

  const InteractiveCosmicBackground({super.key, required this.child});

  @override
  State<InteractiveCosmicBackground> createState() => _InteractiveCosmicBackgroundState();
}

class _InteractiveCosmicBackgroundState extends State<InteractiveCosmicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _physicsController;
  final Random _random = Random();

  // Settings
  bool _gyroMovementEnabled = false;
  double _gyroSensitivity = 1.0;
  double _gyroXOffset = 0.0;
  double _gyroYOffset = 0.0;
  bool _gyroInvertX = false;
  bool _gyroInvertY = false;
  double _gyroDeadzone = 0.08;

  // Parallax offsets
  Offset _pointerPos = Offset.zero;
  Offset _tiltOffset = Offset.zero;
  Offset _smoothedTiltOffset = Offset.zero;

  // Streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _settingsTimer;

  // Physics Entity lists
  final List<_BackgroundStar> _stars = [];
  final List<_Spaceship> _ships = [];
  final List<_PlasmaProjectile> _projectiles = [];
  final List<_BlackHole> _blackHoles = [];
  final List<_StarParticle> _implosionParticles = [];

  // Screen shake
  double _screenShakeIntensity = 0.0;

  @override
  void initState() {
    super.initState();
    _pointerPos = const Offset(200, 300); // Default placeholder target

    // Setup 60fps tick
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _physicsController.addListener(_updatePhysics);

    // Initial load
    _loadPreferences();

    // Check periodically for settings updates in SharedPreferences
    _settingsTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _loadPreferences();
    });

    // Generate initial stars
    for (int i = 0; i < 70; i++) {
      _stars.add(_BackgroundStar(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.15 + _random.nextDouble() * 0.45,
        radius: 0.8 + _random.nextDouble() * 2.0,
        color: _random.nextBool()
            ? kNeonBlue.withValues(alpha: 0.8)
            : (_random.nextBool() ? kNeonPurple.withValues(alpha: 0.8) : Colors.white),
      ));
    }

    // Generate spaceships
    _ships.add(_Spaceship(
      id: 'ship_phoenix',
      color: kNeonBlue,
      position: const Offset(80, 200),
      hoverPhaseOffset: 0.0,
      scale: 1.0,
    ));
    _ships.add(_Spaceship(
      id: 'ship_shadow',
      color: kNeonPurple,
      position: const Offset(320, 500),
      hoverPhaseOffset: pi * 0.6,
      scale: 0.85,
    ));
    _ships.add(_Spaceship(
      id: 'ship_reaper',
      color: kNeonGreen,
      position: const Offset(200, 150),
      hoverPhaseOffset: pi * 1.2,
      scale: 0.9,
    ));
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final gyroEnabled = prefs.getBool('gyroMovementEnabled') ?? false;
    final sensitivity = prefs.getDouble('gyroSensitivity') ?? 1.0;
    final xOff = prefs.getDouble('gyroXOffset') ?? 0.0;
    final yOff = prefs.getDouble('gyroYOffset') ?? 0.0;
    final invertX = prefs.getBool('gyroInvertX') ?? false;
    final invertY = prefs.getBool('gyroInvertY') ?? false;
    final deadzone = prefs.getDouble('gyroDeadzone') ?? 0.08;

    if (mounted) {
      setState(() {
        _gyroMovementEnabled = gyroEnabled;
        _gyroSensitivity = sensitivity;
        _gyroXOffset = xOff;
        _gyroYOffset = yOff;
        _gyroInvertX = invertX;
        _gyroInvertY = invertY;
        _gyroDeadzone = deadzone;
      });
      _setupGyroSubscription();
    }
  }

  void _setupGyroSubscription() {
    if (_gyroMovementEnabled && _accelerometerSubscription == null) {
      _accelerometerSubscription = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        // Compute delta from calibration baseline and deadzone threshold
        final rawX = event.x - _gyroXOffset;
        final rawY = event.y - _gyroYOffset;
        final adjustedX = rawX.abs() < _gyroDeadzone ? 0.0 : rawX;
        final adjustedY = rawY.abs() < _gyroDeadzone ? 0.0 : rawY;
        final xDirection = _gyroInvertX ? adjustedX : -adjustedX;
        final yDirection = _gyroInvertY ? -adjustedY : adjustedY;

        setState(() {
          _tiltOffset = Offset(
            xDirection * 28.0 * _gyroSensitivity,
            yDirection * 28.0 * _gyroSensitivity,
          );
        });
      });
    } else if (!_gyroMovementEnabled && _accelerometerSubscription != null) {
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
      setState(() {
        _tiltOffset = Offset.zero;
      });
    }
  }

  void _updatePhysics() {
    if (!mounted) return;

    final Size size = MediaQuery.sizeOf(context);
    if (size == Size.zero) return;

    // 1. Smoothly interpolate tilt offset to prevent jittery movements
    _smoothedTiltOffset = Offset(
      _smoothedTiltOffset.dx + (_tiltOffset.dx - _smoothedTiltOffset.dx) * 0.12,
      _smoothedTiltOffset.dy + (_tiltOffset.dy - _smoothedTiltOffset.dy) * 0.12,
    );

    // Decay screen shake
    if (_screenShakeIntensity > 0) {
      _screenShakeIntensity -= 0.35;
      if (_screenShakeIntensity < 0) _screenShakeIntensity = 0.0;
    }

    // 2. Update Spaceships
    final hoverTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (final ship in _ships) {
      // Spaceship floating motion: gentle oscillation using sine waves
      final oscillationY = sin(hoverTime * 1.5 + ship.hoverPhaseOffset) * 12.0;
      final oscillationX = cos(hoverTime * 0.8 + ship.hoverPhaseOffset) * 6.0;

      // Spaceship tracks the cursor/pointer with friction/lag (parallaxes relative to cursor + gyro tilt)
      // Set target offset
      Offset shipTarget = ship.position;
      if (ship.id == 'ship_phoenix') {
        shipTarget = Offset(size.width * 0.15, size.height * 0.3) + _smoothedTiltOffset * 0.45;
      } else if (ship.id == 'ship_shadow') {
        shipTarget = Offset(size.width * 0.8, size.height * 0.72) + _smoothedTiltOffset * 0.8;
      } else if (ship.id == 'ship_reaper') {
        shipTarget = Offset(size.width * 0.5, size.height * 0.18) + _smoothedTiltOffset * 0.6;
      }

      // Smooth floating lag towards targets
      final dx = shipTarget.dx - ship.position.dx;
      final dy = shipTarget.dy - ship.position.dy;
      ship.position = Offset(
        ship.position.dx + dx * 0.035 + oscillationX * 0.1,
        ship.position.dy + dy * 0.035 + oscillationY * 0.1,
      );

      // Save engine trails
      ship.trail.add(ship.position);
      if (ship.trail.length > 14) {
        ship.trail.removeAt(0);
      }

      // Rotate ship to face either the active black hole or the user pointer
      Offset rotationTarget = _pointerPos;
      if (_blackHoles.isNotEmpty) {
        // Face the newest black hole!
        rotationTarget = _blackHoles.last.position;
      }
      final targetAngle = atan2(rotationTarget.dy - ship.position.dy, rotationTarget.dx - ship.position.dx);
      
      // Interpolate angle
      double diff = targetAngle - ship.angle;
      while (diff < -pi) {
        diff += 2 * pi;
      }
      while (diff > pi) {
        diff -= 2 * pi;
      }
      ship.angle += diff * 0.08;
    }

    // 3. Update Black Holes
    for (int i = _blackHoles.length - 1; i >= 0; i--) {
      final bh = _blackHoles[i];
      bh.age += 1;

      // Accelerate rotation of accretion disks
      bh.rotationAngle += 0.045 + (bh.age * 0.0005);

      // Expansion phase
      if (bh.age < 30) {
        bh.radius = (bh.age / 30.0) * bh.maxRadius;
      } else if (bh.age > 160) {
        // Implosion phase: shrinks rapidly to 0
        final progress = (bh.age - 160) / 20.0;
        if (progress >= 1.0) {
          // Implosion complete! Trigger screen shake and shockwave
          _screenShakeIntensity = 18.0;
          _triggerShockwave(bh.position, bh.maxRadius * 3.5);
          _blackHoles.removeAt(i);
          continue;
        } else {
          bh.radius = bh.maxRadius * (1.0 - progress);
        }
      } else {
        bh.radius = bh.maxRadius + sin(bh.age * 0.08) * 1.5;
      }
    }

    // 4. Update Projectiles
    for (int i = _projectiles.length - 1; i >= 0; i--) {
      final p = _projectiles[i];
      final toTarget = p.target - p.position;
      final distance = toTarget.distance;

      if (distance < 14.0) {
        // Spawn black hole at target!
        _spawnBlackHole(p.target);
        _projectiles.removeAt(i);
      } else {
        // Fly towards target
        final direction = toTarget / distance;
        p.position += direction * p.speed;
        p.speed += 0.65; // Accelerate projectile flight
      }
    }

    // 5. Update Stars/Particles (Gravity accretion physics)
    for (final star in _stars) {
      double pullX = 0;
      double pullY = 0;
      bool captured = false;

      // Apply gravitational forces from active black holes
      for (final bh in _blackHoles) {
        final toBh = bh.position - Offset(star.x * size.width, star.y * size.height);
        final dist = toBh.distance;
        if (dist < bh.radius * 3.8 && dist > 1.0) {
          // Gravity pull strength increases exponentially closer to core
          final force = (bh.radius * 2.8) / (dist * dist + 400.0);
          final pullFactor = force.clamp(0.0, 7.5);
          
          // Tangential spiral orbit forces
          final tangentX = -toBh.dy / dist;
          final tangentY = toBh.dx / dist;

          pullX += (toBh.dx / dist) * pullFactor + tangentX * (pullFactor * 0.8);
          pullY += (toBh.dy / dist) * pullFactor + tangentY * (pullFactor * 0.8);

          if (dist < bh.radius * 0.28) {
            captured = true;
          }
        }
      }

      if (captured) {
        // Respawn at a random screen edge
        if (_random.nextBool()) {
          star.x = _random.nextBool() ? 0.0 : 1.0;
          star.y = _random.nextDouble();
        } else {
          star.x = _random.nextDouble();
          star.y = _random.nextBool() ? 0.0 : 1.0;
        }
      } else {
        // Convert pull forces to normalized coordinates
        star.x += pullX / size.width;
        star.y += pullY / size.height;

        // Base background space drift
        star.x -= (star.speed * 0.0003);
        if (star.x < 0) {
          star.x = 1.0;
          star.y = _random.nextDouble();
        }
      }
    }

    // 6. Update Implosion particles
    for (int i = _implosionParticles.length - 1; i >= 0; i--) {
      final p = _implosionParticles[i];
      p.position += p.velocity;
      p.velocity = Offset(p.velocity.dx * 0.94, p.velocity.dy * 0.94); // friction
      p.opacity -= 0.024;
      p.size += 0.12;

      if (p.opacity <= 0) {
        _implosionParticles.removeAt(i);
      }
    }

    setState(() {});
  }

  void _triggerShockwave(Offset center, double finalRadius) {
    // Generate star/shockwave explosion particles
    final int count = 30 + _random.nextInt(20);
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 8.5;
      final color = _random.nextBool() ? kNeonGreen : (_random.nextBool() ? kNeonBlue : Colors.white);
      
      _implosionParticles.add(_StarParticle(
        position: center,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        size: 2.0 + _random.nextDouble() * 4.0,
        opacity: 1.0,
        color: color,
      ));
    }
  }

  void _spawnBlackHole(Offset target) {
    // Limit to 2 concurrent black holes to avoid cluttering screen
    if (_blackHoles.length >= 2) {
      _blackHoles.removeAt(0);
    }
    _blackHoles.add(_BlackHole(
      position: target,
      maxRadius: 50.0 + _random.nextDouble() * 20.0,
    ));
  }

  void _triggerSelectionAnimation(Offset target) {
    if (_ships.isEmpty) return;

    // Find ship closest to selection target
    _Spaceship closestShip = _ships.first;
    double minDist = (closestShip.position - target).distance;

    for (final ship in _ships) {
      final d = (ship.position - target).distance;
      if (d < minDist) {
        minDist = d;
        closestShip = ship;
      }
    }

    // Launch projectile from closest ship
    final launchAngle = atan2(target.dy - closestShip.position.dy, target.dx - closestShip.position.dx);
    final muzzleOffset = Offset(cos(launchAngle) * 22, sin(launchAngle) * 22);

    _projectiles.add(_PlasmaProjectile(
      position: closestShip.position + muzzleOffset,
      target: target,
      speed: 4.5,
      color: closestShip.color,
    ));
  }

  @override
  void dispose() {
    _physicsController.removeListener(_updatePhysics);
    _physicsController.dispose();
    _accelerometerSubscription?.cancel();
    _settingsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double shakeX = 0;
    double shakeY = 0;
    if (_screenShakeIntensity > 0) {
      shakeX = (_random.nextDouble() - 0.5) * _screenShakeIntensity;
      shakeY = (_random.nextDouble() - 0.5) * _screenShakeIntensity;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerPos = event.localPosition;
        _triggerSelectionAnimation(event.localPosition);
      },
      onPointerMove: (event) {
        _pointerPos = event.localPosition;
      },
      onPointerHover: (event) {
        _pointerPos = event.localPosition;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background custom paint shifts with screen shake
          Transform.translate(
            offset: Offset(shakeX, shakeY),
            child: CustomPaint(
              painter: _InteractiveCosmicPainter(
                stars: _stars,
                ships: _ships,
                projectiles: _projectiles,
                blackHoles: _blackHoles,
                particles: _implosionParticles,
                smoothedTiltOffset: _smoothedTiltOffset,
              ),
              size: Size.infinite,
            ),
          ),
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// Data Entities
class _BackgroundStar {
  double x; // 0.0 to 1.0
  double y; // 0.0 to 1.0
  final double speed;
  final double radius;
  final Color color;

  _BackgroundStar({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.color,
  });
}

class _Spaceship {
  final String id;
  final Color color;
  Offset position;
  final double hoverPhaseOffset;
  double angle = 0.0;
  final double scale;
  final List<Offset> trail = [];

  _Spaceship({
    required this.id,
    required this.color,
    required this.position,
    required this.hoverPhaseOffset,
    required this.scale,
  });
}

class _PlasmaProjectile {
  Offset position;
  final Offset target;
  double speed;
  final Color color;

  _PlasmaProjectile({
    required this.position,
    required this.target,
    required this.speed,
    required this.color,
  });
}

class _BlackHole {
  final Offset position;
  double radius = 0.0;
  final double maxRadius;
  int age = 0;
  double rotationAngle = 0.0;

  _BlackHole({
    required this.position,
    required this.maxRadius,
  });
}

class _StarParticle {
  Offset position;
  Offset velocity;
  double size;
  double opacity;
  final Color color;

  _StarParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

// Custom Painter
class _InteractiveCosmicPainter extends CustomPainter {
  final List<_BackgroundStar> stars;
  final List<_Spaceship> ships;
  final List<_PlasmaProjectile> projectiles;
  final List<_BlackHole> blackHoles;
  final List<_StarParticle> particles;
  final Offset smoothedTiltOffset;

  const _InteractiveCosmicPainter({
    required this.stars,
    required this.ships,
    required this.projectiles,
    required this.blackHoles,
    required this.particles,
    required this.smoothedTiltOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Solid cosmic background gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, 1000),
        [Color(0xFF02040E), Color(0xFF0C071C), Color(0xFF030A18)],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(rect, bgPaint);

    // 2. Animated Cosmic Auroras/Nebulae
    // Shift slightly with gyro tilt to add layered 3D parallax depth
    _drawNebula(canvas, size, Offset(size.width * 0.25, size.height * 0.25) + smoothedTiltOffset * 0.15, size.width * 0.46, const Color(0xFF280FFF));
    _drawNebula(canvas, size, Offset(size.width * 0.78, size.height * 0.72) + smoothedTiltOffset * 0.25, size.width * 0.38, const Color(0xFF860FFF));
    _drawNebula(canvas, size, Offset(size.width * 0.5, size.height * 0.55) + smoothedTiltOffset * 0.2, size.width * 0.3, const Color(0x9925D366));

    // 3. Sci-Fi Digital Cyber Grid Lines (parallax background layer)
    _drawSciFiGrid(canvas, size, smoothedTiltOffset * 0.35);

    // 4. Background Starfield
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (final star in stars) {
      starPaint.color = star.color;
      canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.radius, starPaint);
    }

    // 5. Draw Black Hole Singularity accretion disks
    for (final bh in blackHoles) {
      _drawBlackHole(canvas, bh);
    }

    // 6. Draw Plasma Projectiles
    for (final proj in projectiles) {
      final pPaint = Paint()
        ..color = proj.color
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
      canvas.drawCircle(proj.position, 6.0, pPaint);
      
      // Inner white core
      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(proj.position, 2.5, corePaint);
    }

    // 7. Draw Spaceships and engine trails
    for (final ship in ships) {
      _drawSpaceship(canvas, ship);
    }

    // 8. Shockwave collapse particles
    for (final p in particles) {
      final pPaint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size, pPaint);
    }
  }

  void _drawNebula(Canvas canvas, Size size, Offset center, double radius, Color baseColor) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [baseColor.withValues(alpha: 0.16), Colors.transparent],
        const [0.0, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  void _drawSciFiGrid(Canvas canvas, Size size, Offset offset) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1F2F6F).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Apply modular offset to grid to simulate infinite scrolling
    const double spacing = 90.0;
    final double startX = (offset.dx % spacing) - spacing;
    final double startY = (offset.dy % spacing) - spacing;

    for (double x = startX; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = startY; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Cyber concentric hud details
    final center = size.center(Offset.zero) + offset * 0.6;
    final circlePaint = Paint()
      ..color = const Color(0xFF00FFBB).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 120.0, circlePaint);
    canvas.drawCircle(center, 280.0, circlePaint);
  }

  void _drawBlackHole(Canvas canvas, _BlackHole bh) {
    final center = bh.position;
    final double r = bh.radius;

    if (r <= 0) return;

    // Accretion disk glow (Large outer neon ring)
    final outerGlow = Paint()
      ..shader = ui.Gradient.radial(
        center,
        r * 2.2,
        [
          kNeonPurple.withValues(alpha: 0.65),
          kNeonBlue.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(center, r * 2.2, outerGlow);

    // Accretion swirl disk (Concentric rotating arcs)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bh.rotationAngle);

    final diskPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [
          kNeonPurple,
          kNeonBlue,
          kNeonGreen,
          kNeonPurple,
        ],
      );

    // Draw accretion rings
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 1.3), 0, pi * 1.4, false, diskPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 1.5), pi, pi * 1.3, false, diskPaint);

    canvas.restore();

    // Event Horizon (Solid black void core)
    final corePaint = Paint()
      ..color = const Color(0xFF030308)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.84, corePaint);

    // White hot gravity boundary line
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);
    canvas.drawCircle(center, r * 0.85, borderPaint);
  }

  void _drawSpaceship(Canvas canvas, _Spaceship ship) {
    if (ship.trail.length < 2) return;

    // 1. Draw engine exhaust tail
    for (int i = 0; i < ship.trail.length - 1; i++) {
      final p1 = ship.trail[i];
      final p2 = ship.trail[i + 1];
      final progress = i / ship.trail.length;

      final trailPaint = Paint()
        ..color = ship.color.withValues(alpha: progress * 0.35)
        ..strokeWidth = (2.0 + progress * 4.0) * ship.scale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, trailPaint);
    }

    // 2. Draw ship geometry body
    canvas.save();
    canvas.translate(ship.position.dx, ship.position.dy);
    canvas.rotate(ship.angle + pi / 2); // default face vector upwards
    canvas.scale(ship.scale);

    // Draw vector polygon lines to form a premium game character spaceship
    final shipPath = Path();
    // Nose
    shipPath.moveTo(0, -22);
    // Left Wing
    shipPath.lineTo(-14, 14);
    shipPath.lineTo(-6, 8);
    // Exhaust thruster
    shipPath.lineTo(0, 15);
    // Right Wing
    shipPath.lineTo(6, 8);
    shipPath.lineTo(14, 14);
    shipPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF131A3A).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shipPath, fillPaint);

    final linePaint = Paint()
      ..color = ship.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(shipPath, linePaint);

    // Thruster engine core glow
    final thrusterPaint = Paint()
      ..color = const Color(0xFFFF9900)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawCircle(const Offset(0, 16), 4.5, thrusterPaint);
    canvas.drawCircle(const Offset(0, 16), 2.0, Paint()..color = Colors.white);

    // Laser battery cannons on wingtips
    canvas.drawLine(const Offset(-13, 8), const Offset(-13, -4), linePaint);
    canvas.drawLine(const Offset(13, 8), const Offset(13, -4), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InteractiveCosmicPainter oldDelegate) => true;
}
