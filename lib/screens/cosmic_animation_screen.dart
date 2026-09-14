import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'home_screen.dart';

class CosmicLoginAnimationScreen extends StatefulWidget {
  static const routeName = '/login-cosmic';
  const CosmicLoginAnimationScreen({super.key});

  @override
  State<CosmicLoginAnimationScreen> createState() => _CosmicLoginAnimationScreenState();
}

class _CosmicLoginAnimationScreenState extends State<CosmicLoginAnimationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final Animation<double> _burst;
  late final Animation<double> _warp;
  late final Animation<double> _flare;
  late final Animation<double> _fade;
  bool _skipPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_skipPressed) {
          Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        }
      })
      ..forward();

    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.92).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 80,
      ),
    ]).animate(_controller);

    _burst = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.7, curve: Curves.easeOutExpo),
    );

    _warp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCirc),
    );

    _flare = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 1.0, curve: Curves.easeIn),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );
  }

  void _skipAnimation() {
    if (_skipPressed) return;
    _skipPressed = true;
    _controller.stop();
    if (mounted) {
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _CosmicPainter(
                    progress: _controller.value,
                    pulse: _pulse.value,
                    burst: _burst.value,
                    warp: _warp.value,
                    flare: _flare.value,
                    fade: _fade.value,
                  ),
                ),
                Positioned(
                  right: 20,
                  top: 44,
                  child: TextButton(
                    onPressed: _skipAnimation,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Skip animation'),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'NEX COSMIC LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 1.0),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          shadows: [
                            Shadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.95),
                              blurRadius: 18,
                            ),
                            Shadow(
                              color: Colors.deepPurple.withValues(alpha: 0.9),
                              blurRadius: 32,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: 1 - _fade.value,
                        child: Text(
                          'The star goes supernova and implodes into a new universe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      LinearProgressIndicator(
                        value: _controller.value,
                        backgroundColor: Colors.white12,
                        color: Colors.cyanAccent.withValues(alpha: 0.95),
                        minHeight: 10,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_controller.value * 30).round()} / 30s',
                        style: TextStyle(
                          color: Colors.white70.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CosmicPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final double burst;
  final double warp;
  final double flare;
  final double fade;

  const _CosmicPainter({
    required this.progress,
    required this.pulse,
    required this.burst,
    required this.warp,
    required this.flare,
    required this.fade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.46;

    _drawNebula(canvas, size, center);
    _drawDigitalGrid(canvas, size, center);
    _drawBurstDisk(canvas, center, radius);
    _drawRings(canvas, center, radius);
    _drawPlasmaArcs(canvas, center, radius);
    _drawEnergyBeams(canvas, size, center);
    _drawWarpCores(canvas, center, radius);
    _drawTrailComets(canvas, size, center, radius);
    _drawShockRibbons(canvas, center, radius);
    _drawLensFlares(canvas, center, radius);
    _drawGlowCanvas(canvas, center, radius);
    _drawSingularitySpike(canvas, center, radius);
    _drawStarImplosion(canvas, size, center, radius);
  }

  void _drawNebula(Canvas canvas, Size size, Offset center) {
    final nebula = const RadialGradient(
      center: Alignment(0, -0.4),
      radius: 0.95,
      colors: [
        Color(0xFF04040D),
        Color(0xFF090A17),
        Color(0xFF160C2D),
        Color(0xFF06030F),
      ],
      stops: [0.0, 0.35, 0.72, 1.0],
    ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, Paint()..shader = nebula);

    final cloudPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.65,
        colors: [
          const Color(0xFF3B0AFD).withValues(alpha: 0.36),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.shortestSide * 0.7));

    canvas.drawCircle(center.translate(-size.width * 0.1, -size.height * 0.08), size.shortestSide * 0.42, cloudPaint);

    final cloudPaint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.5, -0.2),
        radius: 0.5,
        colors: [
          const Color(0xFF00EEFF).withValues(alpha: 0.34),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.shortestSide * 0.55));

    canvas.drawCircle(center.translate(size.width * 0.14, -size.height * 0.05), size.shortestSide * 0.36, cloudPaint2);
  }

  void _drawBurstDisk(Canvas canvas, Offset center, double radius) {
    final diskPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.cyanAccent.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.22));

    canvas.drawCircle(center, radius * (0.14 + pulse * 0.1), diskPaint);
  }

  void _drawRings(Canvas canvas, Offset center, double radius) {
    for (var i = 0; i < 5; i++) {
      final ringRadius = radius * (0.22 + i * 0.12) * (0.82 + warp * 0.14);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 - i * 0.3).clamp(0.8, 2.2)
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: pi * 2,
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.7 * (1 - fade)),
            Colors.deepPurple.withValues(alpha: 0.65 * (1 - fade)),
            Colors.transparent,
            Colors.blueAccent.withValues(alpha: 0.7 * (1 - fade)),
          ],
          stops: const [0.0, 0.33, 0.67, 1.0],
          transform: GradientRotation(progress * 3.6 + i),
        ).createShader(Rect.fromCircle(center: center, radius: ringRadius));
      canvas.drawCircle(center, ringRadius, ringPaint);
    }
  }

  void _drawEnergyBeams(Canvas canvas, Size size, Offset center) {
    final beamPaint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.cyanAccent.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromLTWH(center.dx - 4, 0, 8, size.height));

    const beamCount = 6;
    for (var i = 0; i < beamCount; i++) {
      final angle = (i / beamCount) * pi + progress * 0.7;
      final base = Offset(
        center.dx + cos(angle) * size.width * 0.08,
        center.dy + sin(angle) * size.width * 0.08,
      );
      final target = Offset(
        center.dx + cos(angle) * size.width * 0.6,
        center.dy + sin(angle) * size.height * 0.6,
      );
      canvas.drawLine(base, target, beamPaint);
    }
  }

  void _drawWarpCores(Canvas canvas, Offset center, double radius) {
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4 + progress * 1.4;
      final offset = Offset(
        center.dx + cos(angle) * radius * 0.52,
        center.dy + sin(angle) * radius * 0.52,
      );
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.purpleAccent.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: offset, radius: 22));
      canvas.drawCircle(offset, 18 * (0.7 + warp * 0.3), glow);
      canvas.drawCircle(
        offset,
        4 + warp * 3,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  void _drawTrailComets(Canvas canvas, Size size, Offset center, double radius) {
    const cometCount = 9;
    for (var i = 0; i < cometCount; i++) {
      final t = (progress + i * 0.11) % 1.0;
      final angle = t * pi * 2.0;
      final length = radius * (0.48 + warp * 0.42);
      final pos = Offset(
        center.dx + cos(angle) * length,
        center.dy + sin(angle) * length,
      );
      final direction = Offset(
        cos(angle) * 0.4,
        sin(angle) * 0.4,
      );
      final tail = pos - direction * 48 * (1 - t);
      final tailPaint = Paint()
        ..shader = ui.Gradient.linear(
          tail,
          pos,
          [
            Colors.transparent,
            Colors.cyanAccent.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.9),
          ],
        )
        ..strokeWidth = 6.0 * (1 - t);
      canvas.drawLine(tail, pos, tailPaint);
      canvas.drawCircle(
        pos,
        3.5 + (0.8 - fade * 0.4),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  void _drawLensFlares(Canvas canvas, Offset center, double radius) {
    final flareRadius = radius * 0.08;
    final flarePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: flareRadius * 4));

    canvas.drawCircle(center.translate(0, -radius * 0.1), flareRadius * 3.4, flarePaint);

    for (var i = 0; i < 4; i++) {
      final offset = Offset(
        center.dx + cos(i * pi / 2 + progress * 1.1) * radius * 0.33,
        center.dy + sin(i * pi / 2 + progress * 1.1) * radius * 0.33,
      );
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.blueAccent.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: offset, radius: 18));
      canvas.drawCircle(offset, 18 * (0.8 + warp * 0.4), glow);
    }
  }

  void _drawGlowCanvas(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blueAccent.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));
    canvas.drawCircle(center, radius * (0.9 + warp * 0.1), glowPaint);
  }

  void _drawDigitalGrid(Canvas canvas, Size size, Offset center) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.cyanAccent.withValues(alpha: 0.22);

    final gridSpacing = size.shortestSide * 0.08;
    for (var dx = 0.0; dx < size.width; dx += gridSpacing) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (var dy = 0.0; dy < size.height; dy += gridSpacing) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }
  }

  void _drawPlasmaArcs(Canvas canvas, Offset center, double radius) {
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi,
        colors: [
          Colors.deepPurple.withValues(alpha: 0.75),
          Colors.deepPurple.withValues(alpha: 0.55),
          Colors.blueAccent.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.55),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.86));

    for (var i = 0; i < 3; i++) {
      final arcRadius = radius * (0.9 - i * 0.12) * (0.94 + warp * 0.08);
      final offset = Offset(center.dx, center.dy - radius * 0.08 * i);
      canvas.drawArc(
        Rect.fromCircle(center: offset, radius: arcRadius),
        progress * 2.2 + i * 0.5,
        pi * 0.84,
        false,
        arcPaint,
      );
    }
  }

  void _drawShockRibbons(Canvas canvas, Offset center, double radius) {
    final ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.8),
          Colors.cyanAccent.withValues(alpha: 0.55),
          Colors.deepPurple.withValues(alpha: 0.45),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.1));

    for (var i = 0; i < 5; i++) {
      final angle = progress * (1.6 + i * 0.12) + i * 0.7;
      final p1 = Offset(
        center.dx + cos(angle) * radius * 0.15,
        center.dy + sin(angle) * radius * 0.15,
      );
      final p2 = Offset(
        center.dx + cos(angle + 0.85) * radius * 0.72,
        center.dy + sin(angle + 0.85) * radius * 0.72,
      );
      final p3 = Offset(
        center.dx + cos(angle + 1.6) * radius * 0.95,
        center.dy + sin(angle + 1.6) * radius * 0.95,
      );
      final path = Path()..moveTo(p1.dx, p1.dy)..quadraticBezierTo(p2.dx, p2.dy, p3.dx, p3.dy);
      canvas.drawPath(path, ribbonPaint);
    }
  }

  void _drawSingularitySpike(Canvas canvas, Offset center, double radius) {
    final spikePaint = Paint()
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.square
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.yellowAccent.withValues(alpha: 0.5),
          Colors.redAccent.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    for (var i = 0; i < 12; i++) {
      final angle = i * pi / 6 + progress * 4.0;
      final length = radius * (0.3 + burst * 0.45);
      final start = Offset(
        center.dx + cos(angle) * radius * 0.08,
        center.dy + sin(angle) * radius * 0.08,
      );
      final end = Offset(
        center.dx + cos(angle) * length,
        center.dy + sin(angle) * length,
      );
      canvas.drawLine(start, end, spikePaint);
    }
  }

  void _drawStarImplosion(Canvas canvas, Size size, Offset center, double radius) {
    const starCount = 32;
    const startPhase = 0.60;
    const endPhase = 0.82;
    
    if (progress < startPhase || progress > endPhase) return;
    
    final implosionProgress = (progress - startPhase) / (endPhase - startPhase);
    final easedProgress = implosionProgress * implosionProgress * implosionProgress; // Cubic ease-in for faster implosion
    
    for (var i = 0; i < starCount; i++) {
      final angle = (i / starCount) * pi * 2 + progress * 1.2;
      final startDistance = radius * 1.4;
      final currentDistance = startDistance * (1 - easedProgress * easedProgress); // Accelerating inward
      
      final startPos = Offset(
        center.dx + cos(angle) * startDistance,
        center.dy + sin(angle) * startDistance,
      );
      
      final currentPos = Offset(
        center.dx + cos(angle) * currentDistance,
        center.dy + sin(angle) * currentDistance,
      );
      
      final starAlpha = (1 - implosionProgress).clamp(0.0, 1.0);
      final starSize = 5.0 + (1 - easedProgress) * 3.5;
      
      final starPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.98 * starAlpha),
            Colors.cyanAccent.withValues(alpha: 0.8 * starAlpha),
            Colors.deepPurple.withValues(alpha: 0.5 * starAlpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: currentPos, radius: starSize * 2.2));
      
      canvas.drawCircle(currentPos, starSize, starPaint);
      
      // More dramatic trails
      final trailPaint = Paint()
        ..strokeWidth = 2.4 * (1 - easedProgress)
        ..shader = ui.Gradient.linear(
          startPos,
          currentPos,
          [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.8 * starAlpha),
            Colors.cyanAccent.withValues(alpha: 0.95 * starAlpha),
            Colors.deepPurple.withValues(alpha: 0.7 * starAlpha),
          ],
        );
      
      canvas.drawLine(startPos, currentPos, trailPaint);
      
      // Energy pulse at center
      if (easedProgress > 0.7) {
        final pulseAlpha = (easedProgress - 0.7) / 0.3;
        final pulsePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.yellowAccent.withValues(alpha: 0.6 * pulseAlpha * starAlpha),
              Colors.redAccent.withValues(alpha: 0.4 * pulseAlpha * starAlpha),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 0.5));
        
        canvas.drawCircle(center, radius * 0.5 * pulseAlpha, pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.burst != burst ||
        oldDelegate.warp != warp ||
        oldDelegate.flare != flare ||
        oldDelegate.fade != fade;
  }
}
