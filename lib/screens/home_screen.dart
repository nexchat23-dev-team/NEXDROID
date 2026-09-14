import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/game_category.dart';
import '../providers/token_provider.dart' as token_provider;
import '../providers/animation_provider.dart';
import '../widgets/scifi_animations.dart';
import '../widgets/dynamic_morphing_logo_widget.dart';
import '../services/user_leveling_service.dart';
import '../services/game_sound_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

import 'ai_chat_screen.dart';
import 'announcements_screen.dart';
import 'bet_screen.dart';
import 'calls_screen.dart';
import 'conversations_list_screen.dart';
import 'gaming_hub_screen.dart';
import 'group_chat_screen.dart';
import 'marketplace_screen.dart';
import 'my_statuses_screen.dart';
import 'offline_chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'terminal_screen.dart';
import 'user_search_screen.dart';
import 'video_feed_screen.dart';
import 'weather_screen.dart';
import 'compass_screen.dart';
import 'music_player_screen.dart';
import 'qr_scanner_screen.dart';
import 'file_manager_screen.dart';
import 'app_cloner_hub_screen.dart';
import 'game_detail_screen.dart';
import 'cyber_starfighter_3d_game.dart';
import 'arena_action_games_screen.dart';
import 'media_downloader_screen.dart';
import 'auto_tracker_screen.dart';
import 'animation_store_screen.dart';
import 'battery_saver_screen.dart';
import 'rust_security_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const List<Color> _shootingStarColors = [
    Color(0xFFFFFFFF),
    Color(0xFF7D8CFF),
    Color(0xFFFF69B4),
    Color(0xFF00D4FF),
  ];

  static const List<Map<String, dynamic>> _categoryTabs = [
    {'title': 'ALL', 'icon': Icons.apps_rounded},
    {'title': 'COMMUNICATION', 'icon': Icons.chat_bubble_outline_rounded},
    {'title': 'GAMING', 'icon': Icons.sports_esports_outlined},
    {'title': 'AI & MEDIA', 'icon': Icons.auto_awesome_rounded},
    {'title': 'FINANCE', 'icon': Icons.account_balance_wallet_outlined},
    {'title': 'TOOLS & SYSTEM', 'icon': Icons.terminal_rounded},
  ];

  late final AnimationController _animationController;
  Timer? _shootingStarTimer;
  int _shootingStarColorIndex = 0;
  StreamSubscription? _gyroSub;
  double _gyroX = 0;
  double _gyroY = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showWidgetPanel = false;
  int _selectedCategoryTab = 0;
  bool _isGridView = true;

  late final List<_LauncherApp> _launcherApps = [
    _LauncherApp(
      id: 'profile',
      title: 'Profile MAX',
      subtitle: 'Cyber Ascension & Stats',
      category: 'Social',
      iconBuilder: (context) => _buildProfileIcon(),
      routeName: ProfileScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFF00E5FF),
      badgeText: 'LVL',
    ),
    _LauncherApp(
      id: 'nex_chat',
      title: 'NEX Chat',
      subtitle: 'Encrypted Quantum Messaging',
      category: 'Communication',
      iconBuilder: (context) => _buildNexChatIcon(),
      routeName: ConversationsListScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'groups',
      title: 'Clans & Groups',
      subtitle: 'Syndicate Voice & Clan Hub',
      category: 'Social',
      iconBuilder: (context) => _buildGroupsIcon(),
      routeName: GroupChatScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'calls',
      title: 'Voice & Video',
      subtitle: 'Zero-Latency Calling',
      category: 'Communication',
      iconBuilder: (context) => _buildCallsIcon(),
      routeName: CallsScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'statuses',
      title: 'Stories',
      subtitle: 'Live Ephemeral Feeds',
      category: 'Social',
      iconBuilder: (context) => _buildStatusesIcon(),
      routeName: MyStatusesScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFF00E5FF),
    ),
    _LauncherApp(
      id: 'gaming_hub',
      title: 'Gaming Hub',
      subtitle: 'Arena Tournaments & Quests',
      category: 'Games',
      iconBuilder: (context) => _buildGamingHubIcon(),
      routeName: GamingHubScreen.routeName,
      hasDot: false,
      badgeText: 'HOT',
    ),
    _LauncherApp(
      id: 'game_action',
      title: 'Action 60FPS',
      subtitle: 'Plasma Starfighter Arcade',
      category: 'Games',
      iconBuilder: (context) => _buildActionGameIcon(),
      routeName: GamingHubScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFF00FF88),
      badgeText: '60 FPS',
      onTapCustom: (context) {
        GameSoundService().playHoloEngage();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GameDetailScreen(
              category: GameCategory(
                name: 'Action',
                icon: Icons.rocket_launch_rounded,
                color: Color(0xFF00FF88),
                levels: 10,
                badges: ['Plasma Master', 'Speed Demon', 'Galactic Fighter'],
                description: 'Pilot your plasma starfighter in 60 FPS space arcade shooter.',
              ),
            ),
          ),
        );
      },
    ),
    _LauncherApp(
      id: 'game_adventure',
      title: 'Adventure',
      subtitle: 'Cosmic Anomaly Hazards',
      category: 'Games',
      iconBuilder: (context) => _buildAdventureGameIcon(),
      routeName: GamingHubScreen.routeName,
      hasDot: false,
      badgeText: 'EXP',
      onTapCustom: (context) {
        GameSoundService().playHoloEngage();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GameDetailScreen(
              category: GameCategory(
                name: 'Adventure',
                icon: Icons.explore_rounded,
                color: Color(0xFFFF9800),
                levels: 10,
                badges: ['Dungeon Master', 'Star Explorer', 'Legend'],
                description: 'Navigate deep cosmic anomaly zones and dodge space hazards.',
              ),
            ),
          ),
        );
      },
    ),
    _LauncherApp(
      id: 'game_horror',
      title: 'Horror',
      subtitle: 'Shadow Phantoms Survival',
      category: 'Games',
      iconBuilder: (context) => _buildHorrorGameIcon(),
      routeName: GamingHubScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFFFF2255),
      badgeText: 'SURVIVE',
      onTapCustom: (context) {
        GameSoundService().playHoloEngage();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GameDetailScreen(
              category: GameCategory(
                name: 'Horror',
                icon: Icons.gpp_bad_rounded,
                color: Color(0xFFFF2255),
                levels: 10,
                badges: ['Survivor', 'Ghost Buster', 'Fearless'],
                description: 'Outsmart shadow phantoms in pulse-pounding survival challenges.',
              ),
            ),
          ),
        );
      },
    ),
    _LauncherApp(
      id: 'game_fps',
      title: 'Arena FPS',
      subtitle: 'Neon Tank Wars 3D',
      category: 'Games',
      iconBuilder: (context) => _buildFpsGameIcon(),
      routeName: GamingHubScreen.routeName,
      hasDot: false,
      badgeText: '3D FPS',
      onTapCustom: (context) {
        GameSoundService().playHoloEngage();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NeonTankWarsGame()),
        );
      },
    ),
    _LauncherApp(
      id: 'hyper_void_3d',
      title: 'Hyper-Void 3D',
      subtitle: 'True 3D Vector Dogfight',
      category: 'Games',
      iconBuilder: (context) => const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF00E5FF), size: 28),
      routeName: CyberStarfighter3DGame.routeName,
      hasDot: true,
      dotColor: const Color(0xFF00E5FF),
      badgeText: 'TRUE 3D',
      onTapCustom: (context) {
        GameSoundService().playHyperspace();
        Navigator.pushNamed(context, CyberStarfighter3DGame.routeName);
      },
    ),
    _LauncherApp(
      id: 'game_battle_royale',
      title: 'Battle Royale',
      subtitle: '100-Operative Survival Storm',
      category: 'Games',
      iconBuilder: (context) => _buildBattleRoyaleGameIcon(),
      routeName: GamingHubScreen.routeName,
      hasDot: false,
      badgeText: '100P',
      onTapCustom: (context) {
        GameSoundService().playHoloEngage();
        Navigator.pushNamed(context, GamingHubScreen.routeName);
      },
    ),
    _LauncherApp(
      id: 'marketplace',
      title: 'Marketplace',
      subtitle: 'Digital Asset Exchange',
      category: 'Finance',
      iconBuilder: (context) => _buildMarketplaceIcon(),
      routeName: MarketplaceScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'reels_feed',
      title: 'Reels & Videos',
      subtitle: 'Curated Viral Streams',
      category: 'Media',
      iconBuilder: (context) => _buildReelsIcon(),
      routeName: VideoFeedScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'ai_chat',
      title: 'NEX AI',
      subtitle: 'Quantum Intelligence Copilot',
      category: 'System',
      iconBuilder: (context) => _buildNexAiIcon(),
      routeName: AIChatScreen.routeName,
      hasDot: false,
      badgeText: 'AI',
    ),
    _LauncherApp(
      id: 'predictions',
      title: 'Predictions',
      subtitle: 'Match Wagering & Forecasts',
      category: 'Finance',
      iconBuilder: (context) => _buildPredictionsIcon(),
      routeName: BettingScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFFFFD700),
    ),
    _LauncherApp(
      id: 'security_hub',
      title: 'Security Hub',
      subtitle: 'Memory Safety & Anti-Spy',
      category: 'Security',
      iconBuilder: (context) => _buildSecurityHubIcon(),
      routeName: RustSecurityHubScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'file_manager',
      title: 'File Manager',
      subtitle: 'Vault & Encrypted Storage',
      category: 'Tools',
      iconBuilder: (context) => _buildFileManagerIcon(),
      routeName: FileManagerScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'music_player',
      title: 'Music Player',
      subtitle: 'Hi-Fi Audio Synthesizer',
      category: 'Media',
      iconBuilder: (context) => _buildMusicPlayerIcon(),
      routeName: MusicPlayerScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'terminal',
      title: 'Terminal',
      subtitle: 'Raw Cyber CLI Shell',
      category: 'Dev',
      iconBuilder: (context) => _buildTerminalIcon(),
      routeName: TerminalScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'app_cloner',
      title: 'App Sandbox',
      subtitle: 'Isolated App Instances',
      category: 'System',
      iconBuilder: (context) => _buildAppClonerIcon(),
      routeName: AppClonerHubScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'auto_tracker',
      title: 'Auto Target',
      subtitle: 'Neural Motion Detection',
      category: 'AI / Vision',
      iconBuilder: (context) => _buildAutoTrackerIcon(),
      routeName: AutoTrackerScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFF00FFCC),
      badgeText: 'AI',
    ),
    _LauncherApp(
      id: 'downloader',
      title: 'Downloader',
      subtitle: 'High-Speed 4K Media Grabber',
      category: 'Tools',
      iconBuilder: (context) => _buildDownloaderIcon(),
      routeName: MediaDownloaderScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFFFF3366),
      badgeText: '4K',
    ),
    _LauncherApp(
      id: 'scifi_store',
      title: 'FX & Customs',
      subtitle: 'Sci-Fi Holo Backgrounds',
      category: 'Themes',
      iconBuilder: (context) => _buildSciFiCustomsIcon(),
      routeName: AnimationStoreScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFF00FF41),
      badgeText: 'PRO',
    ),
    _LauncherApp(
      id: 'battery_saver',
      title: 'Battery Saver',
      subtitle: 'Deep Thermal Throttling',
      category: 'System',
      iconBuilder: (context) => _buildBatterySaverIcon(),
      routeName: BatterySaverScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'offline_mesh',
      title: 'Offline Mesh',
      subtitle: 'Decentralized P2P Comms',
      category: 'Communication',
      iconBuilder: (context) => _buildOfflineIcon(),
      routeName: OfflineChatScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'qr_scanner',
      title: 'QR Scanner',
      subtitle: 'Rapid Visual Decoder',
      category: 'Tools',
      iconBuilder: (context) => _buildQrScannerIcon(),
      routeName: QrScannerScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'ai_weather',
      title: 'Weather',
      subtitle: 'Atmospheric Micro-Radar',
      category: 'Utilities',
      iconBuilder: (context) => _buildWeatherIcon(),
      routeName: WeatherScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'compass',
      title: 'Compass',
      subtitle: 'Magnetic Azimuth Sensor',
      category: 'Utilities',
      iconBuilder: (context) => _buildCompassIcon(),
      routeName: CompassScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'announcements',
      title: 'News & Feed',
      subtitle: 'Official Network Updates',
      category: 'Social',
      iconBuilder: (context) => _buildAnnouncementsIcon(),
      routeName: AnnouncementsScreen.routeName,
      hasDot: true,
      dotColor: const Color(0xFF3897F0),
    ),
    _LauncherApp(
      id: 'user_search',
      title: 'User Search',
      subtitle: 'Network Operative Registry',
      category: 'Tools',
      iconBuilder: (context) => _buildSearchIcon(),
      routeName: UserSearchScreen.routeName,
      hasDot: false,
    ),
    _LauncherApp(
      id: 'settings',
      title: 'Settings',
      subtitle: 'System Preferences & Themes',
      category: 'System',
      iconBuilder: (context) => _buildSettingsIcon(),
      routeName: SettingsScreen.routeName,
      hasDot: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat(reverse: true);
    _shootingStarTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() {
        _shootingStarColorIndex = (_shootingStarColorIndex + 1) % _shootingStarColors.length;
      });
    });
    _startGyro();
  }

  DateTime _lastGyroUpdate = DateTime.now();

  void _startGyro() {
    _gyroSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.difference(_lastGyroUpdate).inMilliseconds < 120) return;

      final newX = (event.x / 10).clamp(-1.0, 1.0);
      final newY = (event.y / 10).clamp(-1.0, 1.0);

      if ((newX - _gyroX).abs() > 0.04 || (newY - _gyroY).abs() > 0.04) {
        _lastGyroUpdate = now;
        setState(() {
          _gyroX = newX;
          _gyroY = newY;
        });
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _animationController.dispose();
    _shootingStarTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDailyCheckIn() async {
    final tokenProvider = Provider.of<token_provider.TokenProvider>(context, listen: false);
    final result = await tokenProvider.checkInToday();
    if (!mounted) return;
    GameSoundService().playCoin();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: const Color(0xFF00E5FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_LauncherApp> _getFilteredApps() {
    List<_LauncherApp> pool = _launcherApps;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      return pool.where((app) {
        return app.title.toLowerCase().contains(query) ||
            app.subtitle.toLowerCase().contains(query) ||
            app.category.toLowerCase().contains(query);
      }).toList();
    }

    switch (_selectedCategoryTab) {
      case 1: // COMMUNICATION
        return pool.where((a) => a.category == 'Communication' || (a.category == 'Social' && a.id != 'profile')).toList();
      case 2: // GAMING
        return pool.where((a) => a.category == 'Games').toList();
      case 3: // AI & MEDIA
        return pool.where((a) => a.category == 'Media' || a.category == 'AI / Vision' || a.id == 'ai_chat').toList();
      case 4: // FINANCE
        return pool.where((a) => a.category == 'Finance' || a.category == 'Themes').toList();
      case 5: // TOOLS & SYSTEM
        return pool.where((a) => a.category == 'Tools' || a.category == 'Security' || a.category == 'Dev' || a.category == 'System' || a.category == 'Utilities').toList();
      case 0: // ALL
      default:
        return pool;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokenProvider = Provider.of<token_provider.TokenProvider>(context);
    final animationProvider = Provider.of<AnimationProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final userLeveling = UserLevelingService.instance;
    final user = authService.user ?? FirebaseService.auth.currentUser;

    final equippedHomeId = animationProvider.equippedHomeAnimation ?? 'matrix_rain';
    final displayedApps = _getFilteredApps();

    // Pinned Quick Access Apps shown when viewing ALL without search
    final quickAccessIds = {'profile', 'nex_chat', 'gaming_hub', 'ai_chat', 'predictions'};
    final quickAccessApps = _launcherApps.where((a) => quickAccessIds.contains(a.id)).toList();

    return AnimatedBuilder(
      animation: userLeveling,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF02040A),
          body: Stack(
            children: [
              // ── 1. Live Animated Sci-Fi Background ──────────────────────────────
              Positioned.fill(
                child: equippedHomeId == 'classic_aurora'
                    ? AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _HomeBackgroundPainter(
                              isDark: isDark,
                              animationValue: _animationController.value,
                              shootingStarColor: _shootingStarColors[_shootingStarColorIndex],
                            ),
                          );
                        },
                      )
                    : buildSciFiAnimation(equippedHomeId, gyroX: _gyroX, gyroY: _gyroY),
              ),

              // ── 2. Cinematic Scrim Overlay ──────────────────────────────────────
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.25),
                ),
              ),

              // ── 3. Scrollable Dashboard Body ────────────────────────────────────
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── A. Header & Search Command Bar ────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Operative Command Bar
                            _buildTopStatusBar(user, userLeveling, tokenProvider),

                            const SizedBox(height: 12),

                            // Greeting & System Status
                            _buildOperativeGreetingHeader(user, userLeveling),

                            const SizedBox(height: 10),

                            // Cyber Search Bar
                            _buildLauncherSearchBar(),

                            // Expandable Daily Bonus & Streak HUD
                            if (_showWidgetPanel) ...[
                              const SizedBox(height: 12),
                              _buildStreakAndStatsWidget(tokenProvider),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── B. Category Segment Pills & Layout Mode ───────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: _buildCategoryTabsAndLayoutBar(displayedApps.length),
                      ),
                    ),

                    // ── C. Quick Access Row (When in ALL view with no search) ──────
                    if (_searchQuery.isEmpty && _selectedCategoryTab == 0) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: _buildSectionHeader('QUICK ACCESS PINNED'),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 114,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            physics: const BouncingScrollPhysics(),
                            children: quickAccessApps.map((app) => _buildQuickAccessCard(app)).toList(),
                          ),
                        ),
                      ),

                      // ── D. Games Showcase Carousel ──────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('GAMES & COMBAT ARENA'),
                              InkWell(
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.pushNamed(context, GamingHubScreen.routeName);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'VIEW HUB',
                                        style: TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00E5FF), size: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 174,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildGenreGameCard(
                                title: 'Hyper-Void 3D',
                                subtitle: 'True 3D Vector Space Combat',
                                tag: 'TRUE 3D',
                                tagColor: const Color(0xFF00E5FF),
                                icon: Icons.flight_takeoff_rounded,
                                levels: 'BOSS FIGHT',
                                gradient: const [Color(0xFF001F3F), Color(0xFF000C1A)],
                                borderColor: const Color(0xFF00E5FF),
                                onTap: () {
                                  GameSoundService().playHyperspace();
                                  Navigator.pushNamed(context, CyberStarfighter3DGame.routeName);
                                },
                              ),
                              _buildGenreGameCard(
                                title: 'Action 60FPS',
                                subtitle: 'Plasma Starfighter Arcade',
                                tag: '60 FPS',
                                tagColor: const Color(0xFF00FF88),
                                icon: Icons.rocket_launch_rounded,
                                levels: '10 LEVELS',
                                gradient: const [Color(0xFF004422), Color(0xFF0D2214)],
                                borderColor: const Color(0xFF00FF88),
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const GameDetailScreen(
                                        category: GameCategory(
                                          name: 'Action',
                                          icon: Icons.rocket_launch_rounded,
                                          color: Color(0xFF00FF88),
                                          levels: 10,
                                          badges: ['Plasma Master', 'Speed Demon', 'Galactic Fighter'],
                                          description: 'Pilot your plasma starfighter in 60 FPS space arcade shooter.',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildGenreGameCard(
                                title: 'Adventure',
                                subtitle: 'Cosmic Anomaly Hazards',
                                tag: 'EXPLORE',
                                tagColor: const Color(0xFFFF9800),
                                icon: Icons.explore_rounded,
                                levels: '10 LEVELS',
                                gradient: const [Color(0xFF4A2600), Color(0xFF1E1000)],
                                borderColor: const Color(0xFFFF9800),
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const GameDetailScreen(
                                        category: GameCategory(
                                          name: 'Adventure',
                                          icon: Icons.explore_rounded,
                                          color: Color(0xFFFF9800),
                                          levels: 10,
                                          badges: ['Dungeon Master', 'Star Explorer', 'Legend'],
                                          description: 'Navigate deep cosmic anomaly zones and dodge space hazards.',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildGenreGameCard(
                                title: 'Horror Survival',
                                subtitle: 'Shadow Phantoms Hunt',
                                tag: 'SURVIVAL',
                                tagColor: const Color(0xFFFF2255),
                                icon: Icons.gpp_bad_rounded,
                                levels: '10 LEVELS',
                                gradient: const [Color(0xFF4A0012), Color(0xFF1E0007)],
                                borderColor: const Color(0xFFFF2255),
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const GameDetailScreen(
                                        category: GameCategory(
                                          name: 'Horror',
                                          icon: Icons.gpp_bad_rounded,
                                          color: Color(0xFFFF2255),
                                          levels: 10,
                                          badges: ['Survivor', 'Ghost Buster', 'Fearless'],
                                          description: 'Outsmart shadow phantoms in pulse-pounding survival challenges.',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildGenreGameCard(
                                title: 'Arena FPS',
                                subtitle: 'Neon Tank Wars 3D',
                                tag: '3D FPS',
                                tagColor: const Color(0xFFB44FFF),
                                icon: Icons.gps_fixed_rounded,
                                levels: 'ARENA',
                                gradient: const [Color(0xFF2E0854), Color(0xFF150428)],
                                borderColor: const Color(0xFFB44FFF),
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NeonTankWarsGame()),
                                  );
                                },
                              ),
                              _buildGenreGameCard(
                                title: 'Battle Royale',
                                subtitle: '100-Operative Survival Storm',
                                tag: '100 PLAYERS',
                                tagColor: const Color(0xFFFF5252),
                                icon: Icons.shield_moon_rounded,
                                levels: 'RANKED',
                                gradient: const [Color(0xFF4A0E0E), Color(0xFF1E0505)],
                                borderColor: const Color(0xFFFF5252),
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.pushNamed(context, GamingHubScreen.routeName);
                                },
                              ),
                              _buildGenreGameCard(
                                title: 'Neon Racing',
                                subtitle: 'Nitro Rush Street Circuit',
                                tag: 'NITRO',
                                tagColor: const Color(0xFFFFD600),
                                icon: Icons.speed_rounded,
                                levels: '8 TRACKS',
                                gradient: const [Color(0xFF3E3400), Color(0xFF191500)],
                                borderColor: const Color(0xFFFFD600),
                                onTap: () {
                                  GameSoundService().playHoloEngage();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const GameDetailScreen(
                                        category: GameCategory(
                                          name: 'Racing',
                                          icon: Icons.speed_rounded,
                                          color: Color(0xFFFFD600),
                                          levels: 8,
                                          badges: ['Nitro Rush', 'Track Master', 'Street King'],
                                          description: 'High-speed neon driving with sharp corners, boosts, and rival pressure.',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── E. Main Applications Display (Grid or Command Cards) ──────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader(
                              _searchQuery.isNotEmpty
                                  ? 'SEARCH RESULTS (${displayedApps.length})'
                                  : '${_categoryTabs[_selectedCategoryTab]['title']} MODULES (${displayedApps.length})',
                            ),
                            Text(
                              _isGridView ? '4-COL GRID' : 'COMMAND CARDS',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (displayedApps.isEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_rounded, color: Colors.white38, size: 48),
                              const SizedBox(height: 10),
                              Text(
                                'No modules found for "$_searchQuery"',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Text('CLEAR SEARCH', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_isGridView)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.76,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildDashboardAppTile(displayedApps[i]),
                            childCount: displayedApps.length,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildDashboardCardTile(displayedApps[i]),
                            childCount: displayedApps.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── 4. Anchored Floating Frosted Cyber Navigation Dock ───────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildFrostedLauncherDock(isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Top Operative Command Status Bar ─────────────────────────────────────────
  Widget _buildTopStatusBar(dynamic user, UserLevelingService leveling, token_provider.TokenProvider tokenProvider) {
    return Row(
      children: [
        // App Logo & OS Brand
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: DynamicMorphingLogoWidget(
              size: 34,
              showText: true,
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Daily Bonus Streak & Token Balance Chip
        InkWell(
          onTap: () {
            setState(() => _showWidgetPanel = !_showWidgetPanel);
            HapticFeedback.selectionClick();
            GameSoundService().playTick();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9800), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${tokenProvider.streakCount}d',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5),
                ),
                const SizedBox(width: 6),
                Container(width: 1, height: 12, color: Colors.white24),
                const SizedBox(width: 6),
                const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 3),
                Text(
                  '${tokenProvider.balance}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Operative Profile & Live Milestone Avatar Chip
        InkWell(
          onTap: () {
            GameSoundService().playHoloEngage();
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, ProfileScreen.routeName);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1026).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: leveling.rankColor.withValues(alpha: 0.6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: leveling.rankColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: leveling.rankColor, width: 1.5),
                  ),
                  child: ClipOval(
                    child: leveling.activeMilestoneAvatarAsset != null
                        ? Image.asset(leveling.activeMilestoneAvatarAsset!, fit: BoxFit.cover)
                        : (user?.photoURL != null && user!.photoURL!.isNotEmpty
                            ? Image.network(user.photoURL!, fit: BoxFit.cover)
                            : Container(
                                color: leveling.rankColor,
                                child: const Icon(Icons.person_rounded, color: Colors.black, size: 16),
                              )),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'LVL ${leveling.currentLevel}',
                  style: TextStyle(
                    color: leveling.rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Quick Settings Button
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: IconButton(
                padding: const EdgeInsets.all(7),
                constraints: const BoxConstraints(),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  GameSoundService().playTick();
                  Navigator.pushNamed(context, SettingsScreen.routeName);
                },
                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 19),
                tooltip: 'Settings & Backgrounds',
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Operative Greeting Header ──────────────────────────────────────────────
  Widget _buildOperativeGreetingHeader(dynamic user, UserLevelingService leveling) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final name = AuthService.resolveDisplayName(
      name: user?.displayName,
      username: null,
      email: user?.email,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FF66),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF00FF66), blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        leveling.realityTierTitle,
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              leveling.anomalousPower,
              style: const TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cyber Search Bar ───────────────────────────────────────────────────────
  Widget _buildLauncherSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Search modules, games, clans, tools...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 12.5),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                )
              else
                const Icon(Icons.tune_rounded, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category Filter Tabs & Layout Mode Switcher ──────────────────────────────
  Widget _buildCategoryTabsAndLayoutBar(int totalCount) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categoryTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tab = _categoryTabs[index];
                    final isSelected = _selectedCategoryTab == index && _searchQuery.isEmpty;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        GameSoundService().playTick();
                        setState(() {
                          _selectedCategoryTab = index;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF7C3AED)],
                                )
                              : null,
                          color: isSelected ? null : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab['icon'] as IconData,
                              size: 14,
                              color: isSelected ? Colors.black : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tab['title'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 10.5,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Layout Mode Toggle Button (Grid vs Command Cards)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                GameSoundService().playTick();
                setState(() => _isGridView = !_isGridView);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Icon(
                  _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                  size: 16,
                  color: const Color(0xFF00E5FF),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Expandable Daily Streak & Stats Panel ──────────────────────────────────
  Widget _buildStreakAndStatsWidget(token_provider.TokenProvider tokenProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF161934), Color(0xFF0F1225)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9800), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tokenProvider.streakCount} DAY STREAK ACTIVE',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tokenProvider.hasCheckedInToday ? 'Daily bounty claimed! Keep it burning tomorrow.' : 'Claim today’s bonus tokens to maintain streak.',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: tokenProvider.hasCheckedInToday ? null : _handleDailyCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                child: Text(
                  tokenProvider.hasCheckedInToday ? 'CLAIMED' : 'CHECK IN',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00E5FF),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
      ),
    );
  }

  // ── Quick Access Card (horizontal scroll) ─────────────────────────────────
  Widget _buildQuickAccessCard(_LauncherApp app) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (app.onTapCustom != null) {
          app.onTapCustom!(context);
        } else {
          Navigator.pushNamed(context, app.routeName);
        }
      },
      child: Container(
        width: 86,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(width: 44, height: 44, child: app.iconBuilder(context)),
                if (app.badgeText != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Text(app.badgeText!, style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                app.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Genre Game Card (Action · Adventure · Horror · Arena · Racing) ─────────
  Widget _buildGenreGameCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    required IconData icon,
    required String levels,
    required List<Color> gradient,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Icon(icon, color: borderColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tagColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: tagColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  levels,
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor.withValues(alpha: 0.8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PLAY',
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.play_arrow_rounded, color: borderColor, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Modern 4-Column Squircle App Tile (Grid Mode) ───────────────────────────
  Widget _buildDashboardAppTile(_LauncherApp app) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (app.onTapCustom != null) {
          app.onTapCustom!(context);
        } else {
          Navigator.pushNamed(context, app.routeName);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(width: 58, height: 58, child: app.iconBuilder(context)),
              if (app.hasDot)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: app.dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: app.dotColor.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              if (app.badgeText != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3366),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.black, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3366).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(app.badgeText!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            app.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              shadows: [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detailed Executive Command Card (Card Mode) ──────────────────────────────
  Widget _buildDashboardCardTile(_LauncherApp app) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (app.onTapCustom != null) {
          app.onTapCustom!(context);
        } else {
          Navigator.pushNamed(context, app.routeName);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10172A), Color(0xFF090D18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(width: 46, height: 46, child: app.iconBuilder(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        app.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (app.badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3366),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            app.badgeText!,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${app.category.toUpperCase()} • ${app.subtitle}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (app.hasDot)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: app.dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: app.dotColor.withValues(alpha: 0.8), blurRadius: 6)],
                ),
              ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Anchored Floating Frosted Navigation Dock ────────────────────────────────
  Widget _buildFrostedLauncherDock(bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? bottomPadding + 6 : 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF090D1E).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. NEX Chat with Badge
                _buildDockIcon(
                  builder: () => _buildNexChatIcon(),
                  label: 'Chat',
                  onTap: () => Navigator.pushNamed(context, ConversationsListScreen.routeName),
                  badge: '99+',
                ),

                // 2. Gaming Hub
                _buildDockIcon(
                  builder: () => _buildGamingHubIcon(),
                  label: 'Games',
                  onTap: () => Navigator.pushNamed(context, GamingHubScreen.routeName),
                ),

                // 3. NEX AI
                _buildDockIcon(
                  builder: () => _buildNexAiIcon(),
                  label: 'AI Brain',
                  onTap: () => Navigator.pushNamed(context, AIChatScreen.routeName),
                ),

                // 4. Marketplace
                _buildDockIcon(
                  builder: () => _buildMarketplaceIcon(),
                  label: 'Store',
                  onTap: () => Navigator.pushNamed(context, MarketplaceScreen.routeName),
                ),

                // 5. Settings
                _buildDockIcon(
                  builder: () => _buildSettingsIcon(),
                  label: 'Settings',
                  onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockIcon({
    required Widget Function() builder,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        GameSoundService().playTick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(width: 46, height: 46, child: builder()),
              if (badge != null)
                Positioned(
                  top: -3,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2244),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2244).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CUSTOM SQUIRCLE APP ICON RENDERERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSquircleContainer({
    required List<Color> gradientColors,
    required Widget child,
    Border? border,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        boxShadow: shadows ?? [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildProfileIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF00E5FF)],
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNexChatIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00A884), Color(0xFF005C4B)],
      child: const Center(
        child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildGroupsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      child: const Center(
        child: Icon(Icons.groups_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildCallsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
      child: const Center(
        child: Icon(Icons.call_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildStatusesIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFFF2A85), Color(0xFFFF7A00)],
      child: const Center(
        child: Icon(Icons.donut_large_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildGamingHubIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFFF3366), Color(0xFF7928CA)],
      child: const Center(
        child: Icon(Icons.sports_esports_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildMarketplaceIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      child: const Center(
        child: Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildReelsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
      child: const Center(
        child: Icon(Icons.slow_motion_video_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNexAiIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF030B1E), Color(0xFF0A1E4A)],
      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 1.5),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              ),
            ),
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF6366F1), Color(0xFF4338CA)],
      child: const Center(
        child: Icon(Icons.insights_rounded, color: Color(0xFFFFD700), size: 28),
      ),
    );
  }

  Widget _buildSecurityHubIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF0284C7), Color(0xFF0369A1)],
      child: const Center(
        child: Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 28),
      ),
    );
  }

  Widget _buildFileManagerIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF475569), Color(0xFF334155)],
      child: const Center(
        child: Icon(Icons.folder_shared_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildMusicPlayerIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildTerminalIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF0F172A), Color(0xFF020617)],
      border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.5)),
      child: const Center(
        child: Icon(Icons.terminal_rounded, color: Color(0xFF00FF41), size: 26),
      ),
    );
  }

  Widget _buildAppClonerIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF64748B), Color(0xFF475569)],
      child: const Center(
        child: Icon(Icons.layers_rounded, color: Color(0xFF38BDF8), size: 28),
      ),
    );
  }

  Widget _buildDownloaderIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFFF0844), Color(0xFFFFB199)],
      child: const Center(
        child: Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSciFiCustomsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00FF41), Color(0xFF008F11)],
      child: const Center(
        child: Icon(Icons.auto_awesome_motion_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildBatterySaverIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00E676), Color(0xFF00B0FF)],
      child: const Center(
        child: Icon(Icons.battery_charging_full_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildOfflineIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF651FFF), Color(0xFF3D5AFE)],
      child: const Center(
        child: Icon(Icons.wifi_off_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildQrScannerIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00E5FF), Color(0xFF0091EA)],
      child: const Center(
        child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildWeatherIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
      child: const Center(
        child: Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFD54F), size: 28),
      ),
    );
  }

  Widget _buildCompassIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF37474F), Color(0xFF263238)],
      child: const Center(
        child: Icon(Icons.explore_rounded, color: Color(0xFF00E5FF), size: 28),
      ),
    );
  }

  Widget _buildAnnouncementsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
      child: const Center(
        child: Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8), size: 28),
      ),
    );
  }

  Widget _buildSearchIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF2979FF), Color(0xFF1565C0)],
      child: const Center(
        child: Icon(Icons.person_search_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSettingsIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF64748B), Color(0xFF334155)],
      child: const Center(
        child: Icon(Icons.settings_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildAutoTrackerIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00FFCC), Color(0xFF006655)],
      border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.6), width: 1.2),
      child: const Center(
        child: Icon(Icons.track_changes_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildActionGameIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFF00FF88), Color(0xFF006633)],
      border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.6), width: 1.2),
      child: const Center(
        child: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildAdventureGameIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFFF9800), Color(0xFFB26A00)],
      border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.6), width: 1.2),
      child: const Center(
        child: Icon(Icons.explore_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildHorrorGameIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFFF2255), Color(0xFF880022)],
      border: Border.all(color: const Color(0xFFFF2255).withValues(alpha: 0.6), width: 1.2),
      child: const Center(
        child: Icon(Icons.gpp_bad_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFpsGameIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFB44FFF), Color(0xFF5B16B8)],
      border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.6), width: 1.2),
      child: const Center(
        child: Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBattleRoyaleGameIcon() {
    return _buildSquircleContainer(
      gradientColors: const [Color(0xFFFF5252), Color(0xFFD50000)],
      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.6), width: 1.2),
      child: const Center(
        child: Icon(Icons.shield_moon_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Launcher App Model ──────────────────────────────────────────────────────
class _LauncherApp {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final Widget Function(BuildContext) iconBuilder;
  final String routeName;
  final bool hasDot;
  final Color dotColor;
  final String? badgeText;
  final void Function(BuildContext context)? onTapCustom;

  const _LauncherApp({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.iconBuilder,
    required this.routeName,
    this.hasDot = false,
    this.dotColor = const Color(0xFF00E5FF),
    this.badgeText,
    this.onTapCustom,
  });
}

// ── Classic Background Painter Fallback ─────────────────────────────────────
class _HomeBackgroundPainter extends CustomPainter {
  const _HomeBackgroundPainter({required this.isDark, required this.animationValue, required this.shootingStarColor});

  final bool isDark;
  final double animationValue;
  final Color shootingStarColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF050816), Color(0xFF0B1330)]
            : const [Color(0xFFF7F9FF), Color(0xFFE7EDFF)],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final auroraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.35 + (animationValue * 0.06), -0.25 + (animationValue * 0.04)),
        radius: 1.25,
        colors: isDark
            ? const [Color(0xFF4D6DFF), Color(0xFF1E2A5E), Color(0x00000000)]
            : const [Color(0xFF8BC9FF), Color(0xFFE7DFFF), Color(0x00000000)],
      ).createShader(rect);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.18), size.width * 0.34, auroraPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.75 - (animationValue * 0.04), 0.12 + (animationValue * 0.03)),
        radius: 0.85,
        colors: isDark
            ? const [Color(0xFFB14EFF), Color(0x00000000)]
            : const [Color(0xFFFFC8E7), Color(0x00000000)],
      ).createShader(rect);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.12), size.width * 0.26, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HomeBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.animationValue != animationValue || oldDelegate.shootingStarColor != shootingStarColor;
  }
}
