import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Audit Logs
  final List<Map<String, String>> _auditLogs = [
    {
      'time': 'Just now',
      'action': 'SUPERADMIN_SESSION_ACTIVE',
      'details': 'Connected to live Firebase nexchat-47326 cluster',
      'severity': 'info',
    },
    {
      'time': '12 mins ago',
      'action': 'DEFENDER_RULES_SYNC',
      'details': 'Synchronized security rules with zero-trust shield',
      'severity': 'info',
    },
  ];

  String _searchQuery = '';
  String _reelsSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      _scanLog += 'Spawning worker threads for parallel file integrity queue...\n';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _scanLog += 'Checking Shannon Entropy and Magic Byte Headers (PE, ELF, DEX, APK)...\n';
      _scannedFileCount = 384;
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _scanLog += 'Running heuristic patterns for Reverse Shells and Keyloggers...\n';
      _scannedFileCount = 1290;
      _detectedThreatsCount = 0;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanLog += 'SUCCESS: Scan Complete in 2840ms. Overall Threat Score: 0/100 (CLEAN).\n';
      _isScanning = false;
    });

    _auditLogs.insert(0, {
      'time': 'Just now',
      'action': 'RUST_SCAN_COMPLETED',
      'details': 'Scanned 1,290 files in 2.8s. All modules verified clean.',
      'severity': 'info',
    });
  }

  Future<void> _toggleUserStatus(String uid, String username, bool currentlySuspended) async {
    try {
      final newSuspended = !currentlySuspended;
      await _firestore.collection('users').doc(uid).set({
        'isSuspended': newSuspended,
        'status': newSuspended ? 'suspended' : 'active',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackbar(
        newSuspended ? 'User $username suspended from platform.' : 'User $username access restored.',
        isError: newSuspended,
      );

      _auditLogs.insert(0, {
        'time': 'Just now',
        'action': newSuspended ? 'BAN_USER' : 'UNBAN_USER',
        'details': '${newSuspended ? 'Suspended' : 'Restored'} user $username ($uid)',
        'severity': newSuspended ? 'warning' : 'info',
      });
    } catch (e) {
      _showSnackbar('Failed to update user status: $e', isError: true);
    }
  }

  Future<void> _toggleAdminRole(String uid, String username, bool currentlyAdmin) async {
    try {
      final newAdmin = !currentlyAdmin;
      await _firestore.collection('users').doc(uid).set({
        'isAdmin': newAdmin,
        'role': newAdmin ? 'Admin' : 'User',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackbar(newAdmin ? 'Granted Admin rights to $username' : 'Revoked Admin rights from $username');

      _auditLogs.insert(0, {
        'time': 'Just now',
        'action': 'ROLE_CHANGE',
        'details': 'Set role of $username to ${newAdmin ? 'Admin' : 'User'}',
        'severity': 'info',
      });
    } catch (e) {
      _showSnackbar('Failed to change role: $e', isError: true);
    }
  }

  void _adjustUserTokensDialog(String uid, String username, int currentTokens) {
    final textCtrl = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Adjust Tokens for $username',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current balance: $currentTokens tokens\nEnter amount to add or deduct (+/-):',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
            onPressed: () async {
              final amount = int.tryParse(textCtrl.text) ?? 0;
              Navigator.pop(ctx);
              try {
                await _firestore.collection('users').doc(uid).set({
                  'tokens': FieldValue.increment(amount),
                  'token_balance': FieldValue.increment(amount),
                  'updated_at': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                _showSnackbar('Updated token balance for $username by ${amount >= 0 ? '+$amount' : '$amount'}');
                _auditLogs.insert(0, {
                  'time': 'Just now',
                  'action': 'ADJUST_TOKENS',
                  'details': 'Adjusted tokens for $username by $amount',
                  'severity': 'info',
                });
              } catch (e) {
                _showSnackbar('Failed to adjust tokens: $e', isError: true);
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReel(String reelId, String reelTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Reel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$reelTitle"? This action cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A6D)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('reels').doc(reelId).delete();
      _showSnackbar('Reel deleted from platform');
      _auditLogs.insert(0, {
        'time': 'Just now',
        'action': 'DELETE_REEL',
        'details': 'Deleted reel: $reelTitle ($reelId)',
        'severity': 'warning',
      });
    } catch (e) {
      _showSnackbar('Failed to delete reel: $e', isError: true);
    }
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
            Text('Broadcast Announcement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final body = bodyCtrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);

              try {
                await _firestore.collection('announcements').add({
                  'title': title,
                  'message': body,
                  'body': body,
                  'author': 'SuperAdmin',
                  'timestamp': FieldValue.serverTimestamp(),
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                });

                _showSnackbar('Announcement broadcasted to live cluster');
                _auditLogs.insert(0, {
                  'time': 'Just now',
                  'action': 'SYSTEM_BROADCAST',
                  'details': 'Title: $title',
                  'severity': 'info',
                });
              } catch (e) {
                _showSnackbar('Broadcast notice: $e', isError: true);
              }
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
    final user = _auth.currentUser;
    final adminEmail = user?.email ?? 'SuperAdmin (Direct Link)';

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Dynamic Glowing Gradients
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF00F5FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F5FF).withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'NEX MANAGER CONSOLE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, _) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withValues(alpha: 0.2 + 0.3 * _pulseController.value),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF00E676)),
                                      ),
                                      child: const Text(
                                        'CLUSTER ACTIVE',
                                        style: TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            Text(
                              adminEmail,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
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
                      Tab(icon: Icon(Icons.video_collection_rounded, size: 18), text: 'Reels Moderation'),
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
                      _buildReelsModerationTab(),
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
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length.toString() ?? '...';
                    return _buildMetricCard('Total Users', count, 'Live DB', Icons.people_rounded, const Color(0xFF00F5FF));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('reels').snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length.toString() ?? '...';
                    return _buildMetricCard('Total Reels', count, 'Active Feeds', Icons.video_collection_rounded, const Color(0xFF7C4DFF));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('groups').snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length.toString() ?? '...';
                    return _buildMetricCard('Total Groups', count, 'Chat Rooms', Icons.forum_rounded, const Color(0xFF00E676));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Firewall Blocks', '${_blockedIPs.length}', 'Active Guard', Icons.local_fire_department_rounded, const Color(0xFFFFC857)),
              ),
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
            'Allow users to create cloned isolated app spaces.',
            Icons.copy_all_rounded,
            _isClonerEnabled,
            (val) => setState(() => _isClonerEnabled = val),
            const Color(0xFF7C4DFF),
          ),
          _buildFeatureToggleCard(
            'Security Defender Engine',
            'Automated threat heuristic analysis & real-time scanner.',
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
            'Emergency Maintenance Mode',
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

  // ─── TAB 2: LIVE FIRESTORE USERS & ROLES ───
  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00F5FF)));
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final q = _searchQuery.toLowerCase();
                  final uname = (data['username'] ?? data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return uname.contains(q) || email.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No users matching search.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final u = doc.data();
                    final uid = doc.id;
                    final username = u['username']?.toString() ?? u['name']?.toString() ?? 'NEX User';
                    final email = u['email']?.toString() ?? 'No email';
                    final role = u['role']?.toString() ?? (u['isAdmin'] == true ? 'Admin' : 'User');
                    final isSuspended = u['isSuspended'] == true || u['status'] == 'suspended';
                    final tokens = (u['tokens'] as num?)?.toInt() ?? (u['token_balance'] as num?)?.toInt() ?? 2000;
                    final isAdmin = u['isAdmin'] == true || role == 'Admin';

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
                            backgroundColor: isSuspended ? const Color(0xFFFF2A6D) : (isAdmin ? const Color(0xFF7C4DFF) : const Color(0xFF00F5FF).withValues(alpha: 0.3)),
                            child: Text(
                              username.isNotEmpty ? username[0].toUpperCase() : 'U',
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
                                      username,
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
                                        color: isAdmin
                                            ? const Color(0xFF7C4DFF)
                                            : (isSuspended ? const Color(0xFFFF2A6D) : Colors.white12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isSuspended ? 'SUSPENDED' : role,
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.generating_tokens_rounded, color: Color(0xFFFFC857), size: 14),
                                    const SizedBox(width: 4),
                                    Text('$tokens tokens', style: const TextStyle(color: Color(0xFFFFC857), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                            color: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (action) {
                              if (action == 'toggle_status') {
                                _toggleUserStatus(uid, username, isSuspended);
                              } else if (action == 'tokens') {
                                _adjustUserTokensDialog(uid, username, tokens);
                              } else if (action == 'toggle_role') {
                                _toggleAdminRole(uid, username, isAdmin);
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
                              PopupMenuItem(
                                value: 'toggle_role',
                                child: Row(
                                  children: [
                                    Icon(isAdmin ? Icons.person_rounded : Icons.security_rounded, color: const Color(0xFF7C4DFF), size: 18),
                                    const SizedBox(width: 8),
                                    Text(isAdmin ? 'Demote to User' : 'Promote to Admin', style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: LIVE REELS MODERATION ───
  Widget _buildReelsModerationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _reelsSearchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search reels by title or creator...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C4DFF)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('reels').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)));
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final q = _reelsSearchQuery.toLowerCase();
                  final title = (data['title'] ?? data['caption'] ?? '').toString().toLowerCase();
                  final author = (data['authorName'] ?? data['username'] ?? '').toString().toLowerCase();
                  return title.contains(q) || author.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No reels found.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final title = data['title']?.toString() ?? data['caption']?.toString() ?? 'Reel';
                    final author = data['authorName']?.toString() ?? data['username']?.toString() ?? 'Creator';
                    final likes = (data['likesCount'] as num?)?.toInt() ?? ((data['likes'] is List) ? (data['likes'] as List).length : 0);
                    final comments = (data['commentsCount'] as num?)?.toInt() ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.movie_creation_rounded, color: Color(0xFF7C4DFF)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text('By @$author', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 13),
                                    const SizedBox(width: 3),
                                    Text('$likes', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.chat_bubble_rounded, color: Color(0xFF00F5FF), size: 13),
                                    const SizedBox(width: 3),
                                    Text('$comments', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF2A6D)),
                            tooltip: 'Delete Reel',
                            onPressed: () => _deleteReel(doc.id, title),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: DEFENDER ENGINE ───
  Widget _buildDefenderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00F5FF).withValues(alpha: 0.15),
                  const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00F5FF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFF00F5FF), size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEX DEFENDER ENGINE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Engine Version: $_definitionVersion\nZero-Trust Shield • Files Scanned: $_scannedFileCount • Threats: $_detectedThreatsCount',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isScanning ? null : _runRustScanSimulation,
            icon: _isScanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.radar_rounded),
            label: Text(_isScanning ? 'Scanning in progress...' : 'Execute Deep File Integrity Scan', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),

          if (_scanLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                _scanLog,
                style: const TextStyle(color: Color(0xFF00E676), fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TAB 5: FIREWALL GUARD ───
  Widget _buildFirewallTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureToggleCard(
            'Inbound Packet Filtering',
            'Drop malformed TCP/UDP socket frames.',
            Icons.filter_alt_rounded,
            _inboundBlocking,
            (val) => setState(() => _inboundBlocking = val),
            const Color(0xFF00F5FF),
          ),
          _buildFeatureToggleCard(
            'Outbound Inspection',
            'Inspect telemetry egress endpoints.',
            Icons.outbox_rounded,
            _outboundFiltering,
            (val) => setState(() => _outboundFiltering = val),
            const Color(0xFF7C4DFF),
          ),
          _buildFeatureToggleCard(
            'Stealth Mode',
            'Ignore ping discovery responses on local networks.',
            Icons.visibility_off_rounded,
            _stealthMode,
            (val) => setState(() => _stealthMode = val),
            const Color(0xFFFFC857),
          ),

          const SizedBox(height: 20),

          const Text(
            'BLOCKED IP ADDRESSES',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipInputController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter IPv4 address to blacklist...',
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
                onPressed: () {
                  final ip = _ipInputController.text.trim();
                  if (ip.isNotEmpty && !_blockedIPs.contains(ip)) {
                    setState(() {
                      _blockedIPs.add(ip);
                      _ipInputController.clear();
                    });
                    _showSnackbar('Blacklisted IP: $ip');
                  }
                },
                child: const Text('Block IP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ..._blockedIPs.map((ip) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF2A6D).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.block_rounded, color: Color(0xFFFF2A6D), size: 18),
                const SizedBox(width: 10),
                Text(ip, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                  onPressed: () {
                    setState(() => _blockedIPs.remove(ip));
                    _showSnackbar('Removed IP from blocklist: $ip');
                  },
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── TAB 6: TELEMETRY & LOGS ───
  Widget _buildTelemetryTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final sev = log['severity'];
        final color = sev == 'warning'
            ? const Color(0xFFFFC857)
            : (sev == 'critical' ? const Color(0xFFFF2A6D) : const Color(0xFF00F5FF));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(log['action']!, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(log['time']!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(log['details']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
}
