import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_app/models/installed_app.dart';
import 'package:nex_app/services/app_cloner_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF5D7CFF);
const _kGreen = Color(0xFF22C55E);
const _kPink = Color(0xFFFF69B4);
const _kBg = Color(0xFF060A18);
const _kSurface = Color(0xFF0F172A);

// ─── Data models ──────────────────────────────────────────────────────────────
class _CloneEntry {
  _CloneEntry({
    required this.app,
    required this.clonedAt,
    this.isRunning = false,
  });

  final InstalledApp app;
  final DateTime clonedAt;
  bool isRunning;
  int cpuUsage = 0;
  int ramUsage = 0;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AppClonerHubScreen extends StatefulWidget {
  const AppClonerHubScreen({super.key});
  static const String routeName = '/app-cloner-hub';

  @override
  State<AppClonerHubScreen> createState() => _AppClonerHubScreenState();
}

class _AppClonerHubScreenState extends State<AppClonerHubScreen>
    with TickerProviderStateMixin {
  // ── animation controllers ──────────────────────────────────────────────────
  late final AnimationController _bgAnim =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();
  late final AnimationController _pulseAnim =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final AnimationController _scanAnim =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  // ── state ──────────────────────────────────────────────────────────────────
  List<InstalledApp> _installedApps = [];
  bool _isLoadingApps = true;
  String? _appsError;
  String _searchQuery = '';
  InstalledApp? _selectedApp;

  // cloning flow
  bool _isCloningActive = false;
  double _cloneProgress = 0;
  String _cloneStepMessage = '';
  String _currentStep = '';
  bool _cloneDone = false;
  StreamSubscription<dynamic>? _cloneSub;

  // clones collection
  final List<_CloneEntry> _clones = [];
  int _selectedTab = 0; // 0=Live 1=History 2=Logs

  // live logs
  final List<String> _logs = [];
  Timer? _resourceTimer;

  // search focus
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
    _loadSavedClones();
    _startResourceSimulation();
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _pulseAnim.dispose();
    _scanAnim.dispose();
    _searchCtrl.dispose();
    _cloneSub?.cancel();
    _resourceTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveClones() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _clones.map((c) => {
      'packageName': c.app.packageName,
      'appName': c.app.appName,
      'clonedAt': c.clonedAt.toIso8601String(),
      'isRunning': false, // always save as stopped
    }).toList();
    await prefs.setString('cloned_apps', jsonEncode(list));
  }

