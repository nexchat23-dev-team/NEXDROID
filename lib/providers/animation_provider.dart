import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_provider.dart';

enum AnimationScreen {
  home,
  splash,
  profile,
  gamingHub,
  store,
  chat,
  chatList,
  settings,
  global,
}

class SciFiAnimationModel {
  const SciFiAnimationModel({
    required this.id,
    required this.name,
    required this.movie,
    required this.price,
    required this.description,
    required this.glowColor,
    required this.accentColor,
    required this.routeName,
  });

  final String id;
  final String name;
  final String movie;
  final int price;
  final String description;
  final Color glowColor;
  final Color accentColor;
  final String routeName;
}

class AnimationProvider extends ChangeNotifier {
  Set<String> _ownedAnimations = {};
  
  // Maps screenKey ('home', 'splash', 'profile', 'gaming_hub', 'store', 'chat', 'chat_list', 'settings') to animationId
  Map<String, String> _equippedScreens = {};
  bool _initialized = false;

  AnimationProvider() {
    _loadState();
  }

  Set<String> get ownedAnimations => Set.unmodifiable(_ownedAnimations);
  Map<String, String> get equippedScreens => Map.unmodifiable(_equippedScreens);
  bool get isInitialized => _initialized;

  String? get equippedHomeAnimation => _equippedScreens['home'] ?? 'matrix_rain';
  String? get equippedSplashAnimation => _equippedScreens['splash'];
  String? get equippedProfileAnimation => _equippedScreens['profile'];
  String? get equippedGamingHubAnimation => _equippedScreens['gaming_hub'];
  String? get equippedStoreAnimation => _equippedScreens['store'];
  String? get equippedChatAnimation => _equippedScreens['chat'];
  String? get equippedChatListAnimation => _equippedScreens['chat_list'];
  String? get equippedSettingsAnimation => _equippedScreens['settings'];

  bool isOwned(String id) => id == 'matrix_rain' || _ownedAnimations.contains(id);

  bool isEquippedHome(String id) => (_equippedScreens['home'] ?? 'matrix_rain') == id;
  bool isEquippedSplash(String id) => _equippedScreens['splash'] == id;
  bool isEquippedProfile(String id) => _equippedScreens['profile'] == id;
  bool isEquippedGamingHub(String id) => _equippedScreens['gaming_hub'] == id;
  bool isEquippedStore(String id) => _equippedScreens['store'] == id;
  bool isEquippedChat(String id) => _equippedScreens['chat'] == id;
  bool isEquippedChatList(String id) => _equippedScreens['chat_list'] == id;
  bool isEquippedSettings(String id) => _equippedScreens['settings'] == id;

  bool isEquippedOn(String id, String screenKey) => _equippedScreens[screenKey] == id;

  List<String> getScreensEquipped(String animationId) {
    final list = <String>[];
    _equippedScreens.forEach((k, v) {
      if (v == animationId) list.add(k);
    });
    return list;
  }

