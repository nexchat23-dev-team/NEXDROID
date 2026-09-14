import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogoCyberMode {
  quantumCore,
  bioPulse,
  forceShield,
  neuralGalaxy,
  warpSpeed,
  plasmaArcs,
  solarCorona,
  singularityVoid,
}

class DynamicMorphingLogoWidget extends StatefulWidget {
  final double size;
  final bool showText;
  final bool? enableAnimation;
  final VoidCallback? onTap;

  const DynamicMorphingLogoWidget({
    super.key,
    this.size = 48.0,
    this.showText = true,
    this.enableAnimation,
    this.onTap,
  });

  @override
  State<DynamicMorphingLogoWidget> createState() => _DynamicMorphingLogoWidgetState();
}

class _DynamicMorphingLogoWidgetState extends State<DynamicMorphingLogoWidget>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _shockwaveController;
  late AnimationController _sparkleController;

  StreamSubscription? _gyroSub;
  double _gyroX = 0.0;
  double _gyroY = 0.0;

  int _manualModeIndex = 0;
  bool _useManualMode = false;
  Offset _tapPosition = Offset.zero;
  bool _isTapped = false;
  bool _isAnimationEnabled = true;

  final List<LogoCyberMode> _allModes = LogoCyberMode.values;

  @override
  void initState() {
    super.initState();
    // Continuous smooth morphing through all 8 geometric states (loops every 16 seconds)
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    // Continuous 3D rotation of outer energy ring (loops every 8 seconds)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // High-speed 60FPS pulse & breathing (loops every 1.5 seconds)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Shockwave burst on tap
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Sparkle discharge & electric lightning arcs
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _loadAnimationSetting();
    _startGyro();
  }

  Future<void> _loadAnimationSetting() async {
    if (widget.enableAnimation != null) {
      if (mounted) setState(() => _isAnimationEnabled = widget.enableAnimation!);
      _updateControllers();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('morphingLogoAnimationEnabled') ?? true;
    if (mounted) {
      setState(() => _isAnimationEnabled = enabled);
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (!_isAnimationEnabled) {
      _morphController.stop();
      _rotationController.stop();
      _pulseController.stop();
      _sparkleController.stop();
    } else {
      if (!_morphController.isAnimating) _morphController.repeat();
      if (!_rotationController.isAnimating) _rotationController.repeat();
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      if (!_sparkleController.isAnimating) _sparkleController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DynamicMorphingLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimation != oldWidget.enableAnimation) {
      _loadAnimationSetting();
    }
  }

  void _startGyro() {
    _gyroSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _gyroX = (event.x / 9.81).clamp(-1.0, 1.0);
        _gyroY = (event.y / 9.81).clamp(-1.0, 1.0);
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _morphController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _shockwaveController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
      _isTapped = true;
      if (_isAnimationEnabled) {
        _useManualMode = true;
        _manualModeIndex = (_manualModeIndex + 1) % _allModes.length;
      }
    });

    if (_isAnimationEnabled) {
      _shockwaveController.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _isTapped = false);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _isTapped = false);
      });
    }

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _morphController,
          _rotationController,
          _pulseController,
          _shockwaveController,
          _sparkleController,
        ]),
        builder: (context, child) {
          final rawMorph = _isAnimationEnabled ? _morphController.value : 0.0;
          final rotVal = _isAnimationEnabled ? _rotationController.value : 0.0;
          final pulseVal = _isAnimationEnabled ? _pulseController.value : 0.0;
          final shockVal = _isAnimationEnabled ? _shockwaveController.value : 0.0;
          final sparkVal = _isAnimationEnabled ? _sparkleController.value : 0.0;

          final effectiveMorph = _useManualMode && _isAnimationEnabled
              ? (_manualModeIndex / _allModes.length)
              : rawMorph;

          final activeMode = _isAnimationEnabled
              ? _allModes[(effectiveMorph * _allModes.length).floor() % _allModes.length]
              : LogoCyberMode.quantumCore;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Programmatic 3D Code-Rendered Morphing Logo Canvas
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _AdvancedMorphingLogoPainter(
                  morphProgress: effectiveMorph,
                  rotationProgress: rotVal,
                  pulseProgress: pulseVal,
                  shockwaveProgress: shockVal,
                  sparkleProgress: sparkVal,
                  mode: activeMode,
                  gyroX: _isAnimationEnabled ? _gyroX : 0.0,
                  gyroY: _isAnimationEnabled ? _gyroY : 0.0,
                  isTapped: _isTapped,
                  tapPosition: _tapPosition,
                ),
              ),

              if (widget.showText) ...[
                const SizedBox(width: 10),
                _buildMorphingText(effectiveMorph, pulseVal, activeMode),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMorphingText(double morphVal, double pulseVal, LogoCyberMode mode) {
    final modeColors = _getColorsForMode(mode);
    final color1 = modeColors[0];
    final color2 = modeColors[1];
    final modeTitle = _getModeTitle(mode);

    final glowBlur = 4.0 + pulseVal * 6.0;
    final safeTitleSize = math.min(widget.size * 0.42, 16.0).toDouble();
    final safeModeSize = math.min(widget.size * 0.18, 8.5).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [color1, color2, const Color(0xFF00FF66)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'NEXDROID',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: safeTitleSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              shadows: [
                Shadow(color: color1.withValues(alpha: 0.85), blurRadius: glowBlur),
              ],
            ),
          ),
        ),
        Text(
          'MODE :: $modeTitle',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color2,
            fontSize: safeModeSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  String _getModeTitle(LogoCyberMode mode) {
    switch (mode) {
      case LogoCyberMode.quantumCore:
        return 'QUANTUM CORE';
      case LogoCyberMode.bioPulse:
        return 'BIO-NEURAL';
      case LogoCyberMode.forceShield:
        return 'FORCE SHIELD';
      case LogoCyberMode.neuralGalaxy:
        return 'NEURAL GALAXY';
      case LogoCyberMode.warpSpeed:
        return 'WARP SPEED';
      case LogoCyberMode.plasmaArcs:
        return 'PLASMA ARCS';
      case LogoCyberMode.solarCorona:
        return 'SOLAR CORONA';
      case LogoCyberMode.singularityVoid:
        return 'SINGULARITY';
    }
  }

  List<Color> _getColorsForMode(LogoCyberMode mode) {
    switch (mode) {
      case LogoCyberMode.quantumCore:
        return const [Color(0xFF00E5FF), Color(0xFF3B82F6)];
      case LogoCyberMode.bioPulse:
        return const [Color(0xFF00FF66), Color(0xFF10B981)];
      case LogoCyberMode.forceShield:
        return const [Color(0xFFC084FC), Color(0xFF8B5CF6)];
      case LogoCyberMode.neuralGalaxy:
        return const [Color(0xFFFF2A85), Color(0xFFEC4899)];
      case LogoCyberMode.warpSpeed:
        return const [Color(0xFF00E5FF), Color(0xFF6366F1)];
      case LogoCyberMode.plasmaArcs:
        return const [Color(0xFFFFD166), Color(0xFFF59E0B)];
      case LogoCyberMode.solarCorona:
        return const [Color(0xFFFF4500), Color(0xFFFF8C00)];
      case LogoCyberMode.singularityVoid:
        return const [Color(0xFFA855F7), Color(0xFF06B6D4)];
    }
  }
}

