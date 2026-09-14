import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class UserLevelingService extends ChangeNotifier {
  UserLevelingService._internal();
  static final UserLevelingService instance = UserLevelingService._internal();

  int _totalXP = 42500;
  int _totalOnlineSeconds = 178400; // ~49.5 hours default base
  int _todayOnlineSeconds = 8400;   // ~2.3 hours today
  int _totalGamingSeconds = 86400;  // ~24.0 hours gaming
  int _totalGamesPlayed = 142;
  int _totalWins = 98;
  int _totalKills = 430;
  int _totalDeaths = 186;

  Timer? _onlineTimer;
  Timer? _gamingTimer;
  bool _isGamingActive = false;
  bool _isInitialized = false;

  int get totalXP => _totalXP;
  int get totalOnlineSeconds => _totalOnlineSeconds;
  int get todayOnlineSeconds => _todayOnlineSeconds;
  int get totalGamingSeconds => _totalGamingSeconds;
  int get totalGamesPlayed => _totalGamesPlayed;
  int get totalWins => _totalWins;
  int get totalKills => _totalKills;
  int get totalDeaths => _totalDeaths;
  int _prestigeLevel = 0;
  final Set<String> _activePerks = {'nanite_overdrive', 'subzero_core', 'kinetic_aegis'};
  String? _equippedMilestoneAvatar;
  bool _autoEquipMilestones = true;
  bool _useCustomUploadedAvatar = false;

  // ── Milestone God-Tier Avatars ───────────────────────────────────────────
  static const List<Map<String, dynamic>> milestoneAvatars = [
    {
      'level': 100,
      'title': 'Cybernetic Overclocked Enforcer',
      'subtitle': 'Level 100 • Transcendent Cyber Warrior',
      'asset': 'assets/images/level_100_avatar.jpg',
      'description': 'Reality frequency shattered. Blazing neon ocular visor and obsidian cybernetic titanium armor.',
      'color': Color(0xFF00E5FF),
      'powerRating': '14.8 THz Overclock',
    },
    {
      'level': 1000,
      'title': 'Singularity Event Horizon Archon',
      'subtitle': 'Level 1,000 • Cosmic Black Hole Sovereign',
      'asset': 'assets/images/level_1000_avatar.jpg',
      'description': 'Supermassive black hole event horizon blazing behind an angelic cybernetic god wielding golden quantum lightning.',
      'color': Color(0xFFFFD700),
      'powerRating': '1.25M TJ Deflector Output',
    },
    {
      'level': 10000,
      'title': 'Hypercube Reality Bender',
      'subtitle': 'Level 10,000 • Spacetime Fractal Entity',
      'asset': 'assets/images/level_10000_avatar.jpg',
      'description': 'Cosmic dimensional rift god unleashing ultraviolet laser beams through sacred 4D hypercube tesseracts.',
      'color': Color(0xFFB44FFF),
      'powerRating': '999.9% Singularity Factor',
    },
    {
      'level': 100000,
      'title': 'Multiverse Cosmic Titan',
      'subtitle': 'Level 100,000 • Primordial Multiverse Sovereign',
      'asset': 'assets/images/level_100000_avatar.jpg',
      'description': 'Primordial celestial god crowned by a hypernova star, cupping shattered spiral galaxies in six cosmic hands.',
      'color': Color(0xFFFF007F),
      'powerRating': 'x150.0 Anomalous Power',
    },
  ];

  int get prestigeLevel => _prestigeLevel;
  Set<String> get activePerks => Set.unmodifiable(_activePerks);
  bool isPerkActive(String id) => _activePerks.contains(id);
  bool get autoEquipMilestones => _autoEquipMilestones;
  bool get useCustomUploadedAvatar => _useCustomUploadedAvatar;

  String? get activeMilestoneAvatarAsset {
    if (_useCustomUploadedAvatar) return null;
    if (_equippedMilestoneAvatar != null) return _equippedMilestoneAvatar;
    if (_autoEquipMilestones) {
      final lvl = currentLevel;
      if (lvl >= 100000) return 'assets/images/level_100000_avatar.jpg';
      if (lvl >= 10000) return 'assets/images/level_10000_avatar.jpg';
      if (lvl >= 1000) return 'assets/images/level_1000_avatar.jpg';
      if (lvl >= 100) return 'assets/images/level_100_avatar.jpg';
    }
    return null;
  }

  bool get isMilestoneAvatarActive => activeMilestoneAvatarAsset != null;

  Map<String, dynamic>? get currentMilestoneAvatarData {
    final asset = activeMilestoneAvatarAsset;
    if (asset == null) return null;
    try {
      return milestoneAvatars.firstWhere((m) => m['asset'] == asset);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get unlockedMilestoneAvatars {
    final lvl = currentLevel;
    return milestoneAvatars.where((m) => lvl >= (m['level'] as int) || _prestigeLevel > 0).toList();
  }

  void equipMilestoneAvatar(String assetPath) {
    _equippedMilestoneAvatar = assetPath;
    _useCustomUploadedAvatar = false;
    _saveState();
    unawaited(_syncToFirebase());
    notifyListeners();
  }

  void revertToCustomAvatar() {
    _useCustomUploadedAvatar = true;
    _equippedMilestoneAvatar = null;
    _saveState();
    unawaited(_syncToFirebase());
    notifyListeners();
  }

  void setAutoEquipMilestones(bool autoEquip) {
    _autoEquipMilestones = autoEquip;
    _saveState();
    notifyListeners();
  }

  void togglePerk(String id) {
    if (_activePerks.contains(id)) {
      _activePerks.remove(id);
    } else {
      _activePerks.add(id);
    }
    _saveState();
    notifyListeners();
  }

  bool get canAscendPrestige => currentLevel >= 100 || _totalXP >= 50000;

  bool ascendPrestige() {
    if (!canAscendPrestige) return false;
    final oldLevel = currentLevel;
    _prestigeLevel += 1;
    _totalXP = (currentLevelBaseXP * 0.1).round();
    _checkMilestoneAvatarUnlock(oldLevel, currentLevel);
    _saveState();
    unawaited(_syncToFirebase());
    notifyListeners();
    _levelUpStreamController.add(currentLevel);
    return true;
  }

  void overclockCore() {
    addXP(1500);
  }

  void realityWarp() {
    addXP(10000);
  }

  // ── Unrealistic Sci-Fi RPG Stats ──────────────────────────────────────────
  String get coreClockSpeed {
    final ghz = 4.20 + (currentLevel * 0.16) + (_prestigeLevel * 25.0);
    if (ghz >= 1000.0) {
      return '${(ghz / 1000.0).toStringAsFixed(2)} PHz';
    }
    return '${ghz.toStringAsFixed(2)} THz';
  }

  String get neuralSyncRate {
    final sync = min(99.999, 85.0 + (currentLevel * 0.08) + (_prestigeLevel * 1.5));
    return '${sync.toStringAsFixed(3)}%';
  }

  String get realityDistortion {
    final dist = min(999.9, 14.5 + (currentLevel * 0.22) + (_prestigeLevel * 45.0));
    return '${dist.toStringAsFixed(1)}%';
  }

  String get kineticShielding {
    final tj = (currentLevel * 3200) + (_prestigeLevel * 150000);
    return '${tj.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} TJ';
  }

  String get anomalousPower {
    final ap = 1.0 + (currentLevel * 0.45) + (_prestigeLevel * 15.0);
    return 'x${ap.toStringAsFixed(1)} AP';
  }

  String get quantumCompute {
    final pf = (currentLevel * 128) + (_prestigeLevel * 5000) + 2048;
    if (pf >= 1000000) {
      return '${(pf / 1000000).toStringAsFixed(1)} YottaFLOPS';
    }
    if (pf >= 1000) {
      return '${(pf / 1000).toStringAsFixed(1)} ExaFLOPS';
    }
    return '$pf PetaFLOPS';
  }

  String get realityTierTitle {
    if (_prestigeLevel > 0) {
      return 'PRESTIGE $_prestigeLevel • OMNIPOTENT REALITY ARCHON ⭐';
    }
    final lvl = currentLevel;
    if (lvl >= 9999) return 'TIER Ω • NEXUS REALITY SINGULARITY';
    if (lvl >= 7500) return 'TIER VI • MULTIVERSE COSMOS WEAVER';
    if (lvl >= 5000) return 'TIER V • TRANSCENDENT ENTROPY OVERLORD';
    if (lvl >= 2500) return 'TIER IV • CHRONO-DIMENSIONAL DEITY';
    if (lvl >= 1000) return 'TIER III • QUANTUM VOID ARCHON';
    if (lvl >= 250) return 'TIER II • CYBERNETIC WARLOCK';
    if (lvl >= 50) return 'TIER I • SYNAPTIC VANGUARD';
    return 'TIER 0 • CARBON RECRUIT';
  }

  static const int maxLevel = 9999;

  // Level formula scaling up to max level 9999: XP = 120 * (L - 1)^1.45
  int get currentLevel {
    if (_totalXP <= 0) return 1;
    final lvl = (pow(_totalXP / 120.0, 1.0 / 1.45)).floor() + 1;
    return lvl.clamp(1, maxLevel);
  }

  bool get isMaxLevel => currentLevel >= maxLevel;

  int xpForLevel(int level) {
    if (level <= 1) return 0;
    final capped = level.clamp(1, maxLevel);
    return (120.0 * pow(capped - 1, 1.45)).round();
  }

  int get currentLevelBaseXP => xpForLevel(currentLevel);
  int get nextLevelTargetXP => isMaxLevel ? currentLevelBaseXP : xpForLevel(currentLevel + 1);
  int get xpInCurrentLevel {
    if (isMaxLevel) return 0;
    final diff = _totalXP - currentLevelBaseXP;
    return diff < 0 ? 0 : diff;
  }
  int get xpRequiredForNextLevel {
    if (isMaxLevel) return 1;
    final diff = nextLevelTargetXP - currentLevelBaseXP;
    return diff < 1 ? 1 : diff;
  }

  double get levelProgress {
    if (isMaxLevel) return 1.0;
    if (xpRequiredForNextLevel <= 0) return 0.0;
    final progress = xpInCurrentLevel / xpRequiredForNextLevel;
    if (progress.isNaN || progress.isInfinite) return 0.0;
    return progress.clamp(0.0, 1.0);
  }

  String get rankTitle {
    final lvl = currentLevel;
    if (lvl >= 9999) return 'NEXUS SINGULARITY (MAX LVL 9999)';
    if (lvl >= 9000) return 'ETERNAL COSMOS ARCHITECT ⭐⭐⭐⭐⭐';
    if (lvl >= 7500) return 'INFINITE REALITY WEAVER ⭐⭐⭐⭐';
    if (lvl >= 6000) return 'SUPREME MULTIVERSE GOD ⭐⭐⭐';
    if (lvl >= 4500) return 'DIMENSIONAL DOMINATOR ⭐⭐⭐';
    if (lvl >= 3000) return 'CHRONO-LORD OF TIME ⭐⭐';
    if (lvl >= 2000) return 'STELLAR SOVEREIGN TITAN ⭐';
    if (lvl >= 1000) return 'OMNIPOTENT DEITY ⭐';
    if (lvl >= 750) return 'CELESTIAL OVERLORD';
    if (lvl >= 500) return 'TRANSCENDENT EMPEROR';
    if (lvl >= 350) return 'COSMIC WARLORD';
    if (lvl >= 250) return 'QUANTUM SOVEREIGN';
    if (lvl >= 175) return 'VOID COMMANDER';
    if (lvl >= 100) return 'APEX PHANTOM';
    if (lvl >= 75) return 'IMMORTAL GUARDIAN';
    if (lvl >= 50) return 'TACTICAL WARRIOR';
    if (lvl >= 30) return 'CYBER SPECIALIST';
    if (lvl >= 15) return 'ELITE OPERATIVE';
    if (lvl >= 5) return 'VANGUARD SOLDIER';
    return 'NOVICE RECRUIT';
  }

  Color get rankColor {
    final lvl = currentLevel;
    if (lvl >= 9999) return const Color(0xFFFF00FF); // Holo Magenta
    if (lvl >= 7500) return const Color(0xFFFFD700); // Pure Gold
    if (lvl >= 5000) return const Color(0xFF00FFFF); // Hyper Cyan
    if (lvl >= 3000) return const Color(0xFFFF3366); // Crimson Flare
    if (lvl >= 1000) return const Color(0xFFE040FB); // Neon Violet
    if (lvl >= 500) return const Color(0xFFFF0055);  // Crimson Neon
    if (lvl >= 250) return const Color(0xFFB44FFF);  // Neon Purple
    if (lvl >= 100) return const Color(0xFF00FF88);  // Neon Green
    if (lvl >= 50) return const Color(0xFF00D4FF);   // Cyber Cyan
    if (lvl >= 25) return const Color(0xFFFF9800);   // Amber
    if (lvl >= 10) return const Color(0xFF3B82F6);   // Blue
    return const Color(0xFF94A3B8);                  // Slate
  }

  IconData get rankIcon {
    final lvl = currentLevel;
    if (lvl >= 9999) return Icons.all_inclusive_rounded;
    if (lvl >= 7500) return Icons.auto_awesome_rounded;
    if (lvl >= 5000) return Icons.star_purple500_rounded;
    if (lvl >= 3000) return Icons.whatshot_rounded;
    if (lvl >= 1000) return Icons.stars_rounded;
    if (lvl >= 500) return Icons.local_fire_department_rounded;
    if (lvl >= 250) return Icons.workspace_premium_rounded;
    if (lvl >= 100) return Icons.diamond_rounded;
    if (lvl >= 50) return Icons.military_tech_rounded;
    if (lvl >= 25) return Icons.shield_rounded;
    return Icons.bolt_rounded;
  }

  double get winRate => _totalGamesPlayed == 0 ? 0.0 : (_totalWins / _totalGamesPlayed) * 100.0;
  double get kdRatio => _totalDeaths == 0 ? _totalKills.toDouble() : _totalKills / _totalDeaths;

  String formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedTotalOnlineTime => formatDuration(_totalOnlineSeconds);
  String get formattedTodayOnlineTime => formatDuration(_todayOnlineSeconds);
  String get formattedTotalGamingTime => formatDuration(_totalGamingSeconds);

  Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _totalXP = prefs.getInt('user_leveling_total_xp') ?? 42500;
    _totalOnlineSeconds = prefs.getInt('user_total_online_seconds') ?? 178400;
    _todayOnlineSeconds = prefs.getInt('user_today_online_seconds') ?? 8400;
    _totalGamingSeconds = prefs.getInt('user_total_gaming_seconds') ?? 86400;
    _totalGamesPlayed = prefs.getInt('user_total_games_played') ?? 142;
    _totalWins = prefs.getInt('user_total_wins') ?? 98;
    _totalKills = prefs.getInt('user_total_kills') ?? 430;
    _totalDeaths = prefs.getInt('user_total_deaths') ?? 186;
    _prestigeLevel = prefs.getInt('user_prestige_level') ?? 0;
    _equippedMilestoneAvatar = prefs.getString('user_equipped_milestone_avatar');
    _autoEquipMilestones = prefs.getBool('user_auto_equip_milestones') ?? true;
    _useCustomUploadedAvatar = prefs.getBool('user_use_custom_uploaded_avatar') ?? false;
    final savedPerks = prefs.getStringList('user_active_perks');
    if (savedPerks != null && savedPerks.isNotEmpty) {
      _activePerks.clear();
      _activePerks.addAll(savedPerks);
    }

    _startOnlineTimer();
    _isInitialized = true;
    notifyListeners();
  }

  void _startOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _totalOnlineSeconds += 5;
      _todayOnlineSeconds += 5;
      if (_isGamingActive) {
        _totalGamingSeconds += 5;
      }
      if (_totalOnlineSeconds % 10 == 0) {
        _totalXP += 2;
      }
      _saveState();
      notifyListeners();
    });
  }

  void startGamingSession() {
    _isGamingActive = true;
    notifyListeners();
  }

  void stopGamingSession() {
    _isGamingActive = false;
    notifyListeners();
  }

  final _levelUpStreamController = StreamController<int>.broadcast();
  Stream<int> get onLevelUpStream => _levelUpStreamController.stream;

  final _milestoneAvatarUnlockStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMilestoneAvatarUnlockStream => _milestoneAvatarUnlockStreamController.stream;

  void _checkMilestoneAvatarUnlock(int oldLevel, int newLevel) {
    if (!_autoEquipMilestones) return;
    for (final m in milestoneAvatars) {
      final reqLevel = m['level'] as int;
      if (oldLevel < reqLevel && newLevel >= reqLevel) {
        _equippedMilestoneAvatar = m['asset'] as String;
        _useCustomUploadedAvatar = false;
        _milestoneAvatarUnlockStreamController.add(m);
        break;
      }
    }
  }

  void addXP(int xpGained) {
    if (xpGained <= 0) return;
    final oldLevel = currentLevel;
    _totalXP += xpGained;
    final newLevel = currentLevel;
    if (newLevel > oldLevel) {
      _checkMilestoneAvatarUnlock(oldLevel, newLevel);
      _levelUpStreamController.add(newLevel);
    }
    _saveState();
    unawaited(_syncToFirebase());
    notifyListeners();
  }

  void recordGameResult({
    required int kills,
    required int deaths,
    required bool won,
    int? customXP,
  }) {
    _totalGamesPlayed += 1;
    if (won) _totalWins += 1;
    _totalKills += kills;
    _totalDeaths += deaths;

    final earnedXP = customXP ?? ((won ? 350 : 150) + (kills * 30));
    final oldLevel = currentLevel;
    _totalXP += earnedXP;
    final newLevel = currentLevel;

    if (newLevel > oldLevel) {
      _checkMilestoneAvatarUnlock(oldLevel, newLevel);
      _levelUpStreamController.add(newLevel);
    }
    _saveState();
    unawaited(_syncToFirebase());
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_leveling_total_xp', _totalXP);
    await prefs.setInt('user_total_online_seconds', _totalOnlineSeconds);
    await prefs.setInt('user_today_online_seconds', _todayOnlineSeconds);
    await prefs.setInt('user_total_gaming_seconds', _totalGamingSeconds);
    await prefs.setInt('user_total_games_played', _totalGamesPlayed);
    await prefs.setInt('user_total_wins', _totalWins);
    await prefs.setInt('user_total_kills', _totalKills);
    await prefs.setInt('user_total_deaths', _totalDeaths);
    await prefs.setInt('user_prestige_level', _prestigeLevel);
    await prefs.setStringList('user_active_perks', _activePerks.toList());
    if (_equippedMilestoneAvatar != null) {
      await prefs.setString('user_equipped_milestone_avatar', _equippedMilestoneAvatar!);
    } else {
      await prefs.remove('user_equipped_milestone_avatar');
    }
    await prefs.setBool('user_auto_equip_milestones', _autoEquipMilestones);
    await prefs.setBool('user_use_custom_uploaded_avatar', _useCustomUploadedAvatar);
  }

  Future<void> _syncToFirebase() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user == null) return;
      await FirebaseService.updateUserProfile(uid: user.uid, data: {
        'totalXP': _totalXP,
        'level': currentLevel,
        'prestigeLevel': _prestigeLevel,
        'rank': rankTitle,
        'realityTier': realityTierTitle,
        'coreClockSpeed': coreClockSpeed,
        'totalOnlineSeconds': _totalOnlineSeconds,
        'totalGamingSeconds': _totalGamingSeconds,
        'totalGamesPlayed': _totalGamesPlayed,
        'totalWins': _totalWins,
        'totalKills': _totalKills,
        'totalDeaths': _totalDeaths,
        'kdRatio': kdRatio,
        'winRate': winRate,
        'equippedMilestoneAvatar': _equippedMilestoneAvatar,
        'useCustomUploadedAvatar': _useCustomUploadedAvatar,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    _gamingTimer?.cancel();
    _levelUpStreamController.close();
    _milestoneAvatarUnlockStreamController.close();
    super.dispose();
  }
}
