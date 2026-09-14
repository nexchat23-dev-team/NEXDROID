import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/compass_utils.dart';
import '../utils/constants.dart';

class CompassScreen extends StatefulWidget {
  static const routeName = '/compass';

  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> with TickerProviderStateMixin {
  double _heading = 0;
  double _accuracy = 0;
  bool _isLive = false;
  String _status = 'Waiting for heading…';
  StreamSubscription<CompassEvent>? _headingSubscription;
  bool _permissionGranted = false;
  late final AnimationController _ringController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _initializeCompass();
  }

  Future<void> _initializeCompass() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      final requested = await Permission.locationWhenInUse.request();
      if (!mounted) return;
      setState(() => _permissionGranted = requested.isGranted);
    } else {
      if (!mounted) return;
      setState(() => _permissionGranted = status.isGranted);
    }

    if (!_permissionGranted) {
      setState(() => _status = 'Location permission is required to use the compass accurately.');
      return;
    }

    _headingSubscription = FlutterCompass.events?.listen(
      _handleCompassEvent,
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _isLive = false;
          _status = 'Compass sensor error: ${error.toString()}';
        });
      },
    );
    if (_headingSubscription == null) {
      setState(() {
        _status = 'Compass sensor unavailable on this device';
      });
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _headingSubscription?.cancel();
    super.dispose();
  }

  void _handleCompassEvent(CompassEvent event) {
    if (!mounted) return;
    final heading = event.heading;
    setState(() {
      _heading = heading ?? 0;
      _accuracy = event.accuracy ?? 0;
      _isLive = heading != null && !heading.isNaN && !heading.isInfinite;
      _status = !_isLive
          ? 'Calibrating...'
          : (_accuracy > 0.8 ? 'Stable' : 'Stabilizing');
    });
  }

  Widget _buildPremiumCompassRose() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ringController, _pulseController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kNeonBlue.withValues(alpha: 0.15 + 0.1 * _pulseController.value),
                    blurRadius: 40 + 20 * _pulseController.value,
                    spreadRadius: 10 + 5 * _pulseController.value,
                  ),
                ],
              ),
            ),
            // Background base
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF070B19),
                border: Border.all(color: kNeonBlue.withValues(alpha: 0.3), width: 1),
              ),
            ),
            // Ticks
            ...List.generate(360, (index) {
              final isMajor = index % 10 == 0;
              final isMinor = index % 5 == 0 && !isMajor;
              if (!isMajor && !isMinor) return const SizedBox.shrink();
              
              final angle = index * math.pi / 180;
              return Transform.rotate(
                angle: angle - (_heading * math.pi / 180),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: isMajor ? 2 : 1,
                    height: isMajor ? 12 : 8,
                    decoration: BoxDecoration(
                      color: isMajor ? kNeonBlue : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              );
            }),
            // Labels
            ...List.generate(8, (index) {
              final angle = (index * 45) * math.pi / 180;
              final labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
              final isCardinal = index % 2 == 0;
              return Transform.rotate(
                angle: angle - (_heading * math.pi / 180),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: isCardinal ? kNeonBlue : Colors.white.withValues(alpha: 0.6),
                        fontSize: isCardinal ? 24 : 14,
                        fontWeight: FontWeight.bold,
                        shadows: isCardinal ? const [BoxShadow(color: kNeonBlue, blurRadius: 8)] : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Needle
            Transform.rotate(
              angle: _heading * math.pi / 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF2A5F), Color(0xFF00E5FF)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF2A5F).withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, -10)),
                        BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, 10)),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B19),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 10)],
                    ),
                  ),
                ],
              ),
            ),
            // Center Heading
            Positioned(
              bottom: 40,
              child: Text(
                '${_heading.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: kSurfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ]
        ),
        child: Column(
          children: [
            Icon(icon, color: kNeonBlue, size: 24),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = cardinalDirection(_heading);
    final isTrueNorth = _heading >= 355 || _heading <= 5;

    return Scaffold(
      backgroundColor: const Color(0xFF040613),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Compass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF0D1830), Color(0xFF040613)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: isTrueNorth ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kNeonGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kNeonGreen.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore, color: kNeonGreen, size: 16),
                        SizedBox(width: 8),
                        Text('TRUE NORTH', style: TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _buildPremiumCompassRose(),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Row(
                    children: [
                      _buildInfoCard('HEADING', '${_heading.toStringAsFixed(1)}°', Icons.navigation),
                      const SizedBox(width: 12),
                      _buildInfoCard('DIRECTION', direction, Icons.explore),
                      const SizedBox(width: 12),
                      _buildInfoCard('ACCURACY', '${(_accuracy * 100).toStringAsFixed(0)}%', Icons.gps_fixed),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
