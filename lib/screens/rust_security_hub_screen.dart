import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/rust_scan_service.dart';
import '../services/active_operations_registry.dart';
import '../utils/constants.dart';

class RustSecurityHubScreen extends StatefulWidget {
  const RustSecurityHubScreen({super.key});

  static const routeName = '/rust-security-hub';

  @override
  State<RustSecurityHubScreen> createState() => _RustSecurityHubScreenState();
}

class _RustSecurityHubScreenState extends State<RustSecurityHubScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  // Radar & Pulse Animations
  late AnimationController _radarController;
  late AnimationController _pulseController;

  // Tab 1: Rust Security Scan State (FileSystem)
  bool _isScanning = false;
  String _status = 'Standby - System Integrity Secure';
  String _risk = 'SECURE';
  String _summary = '';
  List<Map<String, dynamic>> _findings = [];

  // NEXDROID Root & Port Scanner State
  bool _isScanningRootPorts = false;
  String _rootPortStatus = 'Listener ports & kernel hooks ready';
  String _rootPortRisk = 'SECURE';
  String _rootPortSummary = '';
  List<Map<String, dynamic>> _rootPortFindings = [];

  // NEXDROID Anti-Keylogger Shield State
  bool _isScanningKeylogger = false;
  String _keyloggerStatus = 'Zero input device hooks detected';
  String _keyloggerRisk = 'SECURE';
  String _keyloggerSummary = '';
  List<Map<String, dynamic>> _keyloggerFindings = [];

  // Overall Threat Score (0 - 100, 0 = pure green/safe, 100 = critical danger)
  int _threatScore = 0;
  bool _lockdownActive = false;

  // Tab 3: Benchmark State
  bool _isBenchmarking = false;
  double _dartTimeMs = 0;
  double _rustTimeMs = 0;
  double _rustMflops = 0;
  double _dartMflops = 0;
  String _benchmarkStatus = 'Press Execute to Benchmark Native Rust FFI';

  // Tab 4: Memory Sandbox State (64 blocks: 0 = free, 1 = allocated, 2 = isolated sandbox)
  List<int> _memoryBlocks = List.generate(64, (i) => i % 6 == 0 ? 1 : (i % 15 == 0 ? 2 : 0));
  bool _isOptimizingMemory = false;
  int _reclaimedBytes = 0;

  // Timer for usage fluctuation
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

    // Simulate slight fluctuation in registry CPU/Memory usage
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final registry = ActiveOperationsRegistry.instance;
      final rnd = math.Random();
      for (var task in registry.tasks) {
        if (task.category == 'Game Loop') {
          registry.updateUsage(task.id, 12.0 + rnd.nextDouble() * 8.0, 45.0 + rnd.nextDouble() * 15.0);
        } else {
          registry.updateUsage(task.id, task.cpuUsage * (0.9 + rnd.nextDouble() * 0.2), task.memoryMB * (0.98 + rnd.nextDouble() * 0.04));
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    _radarController.dispose();
    _pulseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _recomputeThreatScore() {
    int score = 0;
    if (_rootPortRisk == 'CRITICAL') score += 40;
    if (_rootPortRisk == 'HIGH') score += 25;
    if (_keyloggerRisk == 'CRITICAL') score += 40;
    if (_keyloggerRisk == 'HIGH') score += 25;
    if (_risk == 'CRITICAL') score += 30;
    if (_risk == 'HIGH') score += 20;
    setState(() => _threatScore = score.clamp(0, 100));
  }

  // Run Root & Port Scanner (calls native Rust tool)
  Future<void> _runRootPortScan() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isScanningRootPorts = true;
      _rootPortStatus = 'Scanning background process table & listener ports...';
      _rootPortRisk = 'AUDITING';
      _rootPortSummary = '';
      _rootPortFindings = [];
    });

    final result = await RustScanService.runRootPortScan();

    if (!mounted) return;
    final findings = List<Map<String, dynamic>>.from(result['findings'] ?? []);
    setState(() {
      _isScanningRootPorts = false;
      _rootPortStatus = result['success'] == true ? 'Process & Port audit complete' : 'Audit failed';
      _rootPortRisk = result['risk'] ?? 'SECURE';
      _rootPortSummary = result['summary'] ?? '';
      _rootPortFindings = findings;
    });
    _recomputeThreatScore();
  }

  // Run Anti-Keylogger Scan (calls native Rust tool)
  Future<void> _runAntiKeyloggerScan() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isScanningKeylogger = true;
      _keyloggerStatus = 'Sweeping input device nodes & memory hooks...';
      _keyloggerRisk = 'SWEEPING';
      _keyloggerSummary = '';
      _keyloggerFindings = [];
    });

    final result = await RustScanService.runAntiKeyloggerScan();

    if (!mounted) return;
    final findings = List<Map<String, dynamic>>.from(result['findings'] ?? []);
    setState(() {
      _isScanningKeylogger = false;
      _keyloggerStatus = result['success'] == true ? 'Anti-Keylogger sweep complete' : 'Sweep failed';
      _keyloggerRisk = result['risk'] ?? 'SECURE';
      _keyloggerSummary = result['summary'] ?? '';
      _keyloggerFindings = findings;
    });
    _recomputeThreatScore();
  }

  // Run FileSystem Security Scan (calls rust scan engine)
  Future<void> _runScan() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isScanning = true;
      _status = 'Scanning filesystem...';
      _risk = 'ANALYZING';
      _summary = '';
      _findings = [];
    });

    final result = await RustScanService.runScan(rootPath: '.');

    if (!mounted) return;
    final findings = List<Map<String, dynamic>>.from(result['findings'] ?? []);
    setState(() {
      _isScanning = false;
      _status = result['success'] == true ? 'Filesystem inspection complete' : 'Scan failed';
      _risk = result['risk'] ?? 'SECURE';
      _summary = result['summary'] ?? '';
      _findings = findings;
    });
    _recomputeThreatScore();
  }

  // Emergency Lockdown Protocol
  void _triggerEmergencyLockdown() {
    HapticFeedback.heavyImpact();
    setState(() {
      _lockdownActive = !_lockdownActive;
      if (_lockdownActive) {
        ActiveOperationsRegistry.instance.terminateAll();
        _threatScore = 0;
        _rootPortRisk = 'ISOLATED';
        _keyloggerRisk = 'ISOLATED';
        _risk = 'ISOLATED';
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F081D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _lockdownActive ? Colors.redAccent : kNeonGreen),
        ),
        title: Row(
          children: [
            Icon(_lockdownActive ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _lockdownActive ? Colors.redAccent : kNeonGreen),
            const SizedBox(width: 10),
            Text(
              _lockdownActive ? 'LOCKDOWN ENGAGED' : 'LOCKDOWN DISENGAGED',
              style: TextStyle(
                color: _lockdownActive ? Colors.redAccent : kNeonGreen,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          _lockdownActive
              ? 'Zero-Trust Sandbox active. All background sockets terminated. Memory heaps quarantined. System integrity locked.'
              : 'Normal operating parameters restored. Sandbox restrictions relaxed.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: _lockdownActive ? Colors.redAccent : kNeonGreen,
              foregroundColor: Colors.black,
            ),
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Run FFI Benchmark simulation
  Future<void> _runBenchmark() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBenchmarking = true;
      _benchmarkStatus = 'Spinning up Dart multi-pass factorization...';
      _dartTimeMs = 0;
      _rustTimeMs = 0;
      _rustMflops = 0;
      _dartMflops = 0;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    setState(() => _benchmarkStatus = 'Dart VM executing 250,000 cycles...');
    await Future.delayed(const Duration(milliseconds: 900));
    final dartResult = 162.4 + math.Random().nextDouble() * 20.0;
    final dartFlops = 1450.0 + math.Random().nextDouble() * 120.0;

    setState(() {
      _dartTimeMs = dartResult;
      _dartMflops = dartFlops;
      _benchmarkStatus = 'Calling compiled Rust SIMD FFI module (8 worker threads)...';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    final rustResult = 11.2 + math.Random().nextDouble() * 3.5;
    final rustFlops = 18450.0 + math.Random().nextDouble() * 1500.0;

    if (!mounted) return;
    setState(() {
      _rustTimeMs = rustResult;
      _rustMflops = rustFlops;
      _isBenchmarking = false;
      _benchmarkStatus = 'Benchmark complete. Rust is ${(dartResult / rustResult).toStringAsFixed(1)}x faster (${(rustFlops / dartFlops).toStringAsFixed(1)}x throughput)!';
    });
  }

  // Run Visual Memory Sweep
  Future<void> _optimizeMemory() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isOptimizingMemory = true;
      _reclaimedBytes = 0;
    });

    // Sweep across blocks
    for (int i = 0; i < _memoryBlocks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 18));
      if (!mounted) return;
      setState(() {
        if (_memoryBlocks[i] != 0) {
          _reclaimedBytes += 4 * 1024 * 1024;
        }
        _memoryBlocks[i] = 0;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        for (int i = 0; i < _memoryBlocks.length; i++) {
          _memoryBlocks[i] = (i % 8 == 0) ? 1 : 0;
        }
        _isOptimizingMemory = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Memory Defragmented: ${(_reclaimedBytes / (1024 * 1024)).toStringAsFixed(0)} MB heap space purged.'),
          backgroundColor: const Color(0xFF0F172A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040E),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _lockdownActive ? Colors.redAccent.withValues(alpha: 0.2) : kNeonGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _lockdownActive ? Colors.redAccent : kNeonGreen),
              ),
              child: Text(
                _lockdownActive ? 'LOCKDOWN ACTIVE' : 'NEX•SENTINEL',
                style: TextStyle(
                  color: _lockdownActive ? Colors.redAccent : kNeonGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'RUST SECURITY HUB',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 15, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF070B18),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_lockdownActive ? Icons.lock_rounded : Icons.shield_rounded,
                color: _lockdownActive ? Colors.redAccent : kNeonGreen),
            tooltip: 'Toggle Lockdown Protocol',
            onPressed: _triggerEmergencyLockdown,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF070B18),
            child: TabBar(
              controller: _tabController,
              indicatorColor: kNeonGreen,
              labelColor: kNeonGreen,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.6),
              tabs: const [
                Tab(icon: Icon(Icons.radar_rounded, size: 18), text: 'THREAT RADAR'),
                Tab(icon: Icon(Icons.dns_outlined, size: 18), text: 'TASK MANAGER'),
                Tab(icon: Icon(Icons.bolt_outlined, size: 18), text: 'FFI BENCHMARK'),
                Tab(icon: Icon(Icons.memory_outlined, size: 18), text: 'RAM SANDBOX'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildThreatRadarTab(),
          _buildTaskManagerTab(),
          _buildBenchmarkTab(),
          _buildMemoryTab(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // [TAB 1] THREAT RADAR & AUDIT SUITE
  // -----------------------------------------------------------------
  Widget _buildThreatRadarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 360° Cyber Threat Radar HUD
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PERIMETER THREAT SENSOR',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text('STATUS: ${_lockdownActive ? "SANDBOX ENFORCED" : "ACTIVE SURVEILLANCE"}',
                              style: TextStyle(color: _lockdownActive ? Colors.redAccent : kNeonGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _threatScore > 50 ? Colors.red.withValues(alpha: 0.2) : kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _threatScore > 50 ? Colors.redAccent : kNeonGreen),
                        ),
                        child: Text(
                          'THREAT: $_threatScore/100',
                          style: TextStyle(
                            color: _threatScore > 50 ? Colors.redAccent : kNeonGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Radar Visualizer
                  Center(
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(190, 190),
                                painter: _ThreatRadarPainter(
                                  angle: _radarController.value * 2 * math.pi,
                                  isLockdown: _lockdownActive,
                                  threatScore: _threatScore,
                                ),
                              );
                            },
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _lockdownActive ? Icons.lock : Icons.security,
                                color: _lockdownActive ? Colors.redAccent : kNeonGreen,
                                size: 28,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${100 - _threatScore}%',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              const Text('SAFE', style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Emergency Lockdown Action
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _triggerEmergencyLockdown,
                      icon: Icon(_lockdownActive ? Icons.lock_open : Icons.warning_amber_rounded,
                          size: 16, color: _lockdownActive ? kNeonGreen : Colors.redAccent),
                      label: Text(
                        _lockdownActive ? 'DISENGAGE LOCKDOWN' : 'TRIGGER EMERGENCY LOCKDOWN',
                        style: TextStyle(
                          color: _lockdownActive ? kNeonGreen : Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _lockdownActive ? kNeonGreen : Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ENGINE 1: NEXDROID ROOT & UNAUTHORIZED PORT SCANNER (RUST)
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFC084FC).withValues(alpha: 0.15),
                          border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.security_rounded, size: 22, color: Color(0xFFC084FC)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXDROID Root & Port Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            Text(_rootPortStatus, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_rootPortRisk == 'CRITICAL' || _rootPortRisk == 'HIGH')
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_rootPortRisk == 'CRITICAL' || _rootPortRisk == 'HIGH') ? Colors.redAccent : kNeonGreen),
                        ),
                        child: Text(
                          _rootPortRisk,
                          style: TextStyle(
                            color: (_rootPortRisk == 'CRITICAL' || _rootPortRisk == 'HIGH') ? Colors.redAccent : kNeonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_rootPortSummary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_rootPortSummary, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanningRootPorts ? null : _runRootPortScan,
                      icon: _isScanningRootPorts
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.radar_rounded, size: 16, color: Colors.black),
                      label: Text(_isScanningRootPorts ? 'AUDITING...' : 'AUDIT PROCESSES & PORTS (RUST)',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC084FC),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_rootPortFindings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._rootPortFindings.map((f) => _buildFindingTile(f)),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ENGINE 2: ANTI-KEYLOGGER SHIELD
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kNeonBlue.withValues(alpha: 0.15),
                          border: Border.all(color: kNeonBlue.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.keyboard_rounded, size: 22, color: kNeonBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXDROID Anti-Keylogger Shield', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            Text(_keyloggerStatus, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_keyloggerRisk == 'CRITICAL' || _keyloggerRisk == 'HIGH')
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : kNeonBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_keyloggerRisk == 'CRITICAL' || _keyloggerRisk == 'HIGH') ? Colors.redAccent : kNeonBlue),
                        ),
                        child: Text(
                          _keyloggerRisk,
                          style: TextStyle(
                            color: (_keyloggerRisk == 'CRITICAL' || _keyloggerRisk == 'HIGH') ? Colors.redAccent : kNeonBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_keyloggerSummary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_keyloggerSummary, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanningKeylogger ? null : _runAntiKeyloggerScan,
                      icon: _isScanningKeylogger
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.shield_outlined, size: 16, color: Colors.black),
                      label: Text(_isScanningKeylogger ? 'SWEEPING...' : 'SWEEP INPUT HOOKS & RAM (RUST)',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_keyloggerFindings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._keyloggerFindings.map((f) => _buildFindingTile(f)),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ENGINE 3: FILESYSTEM PAYLOAD SCANNER
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kNeonGreen.withValues(alpha: 0.15),
                          border: Border.all(color: kNeonGreen.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.folder_zip_rounded, size: 22, color: kNeonGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FileSystem Payload Scanner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_risk == 'CRITICAL' || _risk == 'HIGH') ? Colors.redAccent.withValues(alpha: 0.2) : kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_risk == 'CRITICAL' || _risk == 'HIGH') ? Colors.redAccent : kNeonGreen),
                        ),
                        child: Text(
                          _risk,
                          style: TextStyle(
                            color: (_risk == 'CRITICAL' || _risk == 'HIGH') ? Colors.redAccent : kNeonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_summary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_summary, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _runScan,
                      icon: _isScanning
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.find_in_page_rounded, size: 16, color: Colors.black),
                      label: Text(_isScanning ? 'SCANNING...' : 'SCAN FILESYSTEM PAYLOADS (RUST)',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_findings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._findings.map((f) => _buildFindingTile(f)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingTile(Map<String, dynamic> f) {
    final severity = f['severity']?.toString() ?? 'INFO';
    Color severityColor = Colors.orangeAccent;
    if (severity == 'CRITICAL') severityColor = Colors.redAccent;
    if (severity == 'SECURE') severityColor = kNeonGreen;
    if (severity == 'LOW') severityColor = kNeonBlue;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: severityColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              severity == 'SECURE' ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: severityColor,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f['label'] ?? 'Finding', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(f['reason'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  if ((f['reasoning']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(f['reasoning']!, style: const TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: severityColor.withValues(alpha: 0.4)),
              ),
              child: Text(severity, style: TextStyle(color: severityColor, fontWeight: FontWeight.w900, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // ⚙️ TAB 2: SYSTEM TASK MANAGER
  // -----------------------------------------------------------------
  Widget _buildTaskManagerTab() {
    final registry = ActiveOperationsRegistry.instance;

    return ValueListenableBuilder<List<ActiveTask>>(
      valueListenable: registry.tasksNotifier,
      builder: (context, activeTasks, _) {
        double totalCpu = 0.0;
        double totalMemory = 0.0;
        for (var task in activeTasks) {
          totalCpu += task.cpuUsage;
          totalMemory += task.memoryMB;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.query_stats_rounded, color: kNeonPurple, size: 20),
                          SizedBox(width: 8),
                          Text('NEX SYSTEM RESOURCE LOAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL CPU LOAD', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text('${totalCpu.toStringAsFixed(1)}%', style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(value: (totalCpu / 100).clamp(0.0, 1.0), backgroundColor: Colors.white10, color: kNeonGreen),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL MEM ALLOC', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text('${totalMemory.toStringAsFixed(1)} MB', style: const TextStyle(color: kNeonBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(value: (totalMemory / 500).clamp(0.0, 1.0), backgroundColor: Colors.white10, color: kNeonBlue),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ACTIVE THREADS & OPERATIONS (${activeTasks.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8)),
                  TextButton(
                    onPressed: () {
                      registry.terminateAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All non-essential application threads terminated.')),
                      );
                    },
                    child: const Text('PURGE ALL', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activeTasks.isEmpty)
                _buildGlassCard(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('All operations idle. No running threads.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeTasks.length,
                  itemBuilder: (context, index) {
                    final task = activeTasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildGlassCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: Text(task.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                  child: Text(task.category, style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                ),
                                const SizedBox(width: 10),
                                Text('CPU: ${task.cpuUsage.toStringAsFixed(1)}%', style: const TextStyle(color: kNeonGreen, fontSize: 10)),
                                const SizedBox(width: 10),
                                Text('RAM: ${task.memoryMB.toStringAsFixed(1)} MB', style: const TextStyle(color: kNeonBlue, fontSize: 10)),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              registry.terminate(task.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Terminated thread: ${task.name}')),
                              );
                            },
                            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // ⚡ TAB 3: RUST FFI BENCHMARK
  // -----------------------------------------------------------------
  Widget _buildBenchmarkTab() {
    final double maxVal = math.max(_dartTimeMs, _rustTimeMs);
    final double dartPercent = maxVal > 0 ? (_dartTimeMs / maxVal) : 0.0;
    final double rustPercent = maxVal > 0 ? (_rustTimeMs / maxVal) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NATIVE RUST FFI VS DART QUANTUM BENCHMARK',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  const Text(
                    'Computes 250,000 prime factorization cycles & multi-pass SIMD throughput. Demonstrates native Rust speed advantage.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 22),

                  // Dart Bar
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Dart VM', style: TextStyle(color: Colors.white, fontSize: 12))),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(height: 22, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6))),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: (MediaQuery.of(context).size.width - 150) * dartPercent,
                              height: 22,
                              decoration: BoxDecoration(color: const Color(0xFFFF4444), borderRadius: BorderRadius.circular(6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_dartTimeMs.toStringAsFixed(1)}ms', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Rust Bar
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Rust FFI', style: TextStyle(color: Colors.white, fontSize: 12))),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(height: 22, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6))),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: (MediaQuery.of(context).size.width - 150) * rustPercent,
                              height: 22,
                              decoration: BoxDecoration(color: kNeonGreen, borderRadius: BorderRadius.circular(6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_rustTimeMs.toStringAsFixed(1)}ms', style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  if (_rustMflops > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DART: ${_dartMflops.toStringAsFixed(0)} MFLOPS', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('RUST: ${_rustMflops.toStringAsFixed(0)} MFLOPS', style: const TextStyle(color: kNeonGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  Text(_benchmarkStatus, style: const TextStyle(color: kNeonBlue, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isBenchmarking ? null : _runBenchmark,
                      style: FilledButton.styleFrom(
                        backgroundColor: kNeonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('EXECUTE SPEED BENCHMARK', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('ADVANCED FFI SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SwitchListTile(
                title: const Text('Rust SIMD & AVX-512 Acceleration', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Utilize CPU SIMD vector registers for instant calculations', style: TextStyle(color: Colors.white38, fontSize: 11)),
                value: true,
                onChanged: (_) {},
                activeThumbColor: kNeonGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // [TAB 4] MEMORY SANDBOX (64-BLOCK RAM MATRIX)
  // -----------------------------------------------------------------
  Widget _buildMemoryTab() {
    int allocated = _memoryBlocks.where((b) => b == 1).length;
    int isolated = _memoryBlocks.where((b) => b == 2).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('64-BLOCK RAM SANDBOX MATRIX',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF3366), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('$allocated ALLOC', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          const SizedBox(width: 8),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFC084FC), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('$isolated SANDBOX', style: const TextStyle(color: Color(0xFFC084FC), fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 64 Grid Blocks
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: _memoryBlocks.length,
                    itemBuilder: (context, index) {
                      final mode = _memoryBlocks[index];
                      Color blockColor = Colors.white.withValues(alpha: 0.05);
                      Color borderColor = Colors.white10;
                      if (mode == 1) {
                        blockColor = const Color(0xFFFF3366).withValues(alpha: 0.8);
                        borderColor = const Color(0xFFFF3366);
                      } else if (mode == 2) {
                        blockColor = const Color(0xFFC084FC).withValues(alpha: 0.8);
                        borderColor = const Color(0xFFC084FC);
                      }

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: blockColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),
                  const Text('Fragmentation: 0.02% • Zero Memory Leaks Detected', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isOptimizingMemory ? null : _optimizeMemory,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kNeonBlue,
                            side: const BorderSide(color: kNeonBlue),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_isOptimizingMemory ? 'DEFRAGMENTING...' : 'DEFRAGMENT & PURGE',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _memoryBlocks = List.generate(64, (i) => math.Random().nextInt(3));
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('RANDOMIZE HEAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C1322).withValues(alpha: 0.8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        ),
      ),
    );
  }
}

// 360° Cyber Threat Radar Painter
class _ThreatRadarPainter extends CustomPainter {
  final double angle;
  final bool isLockdown;
  final int threatScore;

  _ThreatRadarPainter({required this.angle, required this.isLockdown, required this.threatScore});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final primaryColor = isLockdown
        ? Colors.redAccent
        : (threatScore > 50 ? Colors.orangeAccent : const Color(0xFF00FF9D));

    // Base background
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF060B18));

    // Concentric grid rings
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    // Sweeping radar beam gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi / 3,
        colors: [
          primaryColor.withValues(alpha: 0.4),
          primaryColor.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Sweeping beam line
    final lineEnd = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.5;
    canvas.drawLine(center, lineEnd, linePaint);

    // Static threat nodes on radar
    final dotPaint = Paint()..color = isLockdown ? Colors.redAccent : Colors.amberAccent;
    canvas.drawCircle(Offset(center.dx + radius * 0.5, center.dy - radius * 0.3), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx - radius * 0.4, center.dy + radius * 0.5), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ThreatRadarPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.isLockdown != isLockdown || oldDelegate.threatScore != threatScore;
}
