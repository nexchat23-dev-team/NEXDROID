import 'dart:async';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  static const String routeName = '/admin-dashboard';

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _pulseController;

  // Master System Remote Feature Flags State
  bool _isClonerEnabled = true;
  bool _isDefenderEnabled = true;
  bool _isFirewallEnabled = true;
  bool _isGamingActive = true;
  bool _isMarketplaceActive = true;
  bool _isBettingActive = true;
  bool _isMaintenanceMode = false;

  // Firewall State
  bool _inboundBlocking = true;
  bool _outboundFiltering = true;
  bool _stealthMode = false;
  final List<String> _blockedIPs = ['192.168.1.250', '10.0.0.99', '185.220.101.5'];
  final TextEditingController _ipInputController = TextEditingController();

  // Defender State
  final String _definitionVersion = '2.405.2026.PROD';
  bool _isScanning = false;
  String _scanLog = '';
  int _scannedFileCount = 0;
  int _detectedThreatsCount = 14;

  // Sample Users Data
  final List<Map<String, dynamic>> _users = [
    {
      'uid': 'usr_001',
      'username': 'Alex_Developer',
      'email': 'alex@nexapp.internal',
      'role': 'Admin',
      'status': 'active',
      'tokens': 15400,
      'joined': '2026-01-15',
    },
    {
      'uid': 'usr_002',
      'username': 'ShadowRider',
      'email': 'shadow@gmail.com',
      'role': 'User',
      'status': 'active',
      'tokens': 1200,
      'joined': '2026-03-20',
    },
    {
      'uid': 'usr_003',
      'username': 'SuspiciousBot99',
      'email': 'spammer@temp.mail',
      'role': 'User',
      'status': 'suspended',
      'tokens': 0,
      'joined': '2026-07-28',
    },
    {
      'uid': 'usr_004',
      'username': 'CyberMod_Elena',
      'email': 'elena@nexapp.internal',
      'role': 'Moderator',
      'status': 'active',
      'tokens': 4500,
      'joined': '2026-02-10',
    },
    {
      'uid': 'usr_005',
      'username': 'VipGamer_777',
      'email': 'gamer777@hotmail.com',
      'role': 'User',
      'status': 'active',
      'tokens': 8900,
      'joined': '2026-05-04',
    },
  ];

  // Audit Logs
  final List<Map<String, String>> _auditLogs = [
    {
      'time': 'Just now',
      'action': 'SUPERADMIN_LOGIN',
      'details': 'Session opened from 127.0.0.1 (SuperAdmin)',
      'severity': 'info',
    },
    {
      'time': '2 mins ago',
      'action': 'BAN_USER',
      'details': 'Suspended account usr_003 (Spam violation)',
      'severity': 'warning',
    },
    {
      'time': '15 mins ago',
      'action': 'DEFENDER_RULES_UPDATE',
      'details': 'Deployed definition patch v2.405.2026.PROD',
      'severity': 'info',
    },
    {
      'time': '1 hour ago',
      'action': 'FIREWALL_IP_BLOCK',
      'details': 'Blacklisted IP 185.220.101.5 (Port scan detected)',
      'severity': 'critical',
    },
  ];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _ipInputController.dispose();
    super.dispose();
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFFF2A6D) : const Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _runRustScanSimulation() async {
    setState(() {
      _isScanning = true;
      _scanLog = 'Initializing NEX Multi-Threaded Rust Scan Engine v2.0.0...\n';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _scanLog += 'Spawning 4 worker threads for parallel file queue...\n';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _scanLog += 'Checking Shannon Entropy & Magic Byte Headers (PE, ELF, DEX, APK)...\n';
      _scannedFileCount = 384;
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      _scanLog += 'Running YARA-style regex checks for Reverse Shells & Keyloggers...\n';
      _scannedFileCount = 1290;
      _detectedThreatsCount = 14;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _scanLog += 'SUCCESS: Scan Complete in 2940ms. Overall Threat Score: 18/100 (CLEAN).\n';
      _isScanning = false;
    });

    _auditLogs.insert(0, {
      'time': 'Just now',
      'action': 'RUST_SCAN_COMPLETED',
      'details': 'Scanned 1290 files in 2.9s. 14 findings analyzed.',
      'severity': 'info',
    });
  }

  void _toggleUserStatus(Map<String, dynamic> user) {
    setState(() {
      if (user['status'] == 'active') {
        user['status'] = 'suspended';
        _showSnackbar('User ${user['username']} has been SUSPENDED!', isError: true);
        _auditLogs.insert(0, {
          'time': 'Just now',
          'action': 'BAN_USER',
          'details': 'Suspended ${user['username']} (${user['uid']})',
          'severity': 'warning',
        });
      } else {
        user['status'] = 'active';
        _showSnackbar('User ${user['username']} access has been RESTORED.');
        _auditLogs.insert(0, {
          'time': 'Just now',
          'action': 'UNBAN_USER',
          'details': 'Restored access for ${user['username']}',
          'severity': 'info',
        });
      }
    });
  }

  void _adjustUserTokensDialog(Map<String, dynamic> user) {
    final textCtrl = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Grant Tokens to ${user['username']}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter token amount to grant or deduct (+/-):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.generating_tokens_rounded, color: Color(0xFFFFC857)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final amount = int.tryParse(textCtrl.text) ?? 0;
              setState(() {
                user['tokens'] = (user['tokens'] as int) + amount;
                _showSnackbar('Updated token balance for ${user['username']} by +$amount!');
              });
              Navigator.pop(ctx);
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBroadcastAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Color(0xFF00F5FF)),
            SizedBox(width: 10),
            Text('Broadcast System Announcement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Announcement Title',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message body for all connected users...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                _showSnackbar('System Announcement Broadcasted to 1,420 Active Users!');
                _auditLogs.insert(0, {
                  'time': 'Just now',
                  'action': 'SYSTEM_BROADCAST',
                  'details': 'Title: ${titleCtrl.text}',
                  'severity': 'info',
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Send Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF070A18);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Dynamic Glowing Background Gradients
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00F5FF).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Admin App Bar Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF00F5FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F5FF).withValues(alpha: 0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'NEX ADMIN SUITE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, _) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withValues(alpha: 0.2 + 0.3 * _pulseController.value),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF00E676)),
                                      ),
                                      child: const Text(
                                        'LIVE NODE',
                                        style: TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Text(
                              'SuperAdmin: demonalexander526@gmail.com',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showBroadcastAnnouncementDialog,
                        icon: const Icon(Icons.campaign_rounded, color: Color(0xFF00F5FF)),
                        tooltip: 'Broadcast Announcement',
                      ),
                    ],
                  ),
                ),

                // Glassmorphism Navigation Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00F5FF)],
                      ),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: const [
                      Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Control Center'),
                      Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Users & Roles'),
                      Tab(icon: Icon(Icons.shield_rounded, size: 18), text: 'Defender Engine'),
                      Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'Firewall'),
                      Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Telemetry'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Main Tab Content Area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildControlCenterTab(),
                      _buildUsersTab(),
                      _buildDefenderTab(),
                      _buildFirewallTab(),
                      _buildTelemetryTab(),
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

  // ─── TAB 1: CONTROL CENTER & METRICS GRID ───
  Widget _buildControlCenterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Metrics Cards
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Users', '1,420', '+12 today', Icons.people_rounded, const Color(0xFF00F5FF))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Active Admins', '3', 'Online', Icons.verified_user_rounded, const Color(0xFF7C4DFF))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Threats Blocked', '389', 'Definition v2.405', Icons.security_rounded, const Color(0xFFFF2A6D))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Firewall Blocks', '42', '5 IPs Banned', Icons.local_fire_department_rounded, const Color(0xFFFFC857))),
            ],
          ),

          const SizedBox(height: 24),

          // Master Feature Flags Section Header
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF00F5FF), size: 20),
              SizedBox(width: 8),
              Text(
                'MASTER REMOTE FEATURE FLAGS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildFeatureToggleCard(
            'App Cloner Engine',
            'Allow users to create up to 5 cloned isolated app spaces.',
            Icons.copy_all_rounded,
            _isClonerEnabled,
            (val) => setState(() => _isClonerEnabled = val),
            const Color(0xFF7C4DFF),
          ),
          _buildFeatureToggleCard(
            'Security Defender Engine',
            'Automated threat heuristic analysis & real-time virus scans.',
            Icons.shield_rounded,
            _isDefenderEnabled,
            (val) => setState(() => _isDefenderEnabled = val),
            const Color(0xFF00F5FF),
          ),
          _buildFeatureToggleCard(
            'Firewall Guard Engine',
            'Inbound packet filtering, stealth mode & IP blacklisting.',
            Icons.local_fire_department_rounded,
            _isFirewallEnabled,
            (val) => setState(() => _isFirewallEnabled = val),
            const Color(0xFFFF5D8F),
          ),
          _buildFeatureToggleCard(
            'Gaming Hub & Arcades',
            'Multiplayer sessions, tournament ladders & level rewards.',
            Icons.sports_esports_rounded,
            _isGamingActive,
            (val) => setState(() => _isGamingActive = val),
            const Color(0xFFFFC857),
          ),
          _buildFeatureToggleCard(
            'Marketplace Module',
            'Item listings, buyer/seller offers & token transactions.',
            Icons.storefront_rounded,
            _isMarketplaceActive,
            (val) => setState(() => _isMarketplaceActive = val),
            const Color(0xFF00E676),
          ),
          _buildFeatureToggleCard(
            'Betting Module',
            'Live odds, bet slip processing & sports bets.',
            Icons.sports_soccer_rounded,
            _isBettingActive,
            (val) => setState(() => _isBettingActive = val),
            const Color(0xFFFF6B6B),
          ),
          _buildFeatureToggleCard(
            '🚨 Emergency Maintenance Mode',
            'Lock application for non-admin users during updates.',
            Icons.warning_amber_rounded,
            _isMaintenanceMode,
            (val) => setState(() => _isMaintenanceMode = val),
            const Color(0xFFFF2A6D),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: USERS & ROLES MANAGEMENT ───
  Widget _buildUsersTab() {
    final filteredUsers = _users.where((u) {
      final query = _searchQuery.toLowerCase();
      return u['username'].toString().toLowerCase().contains(query) || u['email'].toString().toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search & Filter bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by username or email...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00F5FF)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // User Table List
          Expanded(
            child: ListView.separated(
              itemCount: filteredUsers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final u = filteredUsers[index];
                final isSuspended = u['status'] == 'suspended';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSuspended ? const Color(0xFFFF2A6D).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSuspended ? const Color(0xFFFF2A6D).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isSuspended ? const Color(0xFFFF2A6D) : const Color(0xFF7C4DFF),
                        child: Text(
                          u['username'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  u['username'],
                                  style: TextStyle(
                                    color: isSuspended ? const Color(0xFFFF2A6D) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u['role'] == 'Admin'
                                        ? const Color(0xFF7C4DFF)
                                        : (u['role'] == 'Moderator' ? const Color(0xFF00F5FF) : Colors.white12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    u['role'],
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              u['email'],
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.generating_tokens_rounded, color: Color(0xFFFFC857), size: 14),
                                const SizedBox(width: 4),
                                Text('${u['tokens']} tokens', style: const TextStyle(color: Color(0xFFFFC857), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // User Action Menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                        color: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (action) {
                          if (action == 'toggle_status') {
                            _toggleUserStatus(u);
                          } else if (action == 'tokens') {
                            _adjustUserTokensDialog(u);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'toggle_status',
                            child: Row(
                              children: [
                                Icon(isSuspended ? Icons.check_circle_rounded : Icons.block_rounded, color: isSuspended ? const Color(0xFF00E676) : const Color(0xFFFF2A6D), size: 18),
                                const SizedBox(width: 8),
                                Text(isSuspended ? 'Unban User' : 'Ban/Suspend User', style: TextStyle(color: isSuspended ? const Color(0xFF00E676) : const Color(0xFFFF2A6D))),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'tokens',
                            child: Row(
                              children: [
                                Icon(Icons.generating_tokens_rounded, color: Color(0xFFFFC857), size: 18),
                                SizedBox(width: 8),
                                Text('Adjust Tokens', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: DEFENDER & RUST SCANNER ENGINE ───
  Widget _buildDefenderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF7C4DFF).withValues(alpha: 0.3), const Color(0xFF00F5FF).withValues(alpha: 0.15)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00F5FF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rust Multi-Threaded Engine v2.0.0', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Definition Version: $_definitionVersion', style: const TextStyle(color: Color(0xFF00F5FF), fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Scanned Files: $_scannedFileCount | Threats Tracked: $_detectedThreatsCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _runRustScanSimulation,
                  icon: _isScanning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.play_arrow_rounded, color: Colors.black),
                  label: Text(_isScanning ? 'Scanning...' : 'Run Scan', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F5FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Scan Console Output
          const Text('SECURITY SCAN CONSOLE LOG', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00F5FF).withValues(alpha: 0.3)),
            ),
            child: SingleChildScrollView(
              child: Text(
                _scanLog.isEmpty ? 'Click "Run Scan" to execute Rust security engine...' : _scanLog,
                style: const TextStyle(color: Color(0xFF00E676), fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('RECENT DETECTED THREATS & QUARANTINE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),

          _buildThreatItem('payload_dropper.apk', 'APK Package Header Spoofing', 'CRITICAL', 'Threat Score: 95/100', Colors.red),
          _buildThreatItem('reverse_shell.sh', 'nc -e /bin/bash Pattern Match', 'HIGH', 'Threat Score: 88/100', Colors.orange),
          _buildThreatItem('config_backup.env', 'Hardcoded AWS Access Key', 'MEDIUM', 'Threat Score: 60/100', Colors.amber),
        ],
      ),
    );
  }

  // ─── TAB 4: FIREWALL ADMIN CENTER ───
  Widget _buildFirewallTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureToggleCard('Inbound Packet Blocking', 'Strict inspection of all incoming TCP/UDP connections.', Icons.arrow_downward_rounded, _inboundBlocking, (v) => setState(() => _inboundBlocking = v), const Color(0xFF00F5FF)),
          _buildFeatureToggleCard('Outbound Traffic Filtering', 'Prevent unauthorized telemetry or reverse connections.', Icons.arrow_upward_rounded, _outboundFiltering, (v) => setState(() => _outboundFiltering = v), const Color(0xFF7C4DFF)),
          _buildFeatureToggleCard('Stealth Mode', 'Hide server node response from generic ping/port sweeps.', Icons.visibility_off_rounded, _stealthMode, (v) => setState(() => _stealthMode = v), const Color(0xFFFF5D8F)),

          const SizedBox(height: 20),
          const Text('IP BLACKLIST MANAGER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipInputController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter IP address (e.g. 192.168.1.50)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2A6D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () {
                  if (_ipInputController.text.isNotEmpty) {
                    setState(() {
                      _blockedIPs.add(_ipInputController.text.trim());
                      _ipInputController.clear();
                      _showSnackbar('IP added to Firewall Blacklist!', isError: true);
                    });
                  }
                },
                child: const Text('Ban IP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ..._blockedIPs.map((ip) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF2A6D).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Color(0xFFFF2A6D), size: 18),
                    const SizedBox(width: 10),
                    Text(ip, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 20),
                      onPressed: () {
                        setState(() {
                          _blockedIPs.remove(ip);
                          _showSnackbar('IP $ip unblocked.');
                        });
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── TAB 5: TELEMETRY & AUDIT LOGS ───
  Widget _buildTelemetryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REAL-TIME SYSTEM AUDIT LOGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),

          Expanded(
            child: ListView.separated(
              itemCount: _auditLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = _auditLogs[index];
                final isWarn = log['severity'] == 'warning' || log['severity'] == 'critical';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isWarn ? const Color(0xFFFF2A6D).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isWarn ? const Color(0xFFFF2A6D).withValues(alpha: 0.3) : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isWarn ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                        color: isWarn ? const Color(0xFFFF2A6D) : const Color(0xFF00F5FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(log['action']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const Spacer(),
                                Text(log['time']!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(log['details']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPER COMPONENTS ───
  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: color, blurRadius: 10)])),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFeatureToggleCard(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: value ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildThreatItem(String filename, String reason, String severity, String threatScore, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(filename, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(severity, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(threatScore, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
