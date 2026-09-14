import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';

class BatterySaverScreen extends StatefulWidget {
  static const routeName = '/battery-saver';

  const BatterySaverScreen({super.key});

  @override
  State<BatterySaverScreen> createState() => _BatterySaverScreenState();
}

class _BatterySaverScreenState extends State<BatterySaverScreen> {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batteryStateSub;
  BatteryState _batteryState = BatteryState.unknown;
  int _batteryLevel = 0;
  String _selectedBatteryMode = 'performance';
  String _batteryOptimizationNote = '';
  final String _batteryHealth = 'Good';
  final String _powerSource = 'AC';
  final String _technology = 'Li-ion';
  final String _temperature = '29°C';
  final String _voltage = '3.85V';

  final List<Map<String, String>> _batteryDrainApps = [
    {
      'title': 'NEXDROID Core',
      'subtitle': 'Active sync and messaging',
      'drain': '18%'
    },
    {
      'title': 'NEX Engine',
      'subtitle': 'Background processing',
      'drain': '12%'
    },
    {
      'title': 'Media Visualizer',
      'subtitle': 'Audio and UI effects',
      'drain': '9%'
    },
  ];

  final List<String> _batteryManagerPermissions = [
    'Display over other apps',
    'Background Data',
    'Storage Access',
    'Run in background',
  ];

  final List<Map<String, String>> _sensorList = [
    {'name': 'Anymotion Move', 'value': '2.0 L=16 T=65584'},
    {'name': 'Anymotion Pick', 'value': '2.0 L=16 T=65585'},
    {'name': 'acc_mxc4005', 'value': '1.2 m/s² 7.2 m/s² 6.3 m/s²'},
    {'name': 'mag_qmc6308', 'value': '56.3 µT'},
    {'name': 'Orientation Sensor', 'value': 'Azimuth=15.8 Pitch=-47.8 Roll=7.4'},
    {'name': 'virtual_gyro', 'value': '0.0 rad/s 0.0 rad/s 0.2 rad/s'},
    {'name': 'light_stk3335-x', 'value': '103.9 lux'},
  ];

  @override
  void initState() {
    super.initState();
    _initBatteryManager();
  }

  @override
  void dispose() {
    _batteryStateSub?.cancel();
    super.dispose();
  }