class _AdvancedMorphingLogoPainter extends CustomPainter {
  final double morphProgress;
  final double rotationProgress;
  final double pulseProgress;
  final double shockwaveProgress;
  final double sparkleProgress;
  final LogoCyberMode mode;
  final double gyroX;
  final double gyroY;
  final bool isTapped;
  final Offset tapPosition;

  _AdvancedMorphingLogoPainter({
    required this.morphProgress,
    required this.rotationProgress,
    required this.pulseProgress,
    required this.shockwaveProgress,
    required this.sparkleProgress,
    required this.mode,
    required this.gyroX,
    required this.gyroY,
    required this.isTapped,
    required this.tapPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gyro camera parallax shift
    final centerOffset = Offset(gyroX * 4.0, gyroY * 4.0);
    final center = Offset(size.width / 2, size.height / 2) + centerOffset;
    final radius = math.min(size.width, size.height) / 2;

    final primaryColor = _getPrimaryColor(mode);
    final secondaryColor = _getSecondaryColor(mode);

    // 1. Outer Rotating Energy Ring with Orbiting Photons
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.1),
          primaryColor,
          secondaryColor,
          const Color(0xFF00FF66),
          primaryColor.withValues(alpha: 0.1),
        ],
        transform: GradientRotation(rotationProgress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.92, ringPaint);

