import 'dart:math';
import 'package:flutter/material.dart';

class GalaxyWarBackground extends StatefulWidget {
  final Widget child;

  const GalaxyWarBackground({super.key, required this.child});

  @override
  State<GalaxyWarBackground> createState() => _GalaxyWarBackgroundState();
}

class _GalaxyWarBackgroundState extends State<GalaxyWarBackground> with TickerProviderStateMixin {
  late AnimationController _implosionController;
  late AnimationController _laserController;
  late AnimationController _debrisController;

  final Random _random = Random();
  final List<_Laser> _lasers = [];
  final List<_Debris> _debrisFields = [];

  final List<_SpaceShip> _ships = [];
  final List<_ShipLaser> _shipLasers = [];
  final List<_ExplosionParticle> _explosionParticles = [];
  final List<_PlanetImpact> _planetImpacts = [];
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();

    // Implosion cycle: 5 seconds
    _implosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    // Laser cycle
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _laserController.addListener(() {
      if (_random.nextDouble() > 0.85) {
        _spawnLaser();
      }
      _updateLasers();
      if (_screenSize != Size.zero) {
        _updateDogfightSimulation(_screenSize);
      }
      setState(() {});
    });

    // Debris parallax
    _debrisController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    for (int i = 0; i < 40; i++) {
      _debrisFields.add(_Debris(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.1 + _random.nextDouble() * 0.4,
        size: 1 + _random.nextDouble() * 3,
      ));
    }
  }

  void _spawnLaser() {
    final startLeft = _random.nextBool();
    final startY = _random.nextDouble();
    final endY = startY + (_random.nextDouble() - 0.5) * 0.5;
    
    _lasers.add(_Laser(
      startX: startLeft ? -0.1 : 1.1,
      startY: startY,
      endX: startLeft ? 1.1 : -0.1,
      endY: endY,
      progress: 0.0,
      color: _random.nextBool() ? const Color(0xFF00FFCC) : const Color(0xFFFF0055),
    ));
  }

  void _updateLasers() {
    for (int i = _lasers.length - 1; i >= 0; i--) {
      _lasers[i].progress += 0.08;
      if (_lasers[i].progress > 1.5) {
        _lasers.removeAt(i);
      }
    }
  }

  @override
  void dispose() {
    _implosionController.dispose();
    _laserController.dispose();
    _debrisController.dispose();
    super.dispose();
  }

  void _initializeShips(Size size) {
    _ships.clear();
    _shipLasers.clear();
    _explosionParticles.clear();
    _planetImpacts.clear();

    // 2 X-Wings
    for (int i = 0; i < 2; i++) {
      _ships.add(_SpaceShip(
        id: 'xwing_$i',
        isXWing: true,
        position: Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        angle: _random.nextDouble() * 2 * pi,
        speed: 2.0 + _random.nextDouble() * 1.5,
        targetPosition: Offset(size.width / 2, size.height / 2),
      ));
    }

    // 2 TIE Fighters
    for (int i = 0; i < 2; i++) {
      _ships.add(_SpaceShip(
        id: 'tie_$i',
        isXWing: false,
        position: Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        angle: _random.nextDouble() * 2 * pi,
        speed: 2.5 + _random.nextDouble() * 1.5,
        targetPosition: Offset(size.width / 2, size.height / 2),
      ));
    }
  }

  void _updateDogfightSimulation(Size size) {
    if (size == Size.zero) return;
    
    // Initialize if needed
    if (_ships.isEmpty) {
      _initializeShips(size);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Update existing ships
    for (final ship in _ships) {
      if (ship.isExploding) {
        ship.explosionTimer += 0.016;
        if (ship.explosionTimer > 2.0) {
          // Respawn at a random edge
          ship.isExploding = false;
          ship.health = 1.0;
          ship.trail.clear();
          
          final side = _random.nextInt(4);
          switch (side) {
            case 0: // Left
              ship.position = Offset(-30, _random.nextDouble() * size.height);
              ship.angle = 0.0;
              break;
            case 1: // Right
              ship.position = Offset(size.width + 30, _random.nextDouble() * size.height);
              ship.angle = pi;
              break;
            case 2: // Top
              ship.position = Offset(_random.nextDouble() * size.width, -30);
              ship.angle = pi / 2;
              break;
            case 3: // Bottom
              ship.position = Offset(_random.nextDouble() * size.width, size.height + 30);
              ship.angle = -pi / 2;
              break;
          }
          ship.target = null;
        }
        continue;
      }

      // Target selection AI
      if (ship.target == null || 
          (ship.target is _SpaceShip && (ship.target as _SpaceShip).isExploding)) {
        // Choose target
        final enemies = _ships.where((s) => s.isXWing != ship.isXWing && !s.isExploding).toList();
        if (enemies.isNotEmpty && _random.nextDouble() < 0.7) {
          // Target nearest enemy
          enemies.sort((a, b) {
            final dA = (a.position - ship.position).distanceSquared;
            final dB = (b.position - ship.position).distanceSquared;
            return dA.compareTo(dB);
          });
          ship.target = enemies.first;
        } else {
          // Target planet
          ship.target = 'planet';
        }
      }

      // Determine target coordinates
      Offset targetPos;
      if (ship.target is _SpaceShip) {
        targetPos = (ship.target as _SpaceShip).position;
      } else if (ship.target == 'planet') {
        targetPos = center;
      } else {
        targetPos = center;
      }

      // Evasion behavior: steer away if too close to center
      final toCenter = center - ship.position;
      final distToCenter = toCenter.distance;
      if (distToCenter < 120) {
        // Steer away! Override targetPos to head away from center
        targetPos = ship.position - (toCenter / (distToCenter == 0 ? 1 : distToCenter)) * 150;
      }

      // Steering calculations
      final targetAngle = atan2(targetPos.dy - ship.position.dy, targetPos.dx - ship.position.dx);
      double angleDiff = targetAngle - ship.angle;
      while (angleDiff < -pi) {
        angleDiff += 2 * pi;
      }
      while (angleDiff > pi) {
        angleDiff -= 2 * pi;
      }

      // Turn rate limit (radians per frame)
      const turnRate = 0.05;
      ship.angle += angleDiff.clamp(-turnRate, turnRate);

      // Move forward
      ship.position += Offset(cos(ship.angle), sin(ship.angle)) * ship.speed;

      // Keep inside screen bounds by steering back if they go way off
      if (ship.position.dx < -80 || ship.position.dx > size.width + 80 ||
          ship.position.dy < -80 || ship.position.dy > size.height + 80) {
        ship.target = 'planet'; // force head back to center
      }

      // Add to engine trail
      ship.trail.add(ship.position);
      if (ship.trail.length > 12) {
        ship.trail.removeAt(0);
      }

      // Shooting logic
      final distToTarget = (targetPos - ship.position).distance;
      if (now - ship.lastShotTimeMs > 600 + _random.nextInt(400)) {
        if (distToTarget < 300 && angleDiff.abs() < 0.4) {
          // Shoot!
          _shipLasers.add(_ShipLaser(
            position: ship.position + Offset(cos(ship.angle), sin(ship.angle)) * 15,
            angle: ship.angle,
            speed: 8.0,
            isGreen: !ship.isXWing,
            sourceShipId: ship.id,
            target: ship.target,
          ));
          ship.lastShotTimeMs = now;
        }
      }
    }

    // 2. Update ship lasers
    for (int i = _shipLasers.length - 1; i >= 0; i--) {
      final laser = _shipLasers[i];
      laser.position += Offset(cos(laser.angle), sin(laser.angle)) * laser.speed;

      // Check bounds
      if (laser.position.dx < -50 || laser.position.dx > size.width + 50 ||
          laser.position.dy < -50 || laser.position.dy > size.height + 50) {
        _shipLasers.removeAt(i);
        continue;
      }

      // Collision checks
      bool didCollide = false;

      if (laser.target is _SpaceShip) {
        final targetShip = laser.target as _SpaceShip;
        if (!targetShip.isExploding) {
          final dist = (laser.position - targetShip.position).distance;
          if (dist < 18) {
            // Hit!
            targetShip.isExploding = true;
            targetShip.explosionTimer = 0.0;
            didCollide = true;

            // Spawn explosion particles
            _spawnExplosion(targetShip.position, targetShip.isXWing ? const Color(0xFF00B8F4) : const Color(0xFFFF2200));
          }
        }
      } else if (laser.target == 'planet') {
        final distToPlanet = (laser.position - center).distance;
        if (distToPlanet < 60) {
          didCollide = true;
          // Spawn impact shield flare
          _planetImpacts.add(_PlanetImpact(
            position: laser.position,
            radius: 5.0,
            opacity: 1.0,
            color: laser.isGreen ? const Color(0xFF25D366) : const Color(0xFFFF0055),
          ));
          // Spawn minor sparks
          for (int j = 0; j < 5; j++) {
            _explosionParticles.add(_ExplosionParticle(
              position: laser.position,
              velocity: Offset(
                (cos(laser.angle + pi + (_random.nextDouble() - 0.5) * 1.5)) * (1.0 + _random.nextDouble() * 2.0),
                (sin(laser.angle + pi + (_random.nextDouble() - 0.5) * 1.5)) * (1.0 + _random.nextDouble() * 2.0),
              ),
              size: 1.5 + _random.nextDouble() * 2.0,
              alpha: 1.0,
              color: laser.isGreen ? const Color(0xFF25D366) : const Color(0xFFFF0055),
            ));
          }
        }
      }

      if (didCollide) {
        _shipLasers.removeAt(i);
      }
    }

    // 3. Update explosion particles
    for (int i = _explosionParticles.length - 1; i >= 0; i--) {
      final p = _explosionParticles[i];
      p.position += p.velocity;
      p.alpha -= 0.02;
      if (p.alpha <= 0) {
        _explosionParticles.removeAt(i);
      }
    }

    // 4. Update planet impacts
    for (int i = _planetImpacts.length - 1; i >= 0; i--) {
      final imp = _planetImpacts[i];
      imp.radius += 1.5;
      imp.opacity -= 0.05;
      if (imp.opacity <= 0) {
        _planetImpacts.removeAt(i);
      }
    }
  }

  void _spawnExplosion(Offset pos, Color themeColor) {
    final count = 15 + _random.nextInt(10);
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 0.5 + _random.nextDouble() * 3.5;
      final color = _random.nextBool() 
          ? themeColor 
          : (_random.nextBool() ? const Color(0xFFFFBB00) : const Color(0xFFFF4400));
      _explosionParticles.add(_ExplosionParticle(
        position: pos,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        size: 2.0 + _random.nextDouble() * 4.0,
        alpha: 1.0,
        color: color,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        // Base dark space
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF0F172A), Color(0xFF02040A)],
              center: Alignment.center,
              radius: 1.5,
            ),
          ),
        ),

        // Moving debris
        AnimatedBuilder(
          animation: _debrisController,
          builder: (context, child) {
            return CustomPaint(
              painter: _DebrisPainter(_debrisFields, _debrisController.value),
              size: Size.infinite,
            );
          },
        ),

        // Lasers
        CustomPaint(
          painter: _LaserPainter(_lasers),
          size: Size.infinite,
        ),

        // Dogfight Battle
        CustomPaint(
          painter: _DogfightPainter(
            ships: _ships,
            lasers: _shipLasers,
            particles: _explosionParticles,
            planetImpacts: _planetImpacts,
          ),
          size: Size.infinite,
        ),

        // Imploding Star
        AnimatedBuilder(
          animation: _implosionController,
          builder: (context, child) {
            final t = _implosionController.value;
            // 0.0 to 0.7: star burns and pulses
            // 0.7 to 0.8: shrinks rapidly
            // 0.8 to 0.85: explodes/shockwave
            // 0.85 to 1.0: rebuilds

            double radius = 60.0;
            double shockwaveRadius = 0.0;
            double shockwaveOpacity = 0.0;
            Color starColor = const Color(0xFFFF4400);

            if (t < 0.7) {
              // Pulsing
              radius = 60.0 + sin(t * 10 * pi) * 10;
              starColor = Color.lerp(const Color(0xFFFF4400), const Color(0xFFFFaa00), sin(t * 5 * pi).abs())!;
            } else if (t < 0.8) {
              // Shrink
              final shrinkT = (t - 0.7) / 0.1;
              radius = 70.0 * (1.0 - shrinkT * 0.9);
              starColor = Colors.white;
            } else if (t < 0.85) {
              // Shockwave
              radius = 7.0;
              final expT = (t - 0.8) / 0.05;
              shockwaveRadius = expT * 400.0;
              shockwaveOpacity = 1.0 - expT;
              starColor = const Color(0xFF00FFFF);
            } else {
              // Rebuild
              final rebT = (t - 0.85) / 0.15;
              radius = 7.0 + (60.0 - 7.0) * rebT;
              starColor = Color.lerp(const Color(0xFF00FFFF), const Color(0xFFFF4400), rebT)!;
            }

            // Screen shake effect when shockwave hits
            double shakeX = 0;
            double shakeY = 0;
            if (t > 0.8 && t < 0.9) {
              final intensity = (0.9 - t) * 50;
              shakeX = (_random.nextDouble() - 0.5) * intensity;
              shakeY = (_random.nextDouble() - 0.5) * intensity;
            }

            return Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Stack(
                children: [
                  // Shockwave
                  if (shockwaveRadius > 0)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: shockwaveRadius * 2,
                          height: shockwaveRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00FFFF).withValues(alpha: shockwaveOpacity),
                              width: 15 * shockwaveOpacity,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FFFF).withValues(alpha: shockwaveOpacity * 0.5),
                                blurRadius: 40,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // The Star
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: starColor,
                          boxShadow: [
                            BoxShadow(
                                color: starColor.withValues(alpha: 0.8),
                                blurRadius: radius,
                                spreadRadius: radius * 0.5,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.4),
                              blurRadius: radius * 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // The actual chat content layered on top (with slight translucency if needed)
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.3), // Dark overlay to ensure text readability
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _Laser {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  double progress;
  final Color color;

  _Laser({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.progress,
    required this.color,
  });
}

class _LaserPainter extends CustomPainter {
  final List<_Laser> lasers;

  _LaserPainter(this.lasers);

  @override
  void paint(Canvas canvas, Size size) {
    for (final laser in lasers) {
      final paint = Paint()
        ..color = laser.color
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

      // Laser length
      const length = 0.2;
      
      final p1x = laser.startX + (laser.endX - laser.startX) * (laser.progress - length).clamp(0.0, 1.0);
      final p1y = laser.startY + (laser.endY - laser.startY) * (laser.progress - length).clamp(0.0, 1.0);
      
      final p2x = laser.startX + (laser.endX - laser.startX) * laser.progress.clamp(0.0, 1.0);
      final p2y = laser.startY + (laser.endY - laser.startY) * laser.progress.clamp(0.0, 1.0);

      canvas.drawLine(
        Offset(p1x * size.width, p1y * size.height),
        Offset(p2x * size.width, p2y * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LaserPainter oldDelegate) => true;
}

class _Debris {
  double x;
  double y;
  final double speed;
  final double size;

  _Debris({required this.x, required this.y, required this.speed, required this.size});
}

class _DebrisPainter extends CustomPainter {
  final List<_Debris> debris;
  final double animationValue;

  _DebrisPainter(this.debris, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white54;
    for (final d in debris) {
      // Move debris diagonally
      final dx = (d.x + animationValue * d.speed) % 1.0;
      final dy = (d.y + animationValue * d.speed * 0.5) % 1.0;
      
      canvas.drawCircle(Offset(dx * size.width, dy * size.height), d.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DebrisPainter oldDelegate) => true;
}

class _SpaceShip {
  final String id;
  final bool isXWing;
  Offset position;
  double angle;
  double speed;
  Offset targetPosition;
  dynamic target;
  double health = 1.0;
  bool isExploding = false;
  double explosionTimer = 0.0;
  int lastShotTimeMs = 0;
  final List<Offset> trail = [];

  _SpaceShip({
    required this.id,
    required this.isXWing,
    required this.position,
    this.angle = 0.0,
    this.speed = 2.0,
    required this.targetPosition,
  });
}

class _ShipLaser {
  Offset position;
  final double angle;
  final double speed;
  final bool isGreen;
  final String sourceShipId;
  final dynamic target;
  bool active = true;

  _ShipLaser({
    required this.position,
    required this.angle,
    required this.speed,
    required this.isGreen,
    required this.sourceShipId,
    required this.target,
  });
}

class _ExplosionParticle {
  Offset position;
  Offset velocity;
  double size;
  double alpha;
  final Color color;

  _ExplosionParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.alpha,
    required this.color,
  });
}

class _PlanetImpact {
  final Offset position;
  double radius;
  double opacity;
  final Color color;

  _PlanetImpact({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.color,
  });
}

class _DogfightPainter extends CustomPainter {
  final List<_SpaceShip> ships;
  final List<_ShipLaser> lasers;
  final List<_ExplosionParticle> particles;
  final List<_PlanetImpact> planetImpacts;

  _DogfightPainter({
    required this.ships,
    required this.lasers,
    required this.particles,
    required this.planetImpacts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw engine trails
    for (final ship in ships) {
      if (ship.isExploding) continue;
      _drawEngineTrail(canvas, ship);
    }

    // 2. Draw ships
    for (final ship in ships) {
      if (ship.isExploding) continue;
      if (ship.isXWing) {
        _drawXWing(canvas, ship);
      } else {
        _drawTIE(canvas, ship);
      }
    }

    // 3. Draw ship lasers
    for (final laser in lasers) {
      _drawLaser(canvas, laser);
    }

    // 4. Draw explosion particles
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size, paint);
    }

    // 5. Draw planet impacts
    for (final imp in planetImpacts) {
      final paint = Paint()
        ..color = imp.color.withValues(alpha: imp.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(imp.position, imp.radius, paint);
    }
  }

  void _drawEngineTrail(Canvas canvas, _SpaceShip ship) {
    if (ship.trail.length < 2) return;
    
    final color = ship.isXWing ? const Color(0xFF00B8F4) : const Color(0xFFFF4400);
    
    for (int i = 0; i < ship.trail.length - 1; i++) {
      final p1 = ship.trail[i];
      final p2 = ship.trail[i + 1];
      final alpha = i / ship.trail.length;
      
      final paint = Paint()
        ..color = color.withValues(alpha: alpha * 0.4)
        ..strokeWidth = 1.5 + alpha * 1.5
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawXWing(Canvas canvas, _SpaceShip ship) {
    canvas.save();
    canvas.translate(ship.position.dx, ship.position.dy);
    canvas.rotate(ship.angle + pi / 2);

    final bodyPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
      
    final wingPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF00B8F4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0)
      ..style = PaintingStyle.fill;

    // Draw engine glow
    canvas.drawCircle(const Offset(-4, 8), 3, glowPaint);
    canvas.drawCircle(const Offset(4, 8), 3, glowPaint);

    // Draw wings
    final wingsPath = Path()
      ..moveTo(-4, 0)
      ..lineTo(-18, 6)
      ..lineTo(-18, 4)
      ..lineTo(-4, -2)
      ..moveTo(4, 0)
      ..lineTo(18, 6)
      ..lineTo(18, 4)
      ..lineTo(4, -2);
    canvas.drawPath(wingsPath, wingPaint);

    // Laser cannons at tips
    final cannonPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(-18, 6), const Offset(-18, -2), cannonPaint);
    canvas.drawLine(const Offset(18, 6), const Offset(18, -2), cannonPaint);

    // Main fuselage
    final fuselage = Path()
      ..moveTo(0, -16)
      ..lineTo(-3, 6)
      ..lineTo(3, 6)
      ..close();
    canvas.drawPath(fuselage, bodyPaint);

    // Cockpit glass
    final cockpitPaint = Paint()
      ..color = const Color(0xFF00B8F4)
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(-1.5, -6, 3, 6), cockpitPaint);

    canvas.restore();
  }

  void _drawTIE(Canvas canvas, _SpaceShip ship) {
    canvas.save();
    canvas.translate(ship.position.dx, ship.position.dy);
    canvas.rotate(ship.angle + pi / 2);

    final bodyPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.fill;

    final panelPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final engineGlow = Paint()
      ..color = const Color(0xFFFF2200)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0)
      ..style = PaintingStyle.fill;

    // Red engine glow
    canvas.drawCircle(const Offset(0, 3), 2.5, engineGlow);

    // Struts
    canvas.drawLine(const Offset(-5, 0), const Offset(-11, 0), borderPaint);
    canvas.drawLine(const Offset(5, 0), const Offset(11, 0), borderPaint);

    // Cockpit
    canvas.drawCircle(Offset.zero, 5, bodyPaint);
    canvas.drawCircle(Offset.zero, 5, borderPaint);
    canvas.drawLine(const Offset(-3.5, -3.5), const Offset(3.5, 3.5), borderPaint);
    canvas.drawLine(const Offset(3.5, -3.5), const Offset(-3.5, 3.5), borderPaint);

    // Left hexagonal wing panel
    final leftPanel = Path()
      ..moveTo(-11, -12)
      ..lineTo(-13, -7)
      ..lineTo(-13, 7)
      ..lineTo(-11, 12)
      ..lineTo(-9, 7)
      ..lineTo(-9, -7)
      ..close();
    canvas.drawPath(leftPanel, panelPaint);
    canvas.drawPath(leftPanel, borderPaint);

    // Right hexagonal wing panel
    final rightPanel = Path()
      ..moveTo(11, -12)
      ..lineTo(13, -7)
      ..lineTo(13, 7)
      ..lineTo(11, 12)
      ..lineTo(9, 7)
      ..lineTo(9, -7)
      ..close();
    canvas.drawPath(rightPanel, panelPaint);
    canvas.drawPath(rightPanel, borderPaint);

    canvas.restore();
  }

  void _drawLaser(Canvas canvas, _ShipLaser laser) {
    final paint = Paint()
      ..color = laser.isGreen ? const Color(0xFF25D366) : const Color(0xFFFF0055)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

    const length = 12.0;
    final endX = laser.position.dx - cos(laser.angle) * length;
    final endY = laser.position.dy - sin(laser.angle) * length;

    canvas.drawLine(
      laser.position,
      Offset(endX, endY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DogfightPainter oldDelegate) => true;
}