  Future<void> _loadSavedClones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cloned_apps');
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final app = InstalledApp(
            packageName: map['packageName'] as String,
            appName: map['appName'] as String,
          );
          _clones.add(_CloneEntry(
            app: app,
            clonedAt: DateTime.parse(map['clonedAt'] as String),
            isRunning: false,
          ));
        }
      });
    } catch (e) {
      debugPrint('Error loading saved clones: $e');
    }
  }

  // ── data loading ───────────────────────────────────────────────────────────
  Future<void> _loadApps() async {
    setState(() {
      _isLoadingApps = true;
      _appsError = null;
    });
    try {
      final apps = await AppClonerService.getInstalledApps();
      if (!mounted) return;
      setState(() {
        _installedApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingApps = false;
          _appsError = 'Failed to load apps: $e';
        });
      }
    }
  }

  void _startResourceSimulation() {
    _resourceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        final rng = Random();
        for (final c in _clones) {
          if (c.isRunning) {
            c.cpuUsage = 5 + rng.nextInt(40);
            c.ramUsage = 60 + rng.nextInt(120);
          }
        }
      });
    });
  }

  // ── cloning ────────────────────────────────────────────────────────────────
  Future<void> _startClone(InstalledApp app) async {
    if (_isCloningActive) return;
    setState(() {
      _isCloningActive = true;
      _cloneProgress = 0;
      _cloneDone = false;
      _cloneStepMessage = 'Initializing clone engine...';
      _currentStep = 'init';
      _logs.add(
          '${_timestamp()} ▶  Clone started for ${app.appName} (${app.packageName})');
    });

    final stream = AppClonerService.cloneAppStream(
      packageName: app.packageName,
      appName: app.appName,
    );

    _cloneSub = stream.listen((step) {
      if (!mounted) return;
      setState(() {
        _cloneProgress = step.progress;
        _cloneStepMessage = step.message;
        _currentStep = step.step;
        _logs.add('${_timestamp()}  ${step.message}');
        if (step.success) {
          _cloneDone = true;
          _isCloningActive = false;
          // add to clones list
          final entry = _CloneEntry(
            app: app,
            clonedAt: DateTime.now(),
            isRunning: step.launched,
          );
          if (!_clones.any((c) => c.app.packageName == app.packageName)) {
            _clones.insert(0, entry);
            _saveClones();
          }
          _logs.add('${_timestamp()} ✓  Clone complete!');
        }
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() {
        _isCloningActive = false;
        _cloneStepMessage = 'Error: $e';
        _logs.add('${_timestamp()} ✗  Error: $e');
      });
    });
  }

  Future<void> _launchClone(_CloneEntry entry) async {
    setState(() {
      entry.isRunning = true;
      _logs.add('${_timestamp()} ▶  Launching ${entry.app.appName}...');
    });

    final launched =
        await AppClonerService.launchClonedApp(entry.app.packageName);
    if (!mounted) return;
    setState(() {
      entry.isRunning = launched;
      _logs.add(launched
          ? '${_timestamp()} ✓  ${entry.app.appName} launched'
          : '${_timestamp()} ⚠  Could not launch (device may need ADB)');
    });
    if (!launched) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _kGreen.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: _kGreen, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'App Clone Created Successfully!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'The clone profile was created in an isolated environment. On a rooted device or with ADB, you can launch it directly.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchClone(entry);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.shop, color: _kPink),
                  label: const Text('Open Play Store', style: TextStyle(color: _kPink)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _killClone(_CloneEntry entry) async {
    await AppClonerService.killClone(entry.app.packageName);
    if (!mounted) return;
    setState(() {
      entry.isRunning = false;
      entry.cpuUsage = 0;
      entry.ramUsage = 0;
      _logs.add('${_timestamp()} ■  ${entry.app.appName} stopped');
    });
  }

  void _removeClone(_CloneEntry entry) {
    setState(() {
      _clones.remove(entry);
      _saveClones();
      _logs.add('${_timestamp()} [DEL] ${entry.app.appName} clone deleted');
    });
  }

  String _timestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}]';
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  List<InstalledApp> get _filteredApps {
    if (_searchQuery.isEmpty) return _installedApps;
    return _installedApps
        .where((a) =>
            a.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            a.packageName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  IconData _stepIcon(String step) {
    switch (step) {
      case 'analyzing':
        return Icons.analytics_rounded;
      case 'extracting':
        return Icons.layers_rounded;
      case 'sandbox':
        return Icons.security_rounded;
      case 'repackaging':
        return Icons.inventory_2_rounded;
      case 'signing':
        return Icons.verified_rounded;
      case 'installing':
        return Icons.download_done_rounded;
      case 'done':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.settings_rounded;
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnim,
              builder: (_, __) => CustomPaint(
                painter: _ClonerBgPainter(_bgAnim.value),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStatsBar(),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'App cloning is a sandbox simulation feature',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildAppSelector()),
                      SliverToBoxAdapter(child: _buildCloneActionPanel()),
                      if (_clones.isNotEmpty || _logs.isNotEmpty)
                        SliverToBoxAdapter(child: _buildClonesPanel()),
                      SliverToBoxAdapter(child: _buildFeaturesGrid()),
                      SliverToBoxAdapter(child: _buildLogsPanel()),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _glassButton(
            Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kGreen,
                          boxShadow: [
                            BoxShadow(
                              color: _kGreen
                                  .withAlpha((80 * _pulseAnim.value).round()),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'APP CLONER HUB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Clone · Isolate · Launch',
                  style: TextStyle(color: _kBlue, fontSize: 11, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
          _glassButton(Icons.refresh_rounded, onTap: _loadApps),
        ],
      ),
    );
  }

  Widget _glassButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(38)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // ── STATS BAR ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    final running = _clones.where((c) => c.isRunning).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _statChip('${_clones.length}', 'Clones', _kBlue),
          const SizedBox(width: 8),
          _statChip('$running', 'Running', _kGreen),
          const SizedBox(width: 8),
          _statChip('${_installedApps.length}', 'Apps', _kPink),
          const SizedBox(width: 8),
          _statChip('${_logs.length}', 'Logs', Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ── APP SELECTOR ───────────────────────────────────────────────────────────
  Widget _buildAppSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Select App to Clone'),
          const SizedBox(height: 10),
          // search
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search installed apps...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withAlpha(18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingApps)
            _shimmerList()
          else if (_appsError != null)
            _errorState()
          else if (_filteredApps.isEmpty)
            _emptyState()
          else
            _appList(),
        ],
      ),
    );
  }

  Widget _appList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: _filteredApps.length,
        itemBuilder: (_, i) => _appTile(_filteredApps[i]),
      ),
    );
  }

  Widget _appTile(InstalledApp app) {
    final selected = _selectedApp?.packageName == app.packageName;
    return GestureDetector(
      onTap: () => setState(() => _selectedApp = app),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? _kBlue.withAlpha(50)
              : Colors.white.withAlpha(13),
          border: Border.all(
            color: selected ? _kBlue.withAlpha(160) : Colors.white.withAlpha(25),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: _kBlue.withAlpha(60),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          children: [
            _appIcon(app, 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.appName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(app.packageName,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (_clones.any((c) => c.app.packageName == app.packageName))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kGreen.withAlpha(40),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kGreen.withAlpha(100)),
                ),
                child: const Text('Cloned',
                    style: TextStyle(
                        color: _kGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              )
            else if (selected)
              const Icon(Icons.check_circle_rounded, color: _kBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _appIcon(InstalledApp app, double size) {
    if (app.icon != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
              image: MemoryImage(app.icon!), fit: BoxFit.cover),
        ),
      );
    }
    // Generate a color-coded placeholder icon from app name
    final colorSeed = app.packageName.codeUnits
        .fold(0, (a, b) => a + b);
    final colors = [
      _kBlue, _kGreen, _kPink, Colors.orangeAccent,
      Colors.cyanAccent, Colors.purpleAccent,
    ];
    final color = colors[colorSeed % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withAlpha(40),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Center(
        child: Text(
          app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
          style: TextStyle(
              color: color, fontSize: size * 0.4, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _shimmerList() {
    return Column(
      children: List.generate(
          3,
          (_) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withAlpha(13),
                ),
              )),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.redAccent.withAlpha(20),
        border: Border.all(color: Colors.redAccent.withAlpha(40)),
      ),
      child: Center(
        child: Column(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
          const SizedBox(height: 10),
          Text(_appsError ?? 'Error', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withAlpha(10),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: const Center(
        child: Column(children: [
          Icon(Icons.apps_rounded, color: Colors.white24, size: 36),
          SizedBox(height: 10),
          Text('No apps found',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      ),
    );
  }

  // ── CLONE ACTION PANEL ─────────────────────────────────────────────────────
  Widget _buildCloneActionPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B2A6B).withAlpha(230),
                  _kBg.withAlpha(250),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withAlpha(38)),
              boxShadow: [
                BoxShadow(
                    color: _kBlue.withAlpha(60),
                    blurRadius: 32,
                    offset: const Offset(0, 12))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _scanAnim,
                      builder: (_, __) => Transform.rotate(
                        angle: _scanAnim.value * 2 * pi,
                        child: const Icon(Icons.blur_circular_rounded,
                            color: _kBlue, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Clone Engine',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    if (_selectedApp != null && !_isCloningActive && !_cloneDone)
                      _appIcon(_selectedApp!, 32),
                  ],
                ),
                const SizedBox(height: 14),

                // progress display
                if (_isCloningActive || _cloneDone) ...[
                  _buildCloningProgress(),
                  const SizedBox(height: 14),
                ],

                // action buttons
                if (_selectedApp == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withAlpha(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app_rounded,
                            color: Colors.white38, size: 18),
                        SizedBox(width: 8),
                        Text('Select an app from the list above to begin',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ] else if (_isCloningActive) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      label: const Text('Cloning in progress...'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBlue.withAlpha(140),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ] else if (_cloneDone) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: _kGreen.withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kGreen),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: _kGreen),
                              SizedBox(width: 8),
                              Text('Clone Complete!', style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            final entry = _clones.firstWhere((c) =>
                                c.app.packageName ==
                                _selectedApp!.packageName,
                                orElse: () => _CloneEntry(
                                    app: _selectedApp!,
                                    clonedAt: DateTime.now()));
                            _launchClone(entry);
                          },
                          icon: const Icon(Icons.rocket_launch_rounded),
                          label: const Text('Launch Clone'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cloneDone = false;
                              _cloneProgress = 0;
                              _selectedApp = null;
                            });
                          },
                          icon: const Icon(Icons.add_rounded, color: _kBlue),
                          label: const Text('Clone Another',
                              style: TextStyle(color: _kBlue)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _kBlue),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isCloningActive ? null : () => _startClone(_selectedApp!),
                      icon: const Icon(Icons.copy_all_rounded),
                      label: Text('Clone ${_selectedApp!.appName}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kBlue.withAlpha(100),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloningProgress() {
    final steps = [
      'analyzing', 'extracting', 'sandbox',
      'repackaging', 'signing', 'installing', 'done',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _cloneProgress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.white.withAlpha(25),
              valueColor: AlwaysStoppedAnimation<Color>(
                  _cloneDone ? _kGreen : _kBlue),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // step indicators
        Row(
          children: steps.map((s) {
            final idx = steps.indexOf(s);
            final currentIdx = steps.indexOf(_currentStep);
            final isActive = idx == currentIdx;
            final isDone = currentIdx > idx;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? _kGreen
                          : (isActive ? _kBlue : Colors.white.withAlpha(25)),
                      border: Border.all(
                        color: isActive
                            ? _kBlue
                            : (isDone
                                ? _kGreen
                                : Colors.white.withAlpha(40)),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : _stepIcon(s),
                        size: 12,
                        color: (isDone || isActive)
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(_stepIcon(_currentStep), color: _kBlue, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _cloneStepMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '${(_cloneProgress * 100).round()}%',
              style: TextStyle(
                color: _cloneDone ? _kGreen : _kBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── CLONES PANEL ───────────────────────────────────────────────────────────
  Widget _buildClonesPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _kSurface.withAlpha(200),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // tab row
                Row(
                  children: [
                    const Icon(Icons.dashboard_customize_rounded,
                        color: _kPink, size: 18),
                    const SizedBox(width: 8),
                    const Text('Clone Manager',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    _tabBtn('Live', 0),
                    const SizedBox(width: 6),
                    _tabBtn('History', 1),
                    const SizedBox(width: 6),
                    _tabBtn('Logs', 2),
                  ],
                ),
                const SizedBox(height: 14),
                if (_selectedTab == 0) _buildLiveTab(),
                if (_selectedTab == 1) _buildHistoryTab(),
                if (_selectedTab == 2) _buildLogsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final sel = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: sel ? _kBlue : Colors.transparent,
          border: Border.all(
              color: sel ? _kBlue : Colors.white.withAlpha(40)),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildLiveTab() {
    if (_clones.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No clones yet. Start cloning above!',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      );
    }
    return Column(
      children: _clones.map((c) => _cloneTile(c)).toList(),
    );
  }

  Widget _cloneTile(_CloneEntry entry) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: entry.isRunning
            ? _kGreen.withAlpha(20)
            : Colors.white.withAlpha(10),
        border: Border.all(
          color: entry.isRunning
              ? _kGreen.withAlpha(80)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _appIcon(entry.app, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.app.appName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                entry.isRunning ? _kGreen : Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          entry.isRunning ? 'Running' : 'Stopped',
                          style: TextStyle(
                            color:
                                entry.isRunning ? _kGreen : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              if (!entry.isRunning)
                _actionBtn(
                    Icons.rocket_launch_rounded, _kGreen, () => _launchClone(entry))
              else
                _actionBtn(
                    Icons.stop_circle_rounded, Colors.redAccent, () => _killClone(entry)),
              const SizedBox(width: 6),
              _actionBtn(Icons.delete_outline_rounded, Colors.white38,
                  () => _removeClone(entry)),
            ],
          ),
          if (entry.isRunning) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                      'CPU', '${entry.cpuUsage}%', Colors.orangeAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStat(
                      'RAM', '${entry.ramUsage} MB', _kBlue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStat('Network', 'Active', _kGreen),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withAlpha(15),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(value,
                key: ValueKey(value),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_clones.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: Text('No history yet',
                style: TextStyle(color: Colors.white38, fontSize: 12))),
      );
    }
    return Column(
      children: _clones
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _appIcon(c.app, 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.app.appName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            'Cloned ${_timeAgo(c.clonedAt)}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _kGreen.withAlpha(30),
                        border: Border.all(color: _kGreen.withAlpha(80)),
                      ),
                      child: const Text('Cloned',
                          style: TextStyle(
                              color: _kGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                      onPressed: () => _removeClone(c),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: Text('No logs yet',
                style: TextStyle(color: Colors.white38, fontSize: 12))),
      );
    }
    return Container(
      height: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withAlpha(100),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _logs.length,
        itemBuilder: (_, i) {
          final log = _logs[_logs.length - 1 - i];
          Color c = Colors.white60;
          if (log.contains('✓')) c = _kGreen;
          if (log.contains('✗') || log.contains('⚠')) c = Colors.redAccent;
          if (log.contains('▶')) c = _kBlue;
          return Text(log, style: TextStyle(color: c, fontSize: 10, fontFamily: 'monospace'));
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  // ── FEATURES GRID ──────────────────────────────────────────────────────────
  Widget _buildFeaturesGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Professional Toolset'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: const [
              _FeatureTile(
                icon: Icons.security_rounded,
                title: 'Secure Sandbox',
                subtitle: 'Isolated permission layer per clone',
                color: _kGreen,
              ),
              _FeatureTile(
                icon: Icons.bolt_rounded,
                title: 'Fast Launch',
                subtitle: 'Sub-second clone boot time',
                color: _kBlue,
              ),
              _FeatureTile(
                icon: Icons.palette_rounded,
                title: 'Theme Cloning',
                subtitle: 'Mirror original UI exactly',
                color: _kPink,
              ),
              _FeatureTile(
                icon: Icons.backup_rounded,
                title: 'Auto Backup',
                subtitle: 'Continuous snapshot protection',
                color: Colors.orangeAccent,
              ),
              _FeatureTile(
                icon: Icons.sync_alt_rounded,
                title: 'Cross-Device Sync',
                subtitle: 'Push clone state to other devices',
                color: Colors.cyanAccent,
              ),
              _FeatureTile(
                icon: Icons.monitor_heart_rounded,
                title: 'Resource Monitor',
                subtitle: 'Live CPU & RAM per clone',
                color: Colors.purpleAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LOGS PANEL ─────────────────────────────────────────────────────────────
  Widget _buildLogsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _kSurface.withAlpha(180),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kGreen.withAlpha(
                              (200 * _pulseAnim.value).round()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('System Logs',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _logs.clear()),
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_logs.isEmpty)
                  const Text('No logs yet. Clone an app to see logs here.',
                      style: TextStyle(color: Colors.white38, fontSize: 11))
                else
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withAlpha(80),
                      border: Border.all(color: Colors.white.withAlpha(10)),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final log = _logs[_logs.length - 1 - i];
                        Color c = Colors.white54;
                        if (log.contains('✓')) c = _kGreen;
                        if (log.contains('✗') || log.contains('⚠')) c = Colors.redAccent;
                        if (log.contains('▶')) c = _kBlue;
                        return Text(log,
                            style: TextStyle(
                                color: c, fontSize: 10, fontFamily: 'monospace'));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF0F172A).withAlpha(190),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(35),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────
class _ClonerBgPainter extends CustomPainter {
  _ClonerBgPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // deep space gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF060A18), Color(0xFF0D1230), Color(0xFF060A18)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    // glowing orbs
    _drawOrb(canvas, size, Offset(size.width * 0.8, size.height * 0.15),
        200, const Color(0xFF5D7CFF), t);
    _drawOrb(canvas, size, Offset(size.width * 0.15, size.height * 0.75),
        170, const Color(0xFFFF69B4), 1 - t);

    // orbit rings
    final orbitCenter = Offset(size.width * 0.8, size.height * 0.15);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(orbitCenter, 60 + i * 35 + t * 20, orbitPaint);
    }

    // orbiting particle
    const num radians = pi * 2;
    for (var i = 0; i < 6; i++) {
      final angle = t * radians + (i * radians / 6);
      final r = 65 + i * 12.0;
      final dx = orbitCenter.dx + cos(angle) * r;
      final dy = orbitCenter.dy + sin(angle) * r;
      canvas.drawCircle(
          Offset(dx, dy),
          2,
          Paint()
            ..color = const Color(0xFF5D7CFF).withAlpha(180));
    }

    // stars
    final rng = Random(42);
    final starPaint = Paint()..color = Colors.white.withAlpha(160);
    for (var i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.6 + 0.4;
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // scan line
    final scanY = size.height * t;
    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      Paint()
        ..color = const Color(0xFF5D7CFF).withAlpha(30)
        ..strokeWidth = 1.5,
    );
  }

  void _drawOrb(Canvas canvas, Size size, Offset center, double radius,
      Color color, double anim) {
    canvas.drawCircle(
      center,
      radius * (0.9 + anim * 0.1),
      Paint()
        ..color = color.withAlpha(25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
  }

  @override
  bool shouldRepaint(covariant _ClonerBgPainter old) => old.t != t;
}
