import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_category.dart';
import '../screens/game_detail_screen.dart';
import '../screens/gyro_games_screen.dart';
import '../screens/arena_fps_games_screen.dart';
import '../screens/arena_action_games_screen.dart';
import '../screens/cyber_starfighter_3d_game.dart';
import '../screens/matchmaking_lobby_screen.dart' hide kNeonGreen, kNeonBlue, kNeonPurple;
import '../screens/battle_royale_game_screen.dart' hide kNeonGreen, kNeonBlue, kNeonPurple;
import '../screens/gaming_profile_screen.dart' hide kNeonGreen, kNeonBlue, kNeonPurple;
import '../screens/leaderboard_screen.dart' hide kNeonGreen, kNeonBlue, kNeonPurple;
import '../screens/new_games_screen.dart';
import '../services/clan_service.dart';
import '../services/session_service.dart';
import '../services/squad_service.dart';
import '../services/backend_service.dart';
import '../services/user_leveling_service.dart';
import '../utils/constants.dart';
import '../widgets/interactive_cosmic_background.dart';
import '../providers/animation_provider.dart';
import '../providers/token_provider.dart';
import '../widgets/scifi_animations.dart';
import '../widgets/token_purchase_sheet.dart';

class GamingHubScreen extends StatefulWidget {
  static const routeName = '/gaming-hub';
  const GamingHubScreen({super.key});

  @override
  State<GamingHubScreen> createState() => _GamingHubScreenState();
}