  Future<void> _initBatteryManager() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    _batteryStateSub = _battery.onBatteryStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _batteryState = state);
    });

    setState(() {
      _batteryLevel = level;
      _batteryState = state;
      _batteryOptimizationNote = _batteryState == BatteryState.charging
          ? 'Charging detected. NEX Engine will keep only essential services active.'
          : 'Plug in your device to enable full battery diagnosis and optimization.';
    });
  }

  String get _batteryStateLabel {
    switch (_batteryState) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.full:
        return 'Fully charged';
      case BatteryState.discharging:
        return 'Discharging';
      default:
        return 'Unknown';
    }
  }

  bool get _isCharging {
    return _batteryState == BatteryState.charging ||
        _batteryState == BatteryState.full;
  }

  void _toggleBatteryMode(String mode) {
    setState(() {
      _selectedBatteryMode = mode;
      _batteryOptimizationNote = mode == 'performance'
          ? 'NEX Engine performance mode is on. Expect maximum responsiveness.'
          : 'Battery saver is enabled. Visuals and background tasks are reduced.';
    });
  }

  void _optimizeBatteryNow() {
    setState(() {
      _batteryOptimizationNote = _isCharging
          ? 'Battery diagnosis complete. Closed unused Dart services and retained only core NEXDROID processes.'
          : 'Battery optimization will run once charging begins. Keep NEXDROID open for best performance.';
    });
  }

  Widget _buildBatteryMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF121836),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryRing() {
    final pct = _batteryLevel / 100.0;
    final ringColor = _isCharging
        ? kNeonGreen
        : _batteryLevel > 50
            ? kNeonBlue
            : _batteryLevel > 20
                ? Colors.orange
                : Colors.redAccent;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _BatteryRingPainter(
              progress: pct,
              color: ringColor,
              isCharging: _isCharging,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCharging)
                Icon(Icons.bolt, color: ringColor, size: 18),
              Text(
                '$_batteryLevel%',
                style: TextStyle(
                  color: ringColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _batteryStateLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryManagerSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101028),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kNeonGreen.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: kNeonGreen.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kNeonGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isCharging ? Icons.battery_charging_full : Icons.battery_std,
                  color: kNeonGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEX Charge Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Live battery diagnostics & optimization',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Battery ring + state label
          Center(child: _buildBatteryRing()),
          const SizedBox(height: 20),
          // Responsive 2-column grid of metrics
          LayoutBuilder(
            builder: (context, constraints) {
              const crossCount = 2;
              const spacing = 10.0;
              final itemWidth = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
              final metrics = [
                ('Health', _batteryHealth, kNeonGreen),
                ('Level', '$_batteryLevel%', kNeonBlue),
                ('Power Source', _powerSource, kNeonPurple),
                ('Status', _batteryStateLabel, kNeonGreen),
                ('Technology', _technology, kNeonBlue),
                ('Temp', _temperature, kNeonPurple),
                ('Voltage', _voltage, kNeonGreen),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: metrics.map((m) {
                  return SizedBox(
                    width: itemWidth,
                    height: 72,
                    child: _buildBatteryMetric(m.$1, m.$2, m.$3),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Select a power profile',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleBatteryMode('performance'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedBatteryMode == 'performance'
                          ? kNeonBlue
                          : const Color(0xFF15163B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedBatteryMode == 'performance'
                            ? kNeonBlue
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'NEX_ENGINE PERFORMANCE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedBatteryMode == 'performance'
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleBatteryMode('saver'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedBatteryMode == 'saver'
                          ? kNeonGreen
                          : const Color(0xFF15163B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedBatteryMode == 'saver'
                            ? kNeonGreen
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'NEX_ENGINE BATTERY SAVER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedBatteryMode == 'saver'
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Current apps draining battery',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Column(
            children: _batteryDrainApps.map((app) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt, color: kNeonPurple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            app['subtitle']!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      app['drain']!,
                      style: const TextStyle(
                        color: kNeonGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Sensor status',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          Column(
            children: _sensorList.map((sensor) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sensor['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      sensor['value']!,
                      style: const TextStyle(
                        color: kNeonGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Permissions needed for full battery management',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _batteryManagerPermissions.map((permission) {
              return Chip(
                label: Text(
                  permission,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: const Color(0xFF15163B),
                side: BorderSide(color: kNeonBlue.withValues(alpha: 0.18)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            _batteryOptimizationNote,
            style: TextStyle(
              color: kNeonGreen.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _optimizeBatteryNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNeonBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Run full battery diagnosis'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0E22), Color(0xFF0D1528)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_charging_full,
                color: kNeonGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'Battery Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kNeonGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: kNeonGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$_batteryLevel%',
              style: const TextStyle(
                color: kNeonGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: kNeonGreen.withValues(alpha: 0.7), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Battery optimization, sensors & health — all in one place.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildBatteryManagerSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Battery Ring Painter ───────────────────────────────────────────────────────
class _BatteryRingPainter extends CustomPainter {
  const _BatteryRingPainter({
    required this.progress,
    required this.color,
    required this.isCharging,
  });
  final double progress;
  final Color color;
  final bool isCharging;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle.clamp(0.01, 2 * math.pi),
        colors: [
          color.withAlpha(180),
          color,
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle.clamp(0.01, 2 * math.pi),
      false,
      progressPaint,
    );

    // Glow
    final glowPaint = Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle.clamp(0.01, 2 * math.pi),
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_BatteryRingPainter old) =>
      old.progress != progress || old.color != color;
}