    // 2. Orbiting Photon Nodes
    for (int i = 0; i < 6; i++) {
      final angle = rotationProgress * 2 * math.pi + (i * math.pi / 3);
      final px = center.dx + (radius * 0.92) * math.cos(angle);
      final py = center.dy + (radius * 0.92) * math.sin(angle);
      final photonColor = i % 2 == 0 ? primaryColor : secondaryColor;

      canvas.drawCircle(
        Offset(px, py),
        4.5,
        Paint()
          ..color = photonColor.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawCircle(Offset(px, py), 2.2, Paint()..color = Colors.white);
    }

    // 3. Electric Lightning Arcs Firing Between Outer Ring & Center
    if (mode == LogoCyberMode.plasmaArcs || mode == LogoCyberMode.quantumCore) {
      final rndAngle = (sparkleProgress * 2 * math.pi);
      final arcStart = Offset(
        center.dx + (radius * 0.85) * math.cos(rndAngle),
        center.dy + (radius * 0.85) * math.sin(rndAngle),
      );

      final arcPath = Path();
      arcPath.moveTo(arcStart.dx, arcStart.dy);
      final mid = Offset(
        (arcStart.dx + center.dx) / 2 + (sparkleProgress * 6.0 - 3.0),
        (arcStart.dy + center.dy) / 2 + (sparkleProgress * 6.0 - 3.0),
      );
      arcPath.lineTo(mid.dx, mid.dy);
      arcPath.lineTo(center.dx, center.dy);

      canvas.drawPath(
        arcPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // 4. Mode-Specific Core Geometry Rendering
    final scale = 0.62 + pulseProgress * 0.08;
    final coreRadius = radius * scale;

    final path = Path();
    int pointsCount = 6;
    if (mode == LogoCyberMode.forceShield) pointsCount = 3;
    if (mode == LogoCyberMode.neuralGalaxy) pointsCount = 8;
    if (mode == LogoCyberMode.solarCorona) pointsCount = 12;

    for (int i = 0; i < pointsCount; i++) {
      final angle = (i * 2 * math.pi / pointsCount) + (rotationProgress * math.pi * 0.5);
      double rMod = 1.0;
      if (mode == LogoCyberMode.solarCorona) {
        rMod = (i % 2 == 0) ? 1.2 : 0.8;
      } else if (mode == LogoCyberMode.bioPulse) {
        rMod = 1.0 + 0.15 * math.sin(angle * 4 + pulseProgress * 2 * math.pi);
      }

      final r = coreRadius * rMod;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Core Shadow Blur
    canvas.drawPath(
      path,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Core Fill Gradient
    final coreGradient = LinearGradient(
      colors: [primaryColor, secondaryColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );

    // 5. Engraved Cyber "N" Emblem
    final emblemPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final nPath = Path();
    final s = radius * 0.26;
    nPath.moveTo(center.dx - s, center.dy + s);
    nPath.lineTo(center.dx - s, center.dy - s);
    nPath.lineTo(center.dx + s, center.dy + s);
    nPath.lineTo(center.dx + s, center.dy - s);
    canvas.drawPath(nPath, emblemPaint);

    // 6. Tap Shockwave Radial Explosion Burst
    if (shockwaveProgress > 0.0) {
      final waveRadius = radius * 2.2 * shockwaveProgress;
      final wavePaint = Paint()
        ..color = primaryColor.withValues(alpha: (1.0 - shockwaveProgress) * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * (1.0 - shockwaveProgress);

      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  Color _getPrimaryColor(LogoCyberMode mode) {
    switch (mode) {
      case LogoCyberMode.quantumCore:
        return const Color(0xFF00E5FF);
      case LogoCyberMode.bioPulse:
        return const Color(0xFF00FF66);
      case LogoCyberMode.forceShield:
        return const Color(0xFFC084FC);
      case LogoCyberMode.neuralGalaxy:
        return const Color(0xFFFF2A85);
      case LogoCyberMode.warpSpeed:
        return const Color(0xFF00E5FF);
      case LogoCyberMode.plasmaArcs:
        return const Color(0xFFFFD166);
      case LogoCyberMode.solarCorona:
        return const Color(0xFFFF4500);
      case LogoCyberMode.singularityVoid:
        return const Color(0xFFA855F7);
    }
  }

  Color _getSecondaryColor(LogoCyberMode mode) {
    switch (mode) {
      case LogoCyberMode.quantumCore:
        return const Color(0xFF3B82F6);
      case LogoCyberMode.bioPulse:
        return const Color(0xFF10B981);
      case LogoCyberMode.forceShield:
        return const Color(0xFF8B5CF6);
      case LogoCyberMode.neuralGalaxy:
        return const Color(0xFFEC4899);
      case LogoCyberMode.warpSpeed:
        return const Color(0xFF6366F1);
      case LogoCyberMode.plasmaArcs:
        return const Color(0xFFF59E0B);
      case LogoCyberMode.solarCorona:
        return const Color(0xFFFF8C00);
      case LogoCyberMode.singularityVoid:
        return const Color(0xFF06B6D4);
    }
  }

  @override
  bool shouldRepaint(covariant _AdvancedMorphingLogoPainter oldDelegate) => true;
}