class _GamingHubScreenState extends State<GamingHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Online feature token gate ──
  static const int kOnlineUnlockCost = 10000;
  bool _onlineFeaturesUnlocked = false;
  final ClanService _clanService = ClanService();
  final SquadService _squadService = SquadService();
  final SessionService _sessionService = SessionService();
  Set<String> _purchasedGames = {};

  String? get _currentUserId => SupabaseService.client.auth.currentUser?.id;

  final List<GameCategory> _gameCategories = const [
    GameCategory(
      name: 'Hyper-Void 3D',
      icon: Icons.flight_takeoff_rounded,
      color: kNeonGreen,
      levels: 10,
      badges: ['StarFox Legend', 'Dreadnought Slayer', 'Void Master'],
      description: 'True 3D Vector Space Dogfight with 360° rolls, bogeys, and Dreadnought boss fights.',
    ),
    GameCategory(
      name: 'Action',
      icon: Icons.rocket_launch_rounded,
      color: kNeonGreen,
      levels: 10,
      badges: ['Plasma Master', 'Speed Demon', 'Galactic Fighter'],
      description: 'Pilot your plasma starfighter in 60 FPS space arcade shooter.',
    ),
    GameCategory(
      name: 'Thriller',
      icon: Icons.radar_rounded,
      color: kNeonPurple,
      levels: 10,
      badges: ['Sharp Eye', 'Quick Reflexes', 'Night Hunter'],
      description: 'Test your reaction speed against high-speed hostile targets.',
    ),
    GameCategory(
      name: 'Puzzle',
      icon: Icons.extension_rounded,
      color: kNeonBlue,
      levels: 10,
      badges: ['Cyber Hack', 'Brainiac', 'Pattern Wizard'],
      description: 'Decode cyber hacking node patterns in sequence.',
    ),
    GameCategory(
      name: 'Adventure',
      icon: Icons.explore_rounded,
      color: Colors.orangeAccent,
      levels: 10,
      badges: ['Dungeon Master', 'Star Explorer', 'Legend'],
      description: 'Navigate deep cosmic anomaly zones and dodge space hazards.',
    ),
    GameCategory(
      name: 'Horror',
      icon: Icons.gpp_bad_rounded,
      color: Colors.redAccent,
      levels: 10,
      badges: ['Survivor', 'Ghost Buster', 'Fearless'],
      description: 'Outsmart shadow phantoms in pulse-pounding survival challenges.',
    ),
    GameCategory(
      name: 'Racing',
      icon: Icons.speed_rounded,
      color: Color(0xFFFFD600),
      levels: 8,
      badges: ['Nitro Rush', 'Track Master', 'Street King'],
      description: 'High-speed neon driving with sharp corners, boosts, and rival pressure.',
    ),
    GameCategory(
      name: 'Strategy',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFF8BC34A),
      levels: 12,
      badges: ['Tactical Mind', 'Empire Builder', 'Commander'],
      description: 'Outplay rivals with planning, resource control, and battle timing.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    UserLevelingService.instance.startGamingSession();
    _tabController = TabController(length: 10, vsync: this);
    _loadPurchasedGames();
    _loadOnlineUnlockStatus();
  }

  Future<void> _loadOnlineUnlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Also check TokenProvider balance for users who already had 10k+ tokens
    if (mounted) {
      final alreadySaved = prefs.getBool('online_features_unlocked') ?? false;
      setState(() => _onlineFeaturesUnlocked = alreadySaved);
    }
  }

  Future<void> _saveOnlineUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('online_features_unlocked', true);
  }

  /// Directly attempt unlock without showing dialog (for when balance is sufficient)
  Future<void> _performDirectUnlock(BuildContext context, TokenProvider tokenProvider) async {
    if (_onlineFeaturesUnlocked) return;
    if (tokenProvider.balance >= kOnlineUnlockCost) {
      tokenProvider.deductTokens(kOnlineUnlockCost);
      await _saveOnlineUnlock();
      if (mounted) {
        setState(() => _onlineFeaturesUnlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ONLINE MULTIPLAYER UNLOCKED! Welcome to the arena.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            backgroundColor: Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (context.mounted) {
        TokenPurchaseSheet.show(context, customAmount: kOnlineUnlockCost);
      }
    }
  }

  /// Shows the 10,000 token gate dialog for online features.
  /// Returns true if user already unlocked or just paid.
  Future<bool> _checkOnlineAccess(BuildContext context) async {
    if (_onlineFeaturesUnlocked) return true;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    bool unlocked = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF0A0F1E),
            border: Border.all(color: kNeonGreen.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [BoxShadow(color: kNeonGreen.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 4)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kNeonGreen.withValues(alpha: 0.12),
                  border: Border.all(color: kNeonGreen.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.public_rounded, color: kNeonGreen, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                'ONLINE MULTIPLAYER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.4),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlock real-time online multiplayer features: Matchmaking Lobby, Live Challenges, Battle Royale, and more!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 22),
              // Price row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ONE-TIME UNLOCK', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 0.8)),
                        SizedBox(height: 4),
                        Text('Lifetime Access', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Row(children: [
                      const Icon(Icons.toll_rounded, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${kOnlineUnlockCost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} tokens',
                        style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white38, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Your balance: ${tokenProvider.balance} tokens',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ]),
              const SizedBox(height: 22),
              // Buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () async {
                      if (tokenProvider.balance >= kOnlineUnlockCost) {
                        tokenProvider.deductTokens(kOnlineUnlockCost);
                        await _saveOnlineUnlock();
                        unlocked = true;
                        if (ctx.mounted) Navigator.pop(ctx);
                        // Apply state AFTER dialog is fully popped to ensure rebuild
                        await Future.delayed(Duration.zero);
                        if (mounted) setState(() => _onlineFeaturesUnlocked = true);
                      } else {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          TokenPurchaseSheet.show(context, customAmount: kOnlineUnlockCost);
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tokenProvider.balance >= kOnlineUnlockCost ? kNeonGreen : const Color(0xFF229ED9),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      tokenProvider.balance >= kOnlineUnlockCost ? 'UNLOCK NOW' : 'BUY TOKENS TO UNLOCK',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return unlocked || _onlineFeaturesUnlocked;
  }

  // Subscription: key = 'sub_<gameName>', value = ISO8601 expiry date
  Future<void> _loadPurchasedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final active = <String>{};
    for (final cat in _gameCategories) {
      final key = 'sub_${cat.name}';
      final expStr = prefs.getString(key);
      if (expStr != null) {
        try {
          final exp = DateTime.parse(expStr);
          if (exp.isAfter(now)) active.add(cat.name);
        } catch (_) {}
      }
    }
    // Also check gyro game subscriptions
    for (final gid in ['gyro_ball','space_tilt','gravity_flip','nex_3d_shooter','orbit_drift']) {
      final key = 'sub_$gid';
      final expStr = prefs.getString(key);
      if (expStr != null) {
        try {
          final exp = DateTime.parse(expStr);
          if (exp.isAfter(now)) active.add(gid);
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _purchasedGames = active);
  }

  /// Base price per month in tokens for each game
  int _getGameMonthlyPrice(String categoryName) {
    switch (categoryName) {
      case 'Action':    return 1500;
      case 'Thriller':  return 1000;
      case 'Puzzle':    return 800;
      case 'Adventure': return 2000;
      case 'Horror':    return 1200;
      case 'Racing':    return 1700;
      case 'Strategy':  return 1800;
      default:          return 1000;
    }
  }

  /// Returns tokens cost for N months (longer = bigger discount)
  int _subscriptionCost(int baseMonthly, int months) {
    double disc = 1.0;
    if (months >= 12) {
      disc = 0.55;
    } else if (months >= 6) {
      disc = 0.65;
    } else if (months >= 3) {
      disc = 0.78;
    } else if (months >= 2) {
      disc = 0.90;
    }
    return (baseMonthly * months * disc).round();
  }

  final Map<String, DateTime> _expiryDates = {};

  Future<void> _saveSubscription(String gameName, int months) async {
    final prefs = await SharedPreferences.getInstance();
    final exp = DateTime.now().add(Duration(days: months * 30));
    await prefs.setString('sub_$gameName', exp.toIso8601String());
    if (mounted) {
      setState(() {
        _purchasedGames.add(gameName);
        _expiryDates[gameName] = exp;
      });
    }
  }

  @override
  void dispose() {
    UserLevelingService.instance.stopGamingSession();
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchGamers() async {
    try {
      final response = await SupabaseService.client.from('users').select().limit(50).order('updated_at', ascending: false).execute();
      final data = response as List<dynamic>;
      return data.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Unable to load gamers: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ap = Provider.of<AnimationProvider>(context);
    final equippedGamingId = ap.equippedGamingHubAnimation;

    Widget content = Scaffold(
      backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.sports_esports_rounded, color: kNeonGreen, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GAMING HUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.4)),
                      Text('CYBER ARCADE NETWORK', style: TextStyle(color: kNeonGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, color: kNeonGreen, size: 18),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildAppBarAction(Icons.shopping_cart_outlined, const Color(0xFF00B8F4), () {
                TokenPurchaseSheet.show(context);
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildAppBarAction(Icons.emoji_events_outlined, kNeonPurple, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
              }),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: kNeonGreen,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: kNeonGreen,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      tabs: [
                        const Tab(text: 'ARENA'),
                        const Tab(text: 'GYRO'),
                        const Tab(text: 'GAMERS'),
                        const Tab(text: 'CLANS'),
                        const Tab(text: 'SQUADS'),
                        const Tab(text: 'LIVE'),
                        // ── NEW TABS ──
                        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('LOBBY'),
                          const SizedBox(width: 4),
                          if (!_onlineFeaturesUnlocked)
                            const Icon(Icons.lock_rounded, size: 10, color: Colors.orangeAccent),
                        ])),
                        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('BATTLE ROYALE'),
                          const SizedBox(width: 4),
                          if (!_onlineFeaturesUnlocked)
                            const Icon(Icons.lock_rounded, size: 10, color: Colors.orangeAccent),
                        ])),
                        const Tab(text: 'PROFILE'),
                        const Tab(text: 'VAULT'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildArenaTab(),
            _buildGyroTab(),
            _buildGamersTab(),
            _buildClansTab(),
            _buildSquadsTab(),
            _buildLiveTab(),
            // ── NEW TABS ──
            _buildLobbyTab(),
            _buildBattleRoyaleTab(),
            _buildProfileTab(),
            _buildVaultTab(),
          ],
        ),
      );

    if (equippedGamingId != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: buildSciFiAnimation(equippedGamingId),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),
          content,
        ],
      );
    }

    return InteractiveCosmicBackground(
      child: content,
    );
  }

  Widget _buildAppBarAction(IconData icon, Color color, VoidCallback? onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap),
        ),
      ),
    );
  }

  Widget _buildArenaTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arena Cyber Arcade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Real-time 60 FPS interactive online games. Pick a game, earn high scores, and dominate the leaderboards!', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                   _buildInfoBadge('Active Games', '18 Online', kNeonGreen),
                  _buildInfoBadge('Network Status', '60 FPS', kNeonPurple),
                  _buildInfoBadge('Arena Rank', 'Global #12', kNeonBlue),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Online unlock banner
        if (!_onlineFeaturesUnlocked)
          GestureDetector(
            onTap: () => _checkOnlineAccess(context),
            child: _buildGlassCard(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kNeonGreen.withValues(alpha: 0.12), Colors.transparent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.public_rounded, color: kNeonGreen, size: 26),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UNLOCK ONLINE MULTIPLAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                        SizedBox(height: 3),
                        Text('Matchmaking Lobby • Battle Royale • Live Challenges', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kNeonGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kNeonGreen.withValues(alpha: 0.4)),
                    ),
                    child: const Column(
                      children: [
                        Text('10,000', style: TextStyle(color: kNeonGreen, fontWeight: FontWeight.w900, fontSize: 13)),
                        Text('TOKENS', style: TextStyle(color: kNeonGreen, fontSize: 9, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        if (!_onlineFeaturesUnlocked) const SizedBox(height: 14),
        const Text('FEATURED CYBER GAMES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ..._gameCategories.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGameCard(cat),
        )),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  NEW TAB BUILDERS
  // ─────────────────────────────────────────────────────

  Widget _buildLobbyTab() {
    if (!_onlineFeaturesUnlocked) {
      return _buildLockedFeatureScreen(
        icon: Icons.people_alt_rounded,
        title: 'MATCHMAKING LOBBY',
        description: 'Find and challenge other NEXDROID players in real-time. Create game rooms, send challenges, and play together live!',
        features: const ['Real-time online presence', 'Create & join game lobbies', 'Send live challenges', 'In-lobby chat before matches'],
      );
    }
    return const MatchmakingLobbyScreen();
  }

  Widget _buildBattleRoyaleTab() {
    if (!_onlineFeaturesUnlocked) {
      return _buildLockedFeatureScreen(
        icon: Icons.gps_fixed_rounded,
        title: 'BATTLE ROYALE',
        description: '100-player Battle Royale! Shrinking zone, loot drops, AI bots, weapons and survival action.',
        features: const ['Shrinking zone of death', '20 AI bot enemies', 'Loot & weapon system', 'Real-time kill feed & ranking'],
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gps_fixed_rounded, color: kNeonGreen, size: 64),
          const SizedBox(height: 18),
          const Text('BATTLE ROYALE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('Shrinking zone • 20 AI bots • Loot drops', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BattleRoyaleGameScreen())),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('ENTER THE ZONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3366),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
            child: const Text('VIEW LEADERBOARD →', style: TextStyle(color: kNeonBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return const GamingProfileScreen();
  }

  Widget _buildVaultTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.lock_open_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 10),
                  Text('NEXDROID VAULT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                ]),
                const SizedBox(height: 8),
                const Text('5 exclusive premium games. Dungeon Crawler, Stealth Sniper, Tower Defense, Street Racer & Cyber Heist.', style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewGamesScreen())),
          icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
          label: const Text('OPEN THE VAULT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('VAULT GAMES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        _buildVaultGameTile(Icons.castle_rounded, 'Dungeon Crawler RPG', 'Top-down dungeon, sword & magic combat, 5 rooms, epic boss fight', const Color(0xFFB44FFF)),
        _buildVaultGameTile(Icons.gps_not_fixed_rounded, 'Stealth Sniper', 'Scope & eliminate targets with wind drift, breath hold & guard alerts', const Color(0xFF00D4FF)),
        _buildVaultGameTile(Icons.shield_rounded, 'Tower Defense X', 'Place laser/cryo/missile towers to survive 20 waves of enemies', const Color(0xFF00FF88)),
        _buildVaultGameTile(Icons.speed_rounded, 'Street Racer', 'Top-down traffic dodger with nitro boost, crash physics & 5 tracks', const Color(0xFFFF8C00)),
        _buildVaultGameTile(Icons.security_rounded, 'Cyber Heist', 'Stealth grid game — hack safes, avoid guards & cameras, escape!', const Color(0xFFFF3366)),
      ],
    );
  }

  Widget _buildVaultGameTile(IconData icon, String name, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _buildGlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          subtitle: Text(description, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
          trailing: FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewGamesScreen())),
            style: FilledButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.2),
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  /// Full-screen locked feature placeholder with unlock CTA
  Widget _buildLockedFeatureScreen({
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: Colors.white38, size: 52),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
            const SizedBox(height: 22),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded, color: kNeonGreen, size: 16),
                const SizedBox(width: 8),
                Text(f, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            )),
            const SizedBox(height: 28),
            Consumer<TokenProvider>(
              builder: (ctx, tp, _) => FilledButton.icon(
                onPressed: () async {
                  if (tp.balance >= kOnlineUnlockCost) {
                    // User has enough — unlock directly without extra dialog
                    await _performDirectUnlock(context, tp);
                  } else {
                    // Show the full dialog
                    await _checkOnlineAccess(context);
                  }
                },
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('UNLOCK FOR 10,000 TOKENS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                style: FilledButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGyroTab() {
    return const GyroGameLauncher();
  }

  Widget _getGameWidget(GameCategory cat) {
    switch (cat.name) {
      case 'Hyper-Void 3D':
        return const CyberStarfighter3DGame();
      case 'Warzone Blitz':
        return const WarzoneBlitzGame();
      case 'Cyber Hunt':
        return const CyberHuntGame();
      case 'Zombie Siege':
        return const ZombieSiegeGame();
      case 'Neon Tank Wars':
        return const NeonTankWarsGame();
      case 'Blade Runner X':
        return const BladeRunnerXGame();
      case 'Astro Dogfight':
        return const AstroDogfightGame();
      case 'Pixel Brawl':
        return const PixelBrawlGame();
      case 'Drift Kings':
        return const DriftKingsGame();
      default:
        return GameDetailScreen(category: cat);
    }
  }

  Widget _buildGameCard(GameCategory cat) {
    final bool isSubscribed = _purchasedGames.contains(cat.name);
    final int baseMonthly = _getGameMonthlyPrice(cat.name);
    final expiry = _expiryDates[cat.name];
    final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: cat.color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(cat.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        if (isSubscribed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: kNeonGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: const Text('ACTIVE', style: TextStyle(color: kNeonGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(cat.description, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      if (isSubscribed)
                        Text('⏳ $daysLeft days remaining', style: const TextStyle(color: Colors.white54, fontSize: 11))
                      else
                        Row(children: [
                          const Icon(Icons.toll_rounded, color: Colors.orangeAccent, size: 13),
                          const SizedBox(width: 4),
                          Text('From $baseMonthly tokens/month', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    if (isSubscribed) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => _getGameWidget(cat)));
                    } else {
                      _showSubscriptionDialog(cat.name, baseMonthly, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => _getGameWidget(cat)));
                      });
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isSubscribed ? cat.color : Colors.white12,
                    foregroundColor: isSubscribed ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!isSubscribed) const Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
                    if (!isSubscribed) const SizedBox(width: 4),
                    Text(isSubscribed ? 'PLAY' : 'SUBSCRIBE', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDialog(String gameName, int baseMonthly, VoidCallback onSuccess) {
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    int selectedMonths = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          final cost = _subscriptionCost(baseMonthly, selectedMonths);
          final canAfford = tokenProvider.balance >= cost;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF0F172A),
                border: Border.all(color: kNeonPurple.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    const Icon(Icons.workspace_premium_rounded, color: kNeonPurple, size: 26),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Subscribe to $gameName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                    GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.white38, size: 20)),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Choose your subscription plan', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 18),

                  // Plan grid 1-12 months
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final c = _subscriptionCost(baseMonthly, m);
                      final isSelected = selectedMonths == m;
                      Color planColor = Colors.white12;
                      if (m >= 12) {
                        planColor = Colors.amber.withValues(alpha: 0.2);
                      } else if (m >= 6) {
                        planColor = kNeonGreen.withValues(alpha: 0.15);
                      } else if (m >= 3) {
                        planColor = kNeonBlue.withValues(alpha: 0.15);
                      }

                      return GestureDetector(
                        onTap: () => setS(() => selectedMonths = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected ? kNeonPurple.withValues(alpha: 0.35) : planColor,
                            border: Border.all(color: isSelected ? kNeonPurple : Colors.white.withValues(alpha: 0.12), width: isSelected ? 1.5 : 1),
                          ),
                          child: Column(children: [
                            Text('$m ${m == 1 ? 'mo' : 'mos'}', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.w900, fontSize: 12)),
                            Text('$c T', style: TextStyle(color: isSelected ? kNeonGreen : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                            if (m >= 12) const Text('BEST', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                            if (m >= 6 && m < 12) const Text('SAVE 35%', style: TextStyle(color: kNeonGreen, fontSize: 8, fontWeight: FontWeight.bold)),
                            if (m >= 3 && m < 6) const Text('SAVE 22%', style: TextStyle(color: kNeonBlue, fontSize: 8, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  // Summary
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Cost', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Row(children: [
                      const Icon(Icons.toll_rounded, color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 4),
                      Text('$cost tokens', style: TextStyle(color: canAfford ? kNeonGreen : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 15)),
                    ]),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Your Balance', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Text('${tokenProvider.balance} tokens', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Access Duration', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Text('$selectedMonths month${selectedMonths > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                  const SizedBox(height: 20),

                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (canAfford) {
                          tokenProvider.deductTokens(cost);
                          await _saveSubscription(gameName, selectedMonths);
                          if (!ctx.mounted || !mounted) return;
                          Navigator.pop(ctx);
                          _showSystemSnackBar(context, '$gameName — $selectedMonths month sub activated!');
                          onSuccess();
                        } else {
                          Navigator.pop(ctx);
                          TokenPurchaseSheet.show(context, customAmount: cost);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: canAfford ? kNeonPurple : const Color(0xFF229ED9),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        canAfford ? 'SUBSCRIBE — $cost TOKENS' : 'BUY TOKENS TO SUBSCRIBE',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGamersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchGamers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load gamers', style: TextStyle(color: Colors.redAccent)));
        }

        final gamers = snapshot.data ?? [];
        if (gamers.isEmpty) {
          return const Center(child: Text('No active gamers were found. Invite friends and watch them appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: gamers.length,
          itemBuilder: (context, index) {
            final gamer = gamers[index];
            final name = (gamer['username'] as String?) ?? (gamer['name'] as String?) ?? 'Player';
            final status = (gamer['status'] as String?) ?? 'online';
            final badge = (gamer['level'] != null) ? 'Lv ${gamer['level']}' : 'New';

            return _buildGlassCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: kNeonBlue.withValues(alpha: 0.16),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                subtitle: Text('$badge • ${status.toUpperCase()}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: kNeonGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Text('VIEW', style: TextStyle(color: kNeonGreen, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClansTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _clanService.getClans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load clans', style: TextStyle(color: Colors.redAccent)));
        }

        final clans = snapshot.data ?? [];
        if (clans.isEmpty) {
          return const Center(child: Text('No clans have been formed yet. Start one to lead your own squad.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: clans.length,
          itemBuilder: (context, index) {
            final clan = clans[index];
            final clanName = (clan['name'] as String?) ?? 'Unnamed Clan';
            final members = List<String>.from(clan['members'] ?? []);
            final level = clan['level']?.toString() ?? 'N/A';
            final wins = clan['experience']?.toString() ?? '0';
            final clanId = clan['id']?.toString() ?? '';
            final isMember = members.contains(_currentUserId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGlassCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: kNeonGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: kNeonGreen.withValues(alpha: 0.3))),
                    child: Center(child: Text(level, style: const TextStyle(color: kNeonGreen, fontSize: 18, fontWeight: FontWeight.w900))),
                  ),
                  title: Text(clanName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Text('${members.length} members · $wins XP', style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold))),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: isMember ? Colors.white12 : kNeonGreen, foregroundColor: isMember ? Colors.white : Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: isMember ? null : () => _handleClanJoin(clanId, clanName),
                    child: Text(isMember ? 'MEMBER' : 'JOIN', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSquadsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _squadService.getSquads(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load squads', style: TextStyle(color: Colors.redAccent)));
        }

        final squads = snapshot.data ?? [];
        if (squads.isEmpty) {
          return const Center(child: Text('No squads found yet. Assemble a crew and take the arena by storm.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: squads.length,
          itemBuilder: (context, index) {
            final squad = squads[index];
            final squadName = (squad['name'] as String?) ?? 'Unnamed Squad';
            final game = (squad['game'] as String?) ?? 'Unknown';
            final members = List<String>.from(squad['members'] ?? []);
            final maxMembers = squad['maxMembers'] as int? ?? 4;
            final isFull = members.length >= maxMembers;
            final squadId = squad['id']?.toString() ?? '';
            final isMember = members.contains(_currentUserId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGlassCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kNeonBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.hub_rounded, color: kNeonBlue, size: 24)),
                  title: Text(squadName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                    _buildSquadTag(game.toUpperCase(), kNeonBlue),
                    const SizedBox(width: 8),
                    _buildSquadTag('${members.length}/$maxMembers', isFull ? Colors.redAccent : kNeonGreen),
                  ])),
                  trailing: isMember
                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)), child: const Text('MEMBER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))
                      : IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, color: kNeonBlue, size: 18), onPressed: isFull ? null : () => _handleSquadJoin(squadId, squadName)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionService.getSessions(publicOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load live sessions', style: TextStyle(color: Colors.redAccent)));
        }

        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return const Center(child: Text('No public sessions are live right now. Start one and see it appear instantly.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final title = (session['title'] as String?) ?? 'Live session';
            final game = (session['game'] as String?) ?? 'Unknown';
            final status = (session['status'] as String?) ?? 'scheduled';
            final participants = List<String>.from(session['participants'] ?? []);
            final sessionId = session['id']?.toString() ?? '';
            final startTime = _parseSessionTime(session['startTime']);
            final timeLabel = startTime != null ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}' : 'TBA';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: status == 'active' ? kNeonGreen.withValues(alpha: 0.18) : kNeonPurple.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)), child: Text(status.toUpperCase(), style: TextStyle(color: status == 'active' ? kNeonGreen : kNeonPurple, fontWeight: FontWeight.w900, fontSize: 11))),
                      ]),
                      const SizedBox(height: 10),
                      Text(game, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _buildSmallTag(timeLabel, kNeonBlue),
                        const SizedBox(width: 8),
                        _buildSmallTag('${participants.length} players', kNeonGreen),
                      ]),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: () => _joinSession(sessionId, title), style: OutlinedButton.styleFrom(foregroundColor: kNeonGreen, side: BorderSide(color: kNeonGreen.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Join session')),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10172E).withValues(alpha: 0.74),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String title, String subtitle, Color color) {
    return Container(width: 110, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 10)), const SizedBox(height: 8), Text(subtitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))]));
  }

  Widget _buildSmallTag(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)));
  }

  Widget _buildSquadTag(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)));
  }

  DateTime? _parseSessionTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _joinSession(String sessionId, String sessionTitle) async {
    try {
      await _sessionService.joinSession(sessionId);
      if (!mounted) return;
      _showSystemSnackBar(context, 'Joined session: $sessionTitle');
    } catch (e) {
      if (!mounted) return;
      _showSystemSnackBar(context, 'Failed to join session: ${e.toString()}');
    }
  }

  Future<void> _handleClanJoin(String clanId, String clanName) async {
    try {
      await _clanService.requestJoinClan(clanId);
      if (!mounted) return;
      _showSystemSnackBar(context, 'CLAN_REQUEST_SENT: ${clanName.toUpperCase()}');
    } catch (e) {
      if (!mounted) return;
      _showSystemSnackBar(context, 'CLAN_JOIN_FAILED: ${e.toString()}');
    }
  }

  Future<void> _handleSquadJoin(String squadId, String squadName) async {
    try {
      await _squadService.joinSquad(squadId);
      if (!mounted) return;
      _showSystemSnackBar(context, 'JOINED_SQUAD: ${squadName.toUpperCase()}');
    } catch (e) {
      if (!mounted) return;
      _showSystemSnackBar(context, 'SQUAD_JOIN_FAILED: ${e.toString()}');
    }
  }

  void _showSystemSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        backgroundColor: const Color(0xFF0D1E36),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