  static const List<SciFiAnimationModel> catalog = [
    SciFiAnimationModel(
      id: 'terminator_endoskeleton',
      name: 'Terminator Endoskeleton',
      movie: 'The Terminator',
      price: 15000,
      description: 'Chrome skeleton with piercing red eyes. Scan lines sweep across the battlefield as the T-800 rises from the darkness.',
      glowColor: Color(0xFFFF2200),
      accentColor: Color(0xFFFF6633),
      routeName: '/scifi/terminator',
    ),
    SciFiAnimationModel(
      id: 'iron_man_arc',
      name: 'Iron Man Arc Reactor',
      movie: 'Iron Man',
      price: 20000,
      description: 'Pulsating arc reactor assembles the Mark VII armor piece by piece in a brilliant light show of power and engineering.',
      glowColor: Color(0xFF00CFFF),
      accentColor: Color(0xFFFFD700),
      routeName: '/scifi/iron-man',
    ),
    SciFiAnimationModel(
      id: 'matrix_rain',
      name: 'Matrix Digital Rain',
      movie: 'The Matrix',
      price: 0, // Free default
      description: 'Cascading green katakana and binary code streams from the simulated reality of the machine world.',
      glowColor: Color(0xFF00FF41),
      accentColor: Color(0xFF008F11),
      routeName: '/scifi/matrix',
    ),
    SciFiAnimationModel(
      id: 'lightsaber_duel',
      name: 'Lightsaber Duel',
      movie: 'Star Wars',
      price: 20000,
      description: 'Crimson meets blue in an epic clash. Plasma blades ignite the darkness with electric arcs and raw Force energy.',
      glowColor: Color(0xFF4444FF),
      accentColor: Color(0xFFFF2244),
      routeName: '/scifi/lightsaber',
    ),
    SciFiAnimationModel(
      id: 'xenomorph_shadow',
      name: 'Xenomorph Rising',
      movie: 'Alien',
      price: 18000,
      description: 'Acid drips from the darkness as the xenomorph silhouette emerges from the bio-mechanical hive structure.',
      glowColor: Color(0xFF44FF44),
      accentColor: Color(0xFF001100),
      routeName: '/scifi/xenomorph',
    ),
    SciFiAnimationModel(
      id: 'predator_cloak',
      name: 'Predator Cloak & HUD',
      movie: 'Predator',
      price: 22000,
      description: 'Thermal vision overlay with active optical camouflage distortion and the iconic three-dot red plasma targeting laser.',
      glowColor: Color(0xFFFF0000),
      accentColor: Color(0xFF00FF88),
      routeName: '/scifi/predator',
    ),
    SciFiAnimationModel(
      id: 'optimus_transform',
      name: 'Optimus Matrix of Leadership',
      movie: 'Transformers',
      price: 25000,
      description: 'Cybertronian energy pulses through transforming mechanical plates as the Matrix of Leadership radiates pure blue energon.',
      glowColor: Color(0xFF0077FF),
      accentColor: Color(0xFFFF3300),
      routeName: '/scifi/optimus',
    ),
    SciFiAnimationModel(
      id: 'tron_grid',
      name: 'TRON Grid Lightcycle',
      movie: 'TRON: Legacy',
      price: 15000,
      description: 'Glowing neon blue light ribbons trail across an infinite dark grid floor in the digital frontier.',
      glowColor: Color(0xFF00FFFF),
      accentColor: Color(0xFF0066FF),
      routeName: '/scifi/tron',
    ),
    SciFiAnimationModel(
      id: 'dune_sandworm',
      name: 'Shai-Hulud Sandworm',
      movie: 'Dune',
      price: 28000,
      description: 'Arrakis desert sands part as the colossal Great Maker erupts under an electric spice storm and twin moons.',
      glowColor: Color(0xFFFF9900),
      accentColor: Color(0xFF33CCFF),
      routeName: '/scifi/sandworm',
    ),
    SciFiAnimationModel(
      id: 'interstellar_wormhole',
      name: 'Gargantua Accretion Disk',
      movie: 'Interstellar',
      price: 30000,
      description: 'Gravitational lensing bends starlight around the event horizon of a supermassive black hole with relativistic glowing jets.',
      glowColor: Color(0xFFFFCC00),
      accentColor: Color(0xFF000000),
      routeName: '/scifi/wormhole',
    ),
    SciFiAnimationModel(
      id: 'avatar_banshee',
      name: 'Pandora Bioluminescent Flight',
      movie: 'Avatar',
      price: 20000,
      description: 'Ride an Ikran through the floating Hallelujah Mountains as neon spore trails illuminate the alien night.',
      glowColor: Color(0xFF00FFCC),
      accentColor: Color(0xFFB44FFF),
      routeName: '/scifi/avatar',
    ),
    SciFiAnimationModel(
      id: 'robocop_hud',
      name: 'OmniCorp OCP Tactical HUD',
      movie: 'RoboCop',
      price: 15000,
      description: 'Green phosphorus CRT interface tracks targets with directive readouts, threat matrices, and weapon telemetry.',
      glowColor: Color(0xFF00FF44),
      accentColor: Color(0xFF003311),
      routeName: '/scifi/robocop',
    ),
    SciFiAnimationModel(
      id: 'mandalorian_jetpack',
      name: 'Beskar Spear & Jetpack Blast',
      movie: 'The Mandalorian',
      price: 22000,
      description: 'Whistling birds launch with blue plasma flame trails as the pure Beskar armor deflects incoming blaster fire.',
      glowColor: Color(0xFFFFAA00),
      accentColor: Color(0xFF66AAFF),
      routeName: '/scifi/mandalorian',
    ),
    SciFiAnimationModel(
      id: 'groot_growth',
      name: 'Groot Cosmic Spores',
      movie: 'Guardians of the Galaxy',
      price: 18000,
      description: 'Bioluminescent alien flora blooms in zero gravity as gentle glowing spore particles float through the cosmos.',
      glowColor: Color(0xFF88FF00),
      accentColor: Color(0xFFCCFF00),
      routeName: '/scifi/groot',
    ),
    SciFiAnimationModel(
      id: 'exosuit_powerup',
      name: 'Valkyrie Exosuit Overcharge',
      movie: 'Edge of Tomorrow',
      price: 25000,
      description: 'Hydraulic actuators hiss as orange overcharge arcs ignite across titanium combat limbs in an infinite combat loop.',
      glowColor: Color(0xFFFF6600),
      accentColor: Color(0xFFFFCC00),
      routeName: '/scifi/exosuit',
    ),
    SciFiAnimationModel(
      id: 'fury_road_fire',
      name: 'Doof Wagon Fire Storm',
      movie: 'Mad Max: Fury Road',
      price: 20000,
      description: 'Twin flame exhausts blast toward the blood-orange sky as a massive sandstorm wall closes in on the convoy.',
      glowColor: Color(0xFFFF2200),
      accentColor: Color(0xFFFF8800),
      routeName: '/scifi/mad-max',
    ),
    SciFiAnimationModel(
      id: 'multipass_holo',
      name: 'Korben Dallas MultiPass',
      movie: 'The Fifth Element',
      price: 12000,
      description: '3D holographic identity card rotates in mid-air with flashing authentication glyphs and biometric scans.',
      glowColor: Color(0xFFFF00CC),
      accentColor: Color(0xFF00FFFF),
      routeName: '/scifi/multipass',
    ),
    SciFiAnimationModel(
      id: 'blade_runner_spinner',
      name: 'Neo-Tokyo Spinner Flight',
      movie: 'Blade Runner 2049',
      price: 25000,
      description: 'Flying police spinner cruises between gargantuan holographic geisha billboards in perpetual acidic rain.',
      glowColor: Color(0xFFFF0055),
      accentColor: Color(0xFF00EEFF),
      routeName: '/scifi/blade-runner',
    ),
    SciFiAnimationModel(
      id: 'district9_mech',
      name: 'Prawn Arc Generator Mech',
      movie: 'District 9',
      price: 22000,
      description: 'Bio-locked alien exoskeleton charges its gravity repulsion cannon with crackling lightning arcs.',
      glowColor: Color(0xFFFFBB00),
      accentColor: Color(0xFF33FF99),
      routeName: '/scifi/district9',
    ),
    SciFiAnimationModel(
      id: 'tesseract_cascade',
      name: 'Tesseract Data Cascade',
      movie: 'Interstellar',
      price: 30000,
      description: 'Cooper reaches through the fifth dimension. Books cascade across infinite bookshelf timelines in the gravitational anomaly.',
      glowColor: Color(0xFFFFAA55),
      accentColor: Color(0xFFFFFFFF),
      routeName: '/scifi/tesseract',
    ),
    // ===== 5 NEW GYRO SCI-FI ANIMATIONS =====
    SciFiAnimationModel(
      id: 'warship_beam_cannon',
      name: 'Warship Beam Cannon',
      movie: 'Sci-Fi Original',
      price: 35000, // 35k tokens ($3.50)
      description: 'A sleek Alliance warship locks on and fires a devastating cyan beam ray at an enemy vessel. Tilt to guide the beam — watch shields flicker and debris explode on impact.',
      glowColor: Color(0xFF00EEFF),
      accentColor: Color(0xFFFF4400),
      routeName: '/scifi/warship-beam',
    ),
    SciFiAnimationModel(
      id: 'shooting_stars_field',
      name: 'Shooting Stars Field',
      movie: 'Sci-Fi Original',
      price: 25000, // 25k tokens ($2.50)
      description: 'A 7-stage cosmic meteor event: Calm Starfield → First Shooters → Meteor Shower → Large Meteors → Atmosphere Entry Fireballs → Ground Impacts → Expanding Debris Nebula.',
      glowColor: Color(0xFFCCBBFF),
      accentColor: Color(0xFFFFEEAA),
      routeName: '/scifi/shooting-stars',
    ),
    SciFiAnimationModel(
      id: 'alien_invasion_ship',
      name: 'Alien Invasion',
      movie: 'Sci-Fi Original',
      price: 40000, // 40k tokens ($4.00) (User specified)
      description: 'A dramatic 7-stage alien invasion: Peaceful Night City → Electromagnetic Anomalies → Scout UFO → Mothership Descent → Tractor Beam Abduction → Full Invasion Fleet → Alien Transmission.',
      glowColor: Color(0xFF00FF66),
      accentColor: Color(0xFF66FFAA),
      routeName: '/scifi/alien-invasion',
    ),
    SciFiAnimationModel(
      id: 'cosmic_zoom_bigbang',
      name: 'Cosmic Zoom — Big Bang',
      movie: 'Sci-Fi Original',
      price: 50000, // 50k tokens ($5.00) (User specified)
      description: 'An epic 8-stage intergalactic journey: Earth Surface → Earth Orbit → Solar System → Milky Way → Local Group → Observable Universe → Cosmic Horizon → The Big Bang singularity.',
      glowColor: Color(0xFFAABBFF),
      accentColor: Color(0xFFFFCC88),
      routeName: '/scifi/cosmic-zoom',
    ),
    SciFiAnimationModel(
      id: 'space_battle_war',
      name: 'Space Battle War',
      movie: 'Sci-Fi Original',
      price: 45000, // 45k tokens ($4.50)
      description: 'An all-out space armada war rages between Alliance and Imperial fleets. Missiles streak, lasers exchange, explosions erupt — all with a ringed planet looming in the background.',
      glowColor: Color(0xFF00AAFF),
      accentColor: Color(0xFFFF3300),
      routeName: '/scifi/space-battle',
    ),
    // ===== 5 NEW CINEMATIC SCI-FI ANIMATIONS =====
    SciFiAnimationModel(
      id: 'quantum_blackhole',
      name: 'Quantum Singularity',
      movie: 'Sci-Fi Original',
      price: 35000, // 35k tokens ($3.50)
      description: 'A supermassive black hole with gravitational lensing rings, swirling purple corona glow, polar relativistic jets, and spiraling Hawking radiation particles. Tilt to warp space-time.',
      glowColor: Color(0xFF9C27B0),
      accentColor: Color(0xFF00E5FF),
      routeName: '/scifi/quantum-blackhole',
    ),
    SciFiAnimationModel(
      id: 'cyberpunk_neon_rain',
      name: 'Cyberpunk Neon Rain',
      movie: 'Blade Runner 2049',
      price: 30000, // 30k tokens ($3.00)
      description: 'A drenched dystopian megacity skyline with illuminated neon skyscraper windows, falling multi-colored laser rain, glitch scanlines, and ground neon puddle reflections.',
      glowColor: Color(0xFFFF2A6D),
      accentColor: Color(0xFF00E5FF),
      routeName: '/scifi/cyberpunk-rain',
    ),
    SciFiAnimationModel(
      id: 'galactic_nebula',
      name: 'Galactic Nebula Drift',
      movie: 'Cosmic Original',
      price: 32000, // 32k tokens ($3.20)
      description: 'A deep space vista with layered shifting cosmic nebula clouds, pulsing starfield clusters, and streak shooting stars across interstellar space.',
      glowColor: Color(0xFF6A0DAD),
      accentColor: Color(0xFF00E5FF),
      routeName: '/scifi/galactic-nebula',
    ),
    SciFiAnimationModel(
      id: 'time_warp_vortex',
      name: 'Time Warp Vortex',
      movie: 'Sci-Fi Original',
      price: 40000, // 40k tokens ($4.00)
      description: 'A multi-armed chrono-spiral vortex warping space-time dimensions with concentric chronal distortion wave rings and a blinding white-cyan temporal rift core.',
      glowColor: Color(0xFF00E5FF),
      accentColor: Color(0xFFB44FFF),
      routeName: '/scifi/time-warp',
    ),
    SciFiAnimationModel(
      id: 'nanobot_swarm',
      name: 'Nanobot Swarm Assembly',
      movie: 'Sci-Fi Original',
      price: 38000, // 38k tokens ($3.80)
      description: '80 autonomous glowing cyan nanobots swarm across a holographic matrix grid, connecting dynamic neural energy pathways and self-assembling into a pulsating NEX geometric core.',
      glowColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF00FF88),
      routeName: '/scifi/nanobot-swarm',
    ),
  ];

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final ownedList = prefs.getStringList('scifi_owned_animations') ?? [];
    _ownedAnimations = Set<String>.from(ownedList);
    _ownedAnimations.add('matrix_rain'); // Matrix rain is default and free

    _equippedScreens = {
      'home': prefs.getString('scifi_equipped_home') ?? 'matrix_rain',
      if (prefs.containsKey('scifi_equipped_splash')) 'splash': prefs.getString('scifi_equipped_splash')!,
      if (prefs.containsKey('scifi_equipped_profile')) 'profile': prefs.getString('scifi_equipped_profile')!,
      if (prefs.containsKey('scifi_equipped_gaming_hub')) 'gaming_hub': prefs.getString('scifi_equipped_gaming_hub')!,
      if (prefs.containsKey('scifi_equipped_store')) 'store': prefs.getString('scifi_equipped_store')!,
      if (prefs.containsKey('scifi_equipped_chat')) 'chat': prefs.getString('scifi_equipped_chat')!,
      if (prefs.containsKey('scifi_equipped_chat_list')) 'chat_list': prefs.getString('scifi_equipped_chat_list')!,
      if (prefs.containsKey('scifi_equipped_settings')) 'settings': prefs.getString('scifi_equipped_settings')!,
    };

    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scifi_owned_animations', _ownedAnimations.toList());
    
    for (final screenKey in ['home', 'splash', 'profile', 'gaming_hub', 'store', 'chat', 'chat_list', 'settings']) {
      final animId = _equippedScreens[screenKey];
      if (animId != null) {
        await prefs.setString('scifi_equipped_$screenKey', animId);
      } else {
        await prefs.remove('scifi_equipped_$screenKey');
      }
    }
  }

  /// Direct setter for home background animation
  void setHomeBackground(String? animationId) {
    if (animationId != null) {
      _equippedScreens['home'] = animationId;
    } else {
      _equippedScreens['home'] = 'matrix_rain';
    }
    _saveState();
    notifyListeners();
  }

  /// Direct setter for chat list background animation
  void setChatListBackground(String? animationId) {
    if (animationId != null) {
      _equippedScreens['chat_list'] = animationId;
    } else {
      _equippedScreens.remove('chat_list');
    }
    _saveState();
    notifyListeners();
  }

  /// Purchase an animation using tokens. Returns true on success.
  bool purchaseAnimation(String animationId, int cost, TokenProvider tokenProvider) {
    if (_ownedAnimations.contains(animationId)) return false;
    if (tokenProvider.balance < cost) return false;
    tokenProvider.deductTokens(cost);
    _ownedAnimations = {..._ownedAnimations, animationId};
    _saveState();
    notifyListeners();
    return true;
  }

  /// Equip an owned animation for a specific screen (by screenKey or AnimationScreen enum)
  bool equipAnimation(String animationId, dynamic screen) {
    if (!_ownedAnimations.contains(animationId)) return false;
    final key = screen is AnimationScreen ? _screenEnumToKey(screen) : screen.toString();
    _equippedScreens[key] = animationId;
    _saveState();
    notifyListeners();
    return true;
  }

  /// Equip to ALL screens simultaneously!
  bool equipAllScreens(String animationId) {
    if (!_ownedAnimations.contains(animationId)) return false;
    final allKeys = ['home', 'splash', 'profile', 'gaming_hub', 'store', 'chat', 'chat_list', 'settings'];
    for (final k in allKeys) {
      _equippedScreens[k] = animationId;
    }
    _saveState();
    notifyListeners();
    return true;
  }

  /// Unequip animation from a screen.
  void unequipAnimation(dynamic screen) {
    final key = screen is AnimationScreen ? _screenEnumToKey(screen) : screen.toString();
    if (key == 'home') {
      _equippedScreens['home'] = 'matrix_rain';
    } else {
      _equippedScreens.remove(key);
    }
    _saveState();
    notifyListeners();
  }

  String _screenEnumToKey(AnimationScreen s) {
    switch (s) {
      case AnimationScreen.home: return 'home';
      case AnimationScreen.splash: return 'splash';
      case AnimationScreen.profile: return 'profile';
      case AnimationScreen.gamingHub: return 'gaming_hub';
      case AnimationScreen.store: return 'store';
      case AnimationScreen.chat: return 'chat';
      case AnimationScreen.chatList: return 'chat_list';
      case AnimationScreen.settings: return 'settings';
      case AnimationScreen.global: return 'all';
    }
  }
}
