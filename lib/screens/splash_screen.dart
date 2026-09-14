import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../providers/animation_provider.dart';
import '../services/game_sound_service.dart';
import '../widgets/realistic_3d_cosmic_loading.dart';
import '../widgets/scifi_animations.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreenConstants {
  static const Duration splashDuration = Duration(milliseconds: 4400);
  static const Color kDeepNavy = Color(0xFF02030A);
  static const Color kNeonPurple = Color(0xFF8B5CF6);
  static const Color kElectricCyan = Color(0xFF00E5FF);
  static const Color kNeonGreen = Color(0xFF00FF66);
  static const Color kNeonGold = Color(0xFFFFD700);
}

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _reactorScale;
  late Animation<double> _warpProgression;
  late Animation<double> _hudFade;

  StreamSubscription<AccelerometerEvent>? _gyroSub;
  double _gyroX = 0;
  double _gyroY = 0;
  double _touchX = 0;
  double _touchY = 0;

  final List<Map<String, String>> _telemetryLogs = [
    {'hex': '0x7F01', 'code': 'KERNEL', 'msg': 'QUANTUM ENTANGLEMENT ROUTER: VERIFIED', 'status': 'OK'},
    {'hex': '0x7F2A', 'code': 'CIPHER', 'msg': 'ZERO-TRUST BIOMETRIC VAULT: ARMED', 'status': 'OK'},
    {'hex': '0x7F53', 'code': 'NEURAL', 'msg': 'AI SYNAPSE MATRIX: 128-TFLOPS LOADED', 'status': 'OK'},
    {'hex': '0x7F87', 'code': '3D_ENG', 'msg': 'REAL-TIME 3D VECTOR PIPELINE: ACTIVE', 'status': 'OK'},
    {'hex': '0x7FBD', 'code': 'CLOUD', 'msg': 'SHARD REPLICATION & PRESENCE: ONLINE', 'status': 'OK'},
    {'hex': '0x7FFF', 'code': 'HYPER', 'msg': 'ALL SUBSYSTEMS NOMINAL. WARPING...', 'status': 'READY'},
  ];

  int _currentLogIndex = 0;
  Timer? _logTimer;
  Timer? _soundTimer;
  bool _navigated = false;
  bool _warpSoundPlayed = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startGyro();
    _startTelemetrySequence();
    _playInitialSounds();
  }

  void _playInitialSounds() {
    _soundTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        GameSoundService().playAlienBeam();
      }
    });
  }

  void _setupAnimations() {
    _animCtrl = AnimationController(
      vsync: this,
      duration: SplashScreenConstants.splashDuration,
    );

    // Initial reactor emergence
    _reactorScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Telemetry HUD fade in
    _hudFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.12, 0.45, curve: Curves.easeIn),
      ),
    );

    // Final hyperspace jump warp burst (last 22% of duration)
    _warpProgression = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.78, 1.0, curve: Curves.easeInExpo),
      ),
    );

    _animCtrl.addListener(() {
      // Trigger hyperspace sound right when warp starts
      if (_animCtrl.value >= 0.78 && !_warpSoundPlayed) {
        _warpSoundPlayed = true;
        GameSoundService().playHyperspace();
      }
    });

    _animCtrl.forward().then((_) => _navigateToDestination());
  }

  void _startGyro() {
    _gyroSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _gyroX = (event.x / 9.8).clamp(-1.0, 1.0);
        _gyroY = (event.y / 9.8).clamp(-1.0, 1.0);
      });
    }, onError: (_) {});
  }

  void _startTelemetrySequence() {
    const stepDuration = Duration(milliseconds: 650);
    _logTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) return;
      if (_currentLogIndex < _telemetryLogs.length - 1) {
        setState(() {
          _currentLogIndex++;
        });
        GameSoundService().playTick();
      } else {
        timer.cancel();
      }
    });
  }

  void _navigateToDestination() {
    if (_navigated) return;
    _navigated = true;
    final destination = FirebaseAuth.instance.currentUser == null
        ? LoginScreen.routeName
        : HomeScreen.routeName;
    Navigator.pushReplacementNamed(context, destination);
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _animCtrl.dispose();
    _logTimer?.cancel();
    _soundTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AnimationProvider>();
    final equippedSplashId = ap.equippedSplashAnimation;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: SplashScreenConstants.kDeepNavy,
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _touchX = (_touchX + details.delta.dx * 0.005).clamp(-1.0, 1.0);
            _touchY = (_touchY + details.delta.dy * 0.005).clamp(-1.0, 1.0);
          });
        },
        child: Stack(
          children: [
            // 1. Cosmic Background Starfield
            Positioned.fill(
              child: equippedSplashId != null
                  ? buildSciFiAnimation(equippedSplashId, gyroX: _gyroX, gyroY: _gyroY)
                  : _buildDefaultCosmicCanvas(),
            ),

            // 2. High-Tech Grid Horizon Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CyberGridFloorPainter(
                    progress: _animCtrl.value,
                    tiltX: _gyroX + _touchX,
                    tiltY: _gyroY + _touchY,
                  ),
                ),
              ),
            ),

            // 3. Central 3D Quantum Singularity Arc Reactor
            Center(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) {
                  final scale = _reactorScale.value;
                  final warp = _warpProgression.value;
                  final effectiveScale = scale * (1.0 + warp * 3.5);

                  return Transform.scale(
                    scale: effectiveScale,
                    child: SizedBox(
                      width: math.min(size.width * 0.85, 360),
                      height: math.min(size.width * 0.85, 360),
                      child: CustomPaint(
                        painter: _QuantumReactor3DPainter(
                          progress: _animCtrl.value,
                          warp: warp,
                          tiltX: _gyroX * 0.4 + _touchX * 0.6,
                          tiltY: _gyroY * 0.4 + _touchY * 0.6,
                        ),
                        child: Center(
                          child: _buildCoreBranding(warp),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. Top Operative Diagnostic HUD
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _hudFade,
                child: _buildTopTelemetryHeader(),
              ),
            ),

            // 5. Bottom Live Telemetry Terminal & Segmented Gauge
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _hudFade,
                child: _buildBottomTelemetryConsole(),
              ),
            ),

            // 6. Hyperspace Warp Jump Speed Flare
            AnimatedBuilder(
              animation: _warpProgression,
              builder: (context, _) {
                final warp = _warpProgression.value;
                if (warp <= 0.01) return const SizedBox.shrink();

                return Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HyperspaceFlarePainter(warp: warp),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCosmicCanvas() {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return Realistic3DCosmicLoadingWidget(
          statusText: _telemetryLogs[_currentLogIndex]['msg'] ?? '',
          progress: _animCtrl.value,
          isWarping: _warpProgression.value > 0.05,
        );
      },
    );
  }

  Widget _buildCoreBranding(double warp) {
    return Opacity(
      opacity: (1.0 - warp * 1.5).clamp(0.0, 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.65),
              border: Border.all(
                color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.hub_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'NEX-OS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: SplashScreenConstants.kElectricCyan,
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'QUANTUM SINGULARITY CORE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTelemetryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SplashScreenConstants.kNeonGreen,
                  boxShadow: [
                    BoxShadow(
                      color: SplashScreenConstants.kNeonGreen,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'NEXUS KERNEL 4.9.2',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: SplashScreenConstants.kElectricCyan, size: 12),
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    final percent = (_animCtrl.value * 100).toStringAsFixed(1);
                    return Text(
                      '$percent%',
                      style: const TextStyle(
                        color: SplashScreenConstants.kElectricCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTelemetryConsole() {
    final currentLog = _telemetryLogs[_currentLogIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.08),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cyber Progress Bar with Glowing Head
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, _) {
              return Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: _animCtrl.value.clamp(0.0, 1.0),
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [
                            SplashScreenConstants.kNeonPurple,
                            SplashScreenConstants.kElectricCyan,
                            Colors.white,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Active Telemetry Status Line
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SplashScreenConstants.kNeonPurple.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentLog['hex'] ?? '0x0000',
                  style: const TextStyle(
                    color: SplashScreenConstants.kNeonPurple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SplashScreenConstants.kElectricCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentLog['code'] ?? 'SYS',
                  style: const TextStyle(
                    color: SplashScreenConstants.kElectricCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                currentLog['status'] ?? 'OK',
                style: const TextStyle(
                  color: SplashScreenConstants.kNeonGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Log Description
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              currentLog['msg'] ?? '',
              key: ValueKey<String>(currentLog['msg'] ?? ''),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3D Concentric Ring Quantum Reactor Custom Painter
class _QuantumReactor3DPainter extends CustomPainter {
  final double progress;
  final double warp;
  final double tiltX;
  final double tiltY;

  _QuantumReactor3DPainter({
    required this.progress,
    required this.warp,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;

    // 1. Central Core Glow Shockwaves
    final pulseScale = 0.8 + 0.2 * math.sin(progress * math.pi * 8);
    final coreGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          SplashScreenConstants.kElectricCyan.withValues(alpha: 0.6),
          SplashScreenConstants.kNeonPurple.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 45 * pulseScale));
    canvas.drawCircle(center, 45 * pulseScale, coreGlowPaint);

    // 2. Render 4 Nested 3D Rings with Depth Sorting
    // Ring 1: Outer cyan telemetry tick ring
    _draw3DRing(
      canvas: canvas,
      center: center,
      radius: maxRadius,
      pitch: 0.35 + tiltY * 0.4,
      yaw: 0.25 + tiltX * 0.4,
      roll: progress * math.pi * 2,
      strokeWidth: 2.2,
      color: SplashScreenConstants.kElectricCyan,
      tickCount: 36,
      nodeCount: 6,
    );

    // Ring 2: Purple flux containment ring (counter-rotating)
    _draw3DRing(
      canvas: canvas,
      center: center,
      radius: maxRadius * 0.78,
      pitch: -0.45 + tiltY * 0.3,
      yaw: -0.40 + tiltX * 0.3,
      roll: -progress * math.pi * 3,
      strokeWidth: 2.6,
      color: SplashScreenConstants.kNeonPurple,
      tickCount: 24,
      nodeCount: 4,
    );

    // Ring 3: Gold tachyon acceleration ring
    _draw3DRing(
      canvas: canvas,
      center: center,
      radius: maxRadius * 0.58,
      pitch: 0.65 + tiltY * 0.2,
      yaw: -0.15 + tiltX * 0.2,
      roll: progress * math.pi * 4,
      strokeWidth: 2.0,
      color: SplashScreenConstants.kNeonGold,
      tickCount: 16,
      nodeCount: 3,
    );

    // Ring 4: Inner green stabilization ring
    _draw3DRing(
      canvas: canvas,
      center: center,
      radius: maxRadius * 0.40,
      pitch: -0.20 + tiltY * 0.1,
      yaw: 0.55 + tiltX * 0.1,
      roll: -progress * math.pi * 5,
      strokeWidth: 1.8,
      color: SplashScreenConstants.kNeonGreen,
      tickCount: 12,
      nodeCount: 2,
    );

    // 3. Lightning Plasma Arc Discharges Between Rings
    _drawPlasmaArcs(canvas, center, maxRadius);
  }

  void _draw3DRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double pitch,
    required double yaw,
    required double roll,
    required double strokeWidth,
    required Color color,
    required int tickCount,
    required int nodeCount,
  }) {
    const int segments = 72;
    final List<Map<String, dynamic>> projectedPoints = [];

    // Calculate 3D points rotated by Euler angles (pitch, yaw, roll)
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosR = math.cos(roll);
    final sinR = math.sin(roll);

    for (int i = 0; i <= segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      final x0 = radius * math.cos(theta);
      final y0 = radius * math.sin(theta);
      const z0 = 0.0;

      // Roll around Z
      final x1 = x0 * cosR - y0 * sinR;
      final y1 = x0 * sinR + y0 * cosR;
      const z1 = z0;

      // Pitch around X
      final x2 = x1;
      final y2 = y1 * cosP - z1 * sinP;
      final z2 = y1 * sinP + z1 * cosP;

      // Yaw around Y
      final x3 = x2 * cosY + z2 * sinY;
      final y3 = y2;
      final z3 = -x2 * sinY + z2 * cosY;

      // Perspective projection
      const cameraDist = 450.0;
      final factor = cameraDist / (cameraDist + z3);
      final screenX = center.dx + x3 * factor;
      final screenY = center.dy + y3 * factor;

      projectedPoints.add({
        'offset': Offset(screenX, screenY),
        'z': z3,
        'factor': factor,
        'theta': theta,
      });
    }

    // Draw ring segments with depth illumination
    for (int i = 0; i < projectedPoints.length - 1; i++) {
      final p1 = projectedPoints[i];
      final p2 = projectedPoints[i + 1];
      final avgZ = (p1['z'] + p2['z']) / 2;

      // Closer points (z < 0) are brighter; further points are dimmer
      final depthAlpha = ((1.0 - (avgZ / (radius * 1.5))) * 0.65).clamp(0.15, 1.0);
      final segmentPaint = Paint()
        ..color = color.withValues(alpha: depthAlpha)
        ..strokeWidth = strokeWidth * ((p1['factor'] + p2['factor']) / 2)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1['offset'] as Offset, p2['offset'] as Offset, segmentPaint);
    }

    // Draw ticks & orbital nodes
    final nodeStep = segments ~/ nodeCount;
    for (int i = 0; i < segments; i += nodeStep) {
      final p = projectedPoints[i];
      final avgZ = p['z'] as double;
      final factor = p['factor'] as double;
      final pos = p['offset'] as Offset;

      final depthAlpha = ((1.0 - (avgZ / (radius * 1.5))) * 0.85).clamp(0.2, 1.0);
      final nodePaint = Paint()
        ..color = Colors.white.withValues(alpha: depthAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pos, 3.5 * factor, nodePaint);

      // Node glow halo
      final glowPaint = Paint()
        ..color = color.withValues(alpha: depthAlpha * 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 7.0 * factor, glowPaint);
    }
  }

  void _drawPlasmaArcs(Canvas canvas, Offset center, double maxRadius) {
    final arcRng = math.Random((progress * 20).toInt());
    if (arcRng.nextDouble() > 0.45) return;

    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final arcPath = Path();
    final angle = arcRng.nextDouble() * math.pi * 2;
    final r1 = maxRadius * 0.4;
    final r2 = maxRadius * 0.75;

    final start = Offset(center.dx + r1 * math.cos(angle), center.dy + r1 * math.sin(angle));
    final end = Offset(center.dx + r2 * math.cos(angle + 0.3), center.dy + r2 * math.sin(angle + 0.3));
    final mid = Offset(
      (start.dx + end.dx) / 2 + (arcRng.nextDouble() - 0.5) * 20,
      (start.dy + end.dy) / 2 + (arcRng.nextDouble() - 0.5) * 20,
    );

    arcPath.moveTo(start.dx, start.dy);
    arcPath.quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    canvas.drawPath(arcPath, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _QuantumReactor3DPainter oldDelegate) => true;
}

/// Cyber Grid Floor Horizon Custom Painter
class _CyberGridFloorPainter extends CustomPainter {
  final double progress;
  final double tiltX;
  final double tiltY;

  _CyberGridFloorPainter({
    required this.progress,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.65;
    final gridPaint = Paint()
      ..color = SplashScreenConstants.kElectricCyan.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    // Perspective lines receding to vanishing point
    final vanishingPoint = Offset(size.width / 2 + tiltX * 40, horizon + tiltY * 20);
    const int numVLines = 14;
    for (int i = 0; i <= numVLines; i++) {
      final bottomX = (i / numVLines) * size.width * 1.6 - size.width * 0.3;
      canvas.drawLine(vanishingPoint, Offset(bottomX, size.height), gridPaint);
    }

    // Horizontal scanning grid lines moving forward
    const int numHLines = 8;
    for (int i = 0; i < numHLines; i++) {
      final t = ((i / numHLines) + (progress * 2)) % 1.0;
      final y = horizon + math.pow(t, 2.5) * (size.height - horizon);
      final alpha = (t * 0.18).clamp(0.0, 0.18);
      final hPaint = Paint()
        ..color = SplashScreenConstants.kElectricCyan.withValues(alpha: alpha)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridFloorPainter oldDelegate) => true;
}

/// Cinematic Hyperspace Speed Jump Warp Flare Custom Painter
class _HyperspaceFlarePainter extends CustomPainter {
  final double warp;

  _HyperspaceFlarePainter({required this.warp});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(42);

    // Radial warp lines expanding outward
    const lineCount = 90;
    for (int i = 0; i < lineCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final length = (300.0 + rng.nextDouble() * 600.0) * warp;
      final innerDist = 20.0 + rng.nextDouble() * 50.0;

      final p1 = Offset(center.dx + math.cos(angle) * innerDist, center.dy + math.sin(angle) * innerDist);
      final p2 = Offset(center.dx + math.cos(angle) * (innerDist + length), center.dy + math.sin(angle) * (innerDist + length));

      final linePaint = Paint()
        ..color = (rng.nextBool()
                ? SplashScreenConstants.kElectricCyan
                : Colors.white)
            .withValues(alpha: (warp * 0.9).clamp(0.0, 1.0))
        ..strokeWidth = (1.5 + rng.nextDouble() * 3.0) * warp
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, linePaint);
    }

    // Flash burst screen overlay
    final flashAlpha = (warp * 0.65).clamp(0.0, 0.9);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white.withValues(alpha: flashAlpha),
    );
  }

  @override
  bool shouldRepaint(covariant _HyperspaceFlarePainter oldDelegate) => true;
}
