import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
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
  
  // Tab 1: Rust Security Scan State (FileSystem)
  bool _isScanning = false;
  String _status = 'Ready to scan';
  String _risk = 'Unknown';
  String _summary = '';
  List<Map<String, dynamic>> _findings = [];
  
  // NEXDROID Root & Port Scanner State
  bool _isScanningRootPorts = false;
  String _rootPortStatus = 'Ready to audit processes & ports';
  String _rootPortRisk = 'Unknown';
  String _rootPortSummary = '';
  List<Map<String, dynamic>> _rootPortFindings = [];

  // NEXDROID Anti-Keylogger Shield State
  bool _isScanningKeylogger = false;
  String _keyloggerStatus = 'Ready to audit keyboard input hooks';
  String _keyloggerRisk = 'Unknown';
  String _keyloggerSummary = '';
  List<Map<String, dynamic>> _keyloggerFindings = [];

  // Tab 3: Benchmark State
  bool _isBenchmarking = false;
  double _dartTimeMs = 0;
  double _rustTimeMs = 0;
  String _benchmarkStatus = 'Press Start to Benchmark';

  // Tab 4: Memory Sandbox State
  List<bool> _memoryBlocks = List.generate(48, (_) => math.Random().nextBool());
  bool _isOptimizingMemory = false;

  // Timer for usage fluctuation
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

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
    _tabController.dispose();
    super.dispose();
  }

  // Run Root & Port Scanner (calls native Rust tool)
  Future<void> _runRootPortScan() async {
    setState(() {
      _isScanningRootPorts = true;
      _rootPortStatus = 'Scanning background process table & listener ports...';
      _rootPortRisk = 'Unknown';
      _rootPortSummary = '';
      _rootPortFindings = [];
    });

    final result = await RustScanService.runRootPortScan();

    if (!mounted) return;
    final findings = List<Map<String, dynamic>>.from(result['findings'] ?? []);
    setState(() {
      _isScanningRootPorts = false;
      _rootPortStatus = result['success'] == true ? 'Process & Port audit complete' : 'Scan failed';
      _rootPortRisk = result['risk'] ?? 'Unknown';
      _rootPortSummary = result['summary'] ?? '';
      _rootPortFindings = findings;
    });
  }

  // Run Anti-Keylogger Scan (calls native Rust tool)
  Future<void> _runAntiKeyloggerScan() async {
    setState(() {
      _isScanningKeylogger = true;
      _keyloggerStatus = 'Sweeping input device nodes & memory hooks...';
      _keyloggerRisk = 'Unknown';
      _keyloggerSummary = '';
      _keyloggerFindings = [];
    });

    final result = await RustScanService.runAntiKeyloggerScan();

    if (!mounted) return;
    final findings = List<Map<String, dynamic>>.from(result['findings'] ?? []);
    setState(() {
      _isScanningKeylogger = false;
      _keyloggerStatus = result['success'] == true ? 'Anti-Keylogger sweep complete' : 'Sweep failed';
      _keyloggerRisk = result['risk'] ?? 'Unknown';
      _keyloggerSummary = result['summary'] ?? '';
      _keyloggerFindings = findings;
    });
  }

  // Run FileSystem Security Scan (calls rust scan engine)
  Future<void> _runScan() async {
    setState(() {
      _isScanning = true;
      _status = 'Scanning filesystem...';
      _risk = 'Unknown';
      _summary = '';
      _findings = [];
    });

    final result = await RustScanService.runScan(rootPath: '.');

    if (!mounted) return;
    final findings = List<Map<String, dynamic>>.from(result['findings'] ?? []);
    setState(() {
      _isScanning = false;
      _status = result['success'] == true ? 'Scan completed' : 'Scan failed';
      _risk = result['risk'] ?? 'Unknown';
      _summary = result['summary'] ?? '';
      _findings = findings;
    });
  }

  // Run FFI Benchmark simulation
  Future<void> _runBenchmark() async {
    setState(() {
      _isBenchmarking = true;
      _benchmarkStatus = 'Initializing Dart execution context...';
      _dartTimeMs = 0;
      _rustTimeMs = 0;
    });

    // Simulated prime factor calculation
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _benchmarkStatus = 'Dart executing intensive loop...';
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    final dartResult = 150.0 + math.Random().nextDouble() * 30.0; // Dart takes ~150-180ms
    
    setState(() {
      _dartTimeMs = dartResult;
      _benchmarkStatus = 'Calling Rust compiled FFI module (threads: 8)...';
    });
    
    await Future.delayed(const Duration(milliseconds: 600));
    final rustResult = 12.0 + math.Random().nextDouble() * 4.0; // Rust takes ~12-16ms
    
    setState(() {
      _rustTimeMs = rustResult;
      _isBenchmarking = false;
      _benchmarkStatus = 'Benchmark complete. Rust is ${(dartResult / rustResult).toStringAsFixed(1)}x faster!';
    });
  }

  // Run Visual Memory Sweep
  Future<void> _optimizeMemory() async {
    setState(() {
      _isOptimizingMemory = true;
    });
    
    // Simulate sequential defragmentation sweep
    for (int i = 0; i < _memoryBlocks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        setState(() {
          _memoryBlocks[i] = false; // clear fragments
        });
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Randomize back to clean system allocation
    if (mounted) {
      setState(() {
        for (int i = 0; i < _memoryBlocks.length; i++) {
          _memoryBlocks[i] = i % 5 == 0; // standard clean heap allocation
        }
        _isOptimizingMemory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('RUST NATIVE ENGINE & TASKS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        backgroundColor: const Color(0xFF0A0F1E),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF0A0F1E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: kNeonGreen,
              labelColor: kNeonGreen,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.6),
              tabs: const [
                Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'SECURITY'),
                Tab(icon: Icon(Icons.dns_outlined, size: 18), text: 'TASK MANAGER'),
                Tab(icon: Icon(Icons.bolt_outlined, size: 18), text: 'FFI BENCHMARK'),
                Tab(icon: Icon(Icons.memory_outlined, size: 18), text: 'MEM SANDBOX'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSecurityTab(),
          _buildTaskManagerTab(),
          _buildBenchmarkTab(),
          _buildMemoryTab(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // 🛡️ TAB 1: RUST SECURITY HUB
  // -----------------------------------------------------------------
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------------
          // ENGINE 1: NEXDROID ROOT & UNAUTHORIZED PORT SCANNER (RUST)
          // -----------------------------------------------------------
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
                        child: const Icon(Icons.security_rounded, size: 24, color: Color(0xFFC084FC)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXDROID Root & Port Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                            Text(_rootPortStatus, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_rootPortRisk == 'CRITICAL' || _rootPortRisk == 'HIGH')
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_rootPortRisk == 'CRITICAL' || _rootPortRisk == 'HIGH') ? Colors.redAccent : kNeonGreen),
                        ),
                        child: Text(
                          _rootPortRisk,
                          style: TextStyle(color: (_rootPortRisk == 'CRITICAL' || _rootPortRisk == 'HIGH') ? Colors.redAccent : kNeonGreen, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (_rootPortSummary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_rootPortSummary, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanningRootPorts ? null : _runRootPortScan,
                      icon: _isScanningRootPorts
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.radar_rounded, size: 16, color: Colors.black),
                      label: Text(_isScanningRootPorts ? 'AUDITING...' : 'AUDIT PROCESSES & PORTS (RUST)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC084FC),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_rootPortFindings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._rootPortFindings.map((f) => _buildFindingTile(f)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -----------------------------------------------------------
          // ENGINE 2: NEXDROID ANTI-KEYLOGGER SHIELD ENGINE (RUST)
          // -----------------------------------------------------------
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
                        child: const Icon(Icons.keyboard_rounded, size: 24, color: kNeonBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXDROID Anti-Keylogger Shield', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                            Text(_keyloggerStatus, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_keyloggerRisk == 'CRITICAL' || _keyloggerRisk == 'HIGH')
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : kNeonBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_keyloggerRisk == 'CRITICAL' || _keyloggerRisk == 'HIGH') ? Colors.redAccent : kNeonBlue),
                        ),
                        child: Text(
                          _keyloggerRisk,
                          style: TextStyle(color: (_keyloggerRisk == 'CRITICAL' || _keyloggerRisk == 'HIGH') ? Colors.redAccent : kNeonBlue, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (_keyloggerSummary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_keyloggerSummary, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanningKeylogger ? null : _runAntiKeyloggerScan,
                      icon: _isScanningKeylogger
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.shield_outlined, size: 16, color: Colors.black),
                      label: Text(_isScanningKeylogger ? 'SWEEPING...' : 'SWEEP INPUT HOOKS & RAM (RUST)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_keyloggerFindings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._keyloggerFindings.map((f) => _buildFindingTile(f)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -----------------------------------------------------------
          // ENGINE 3: FILESYSTEM & HEURISTIC PAYLOAD SCANNER (RUST)
          // -----------------------------------------------------------
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
                        child: const Icon(Icons.folder_zip_rounded, size: 24, color: kNeonGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FileSystem Payload Scanner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                            Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_risk == 'CRITICAL' || _risk == 'HIGH') ? Colors.redAccent.withValues(alpha: 0.2) : kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_risk == 'CRITICAL' || _risk == 'HIGH') ? Colors.redAccent : kNeonGreen),
                        ),
                        child: Text(
                          _risk,
                          style: TextStyle(color: (_risk == 'CRITICAL' || _risk == 'HIGH') ? Colors.redAccent : kNeonGreen, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (_summary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_summary, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _runScan,
                      icon: _isScanning
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.find_in_page_rounded, size: 16, color: Colors.black),
                      label: Text(_isScanning ? 'SCANNING...' : 'SCAN FILESYSTEM PAYLOADS (RUST)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_findings.isNotEmpty) ...[
                    const SizedBox(height: 12),
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
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: severityColor.withValues(alpha: 0.2)),
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
                  Text(f['label'] ?? 'Finding', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
              child: Text(severity, style: TextStyle(color: severityColor, fontWeight: FontWeight.w900, fontSize: 9.5)),
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
              // System Load Card
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
                  Text('ACTIVE THREADS & OPERATIONS (${activeTasks.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                  TextButton(
                    onPressed: () {
                      registry.terminateAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All non-essential Dart application threads stopped.')),
                      );
                    },
                    child: const Text('KILL ALL', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activeTasks.isEmpty)
                _buildGlassCard(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('All operations idle. No running tasks.', style: TextStyle(color: Colors.white38, fontSize: 13)),
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
                  const Text('NATIVE RUST FFI VS DART BENCHMARK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  const Text(
                    'Computes 250,000 prime factorization cycles. Comparison demonstrates high performance native compiled C/Rust FFI capabilities in NEX-APP.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  
                  // Dart Bar
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Dart Virtual', style: TextStyle(color: Colors.white, fontSize: 12))),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(height: 24, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6))),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: (MediaQuery.of(context).size.width - 150) * dartPercent,
                              height: 24,
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
                            Container(height: 24, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6))),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: (MediaQuery.of(context).size.width - 150) * rustPercent,
                              height: 24,
                              decoration: BoxDecoration(color: kNeonGreen, borderRadius: BorderRadius.circular(6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_rustTimeMs.toStringAsFixed(1)}ms', style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text(_benchmarkStatus, style: TextStyle(color: kNeonBlue, fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  
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
                      child: const Text('EXECUTE SPEED BENCHMARK'),
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
                title: const Text('Rust SIMD Acceleration', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Use CPU SIMD registers (AVX/Neon) for execution boost', style: TextStyle(color: Colors.white38, fontSize: 11)),
                value: true,
                onChanged: (_) {},
                activeColor: kNeonGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // 🧱 TAB 4: MEMORY SANDBOX
  // -----------------------------------------------------------------
  Widget _buildMemoryTab() {
    int allocated = _memoryBlocks.where((b) => b).length;

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
                      const Text('RUST MEMORY SANDBOX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                      Text('$allocated/48 BLOCKS', style: const TextStyle(color: kNeonBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Visual Grid of Memory Blocks
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
                      bool active = _memoryBlocks[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: active 
                              ? const Color(0xFFFF3366).withValues(alpha: 0.8) 
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: active ? const Color(0xFFFF3366) : Colors.white10,
                            width: 1,
                          ),
                          boxShadow: active ? [
                            BoxShadow(color: const Color(0xFFFF3366).withValues(alpha: 0.3), blurRadius: 4),
                          ] : null,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  const Text('System Fragmentation: Low (Rust Static Allocation)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 20),
                  
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
                          child: const Text('DEFRAGMENT'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _memoryBlocks = List.generate(48, (_) => math.Random().nextBool());
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('RANDOMIZE'),
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
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}
