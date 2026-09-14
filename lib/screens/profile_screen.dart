import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/animation_provider.dart';
import '../providers/token_provider.dart' as token_provider;
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/user_leveling_service.dart';
import '../services/game_sound_service.dart';
import '../widgets/cyber_background.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/scifi_animations.dart';
import 'file_manager_screen.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  AuthService? _authService;
  bool _isUploading = false;
  Uint8List? _selectedImageBytes;
  String? _avatarUrl;
  String _userStatusBio = "Available";
  String _auraColor = 'cyan';
  String _operativeTitle = 'Quantum Spectre';
  bool _biometricLock = true;
  bool _stealthMode = false;
  bool _claimedMission2 = false;
  final bool _claimedMission3 = true;
  final bool _claimedMission4 = true;
  String _hapticLevel = 'High';
  bool _holoSheenEnabled = true;
  bool _cyberSfxEnabled = true;
  late AnimationController _glowController;
  late AnimationController _reactorSpinController;
  StreamSubscription<int>? _levelUpSubscription;
  StreamSubscription<Map<String, dynamic>>? _milestoneAvatarSubscription;
  int _selectedProfileTab = 0; // 0: Ascension, 1: Telemetry, 2: Dossier, 3: Vault

  @override
  void initState() {
    super.initState();
    UserLevelingService.instance.initialize();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _reactorSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _levelUpSubscription = UserLevelingService.instance.onLevelUpStream.listen((newLevel) {
      if (!mounted) return;
      CinematicLevelUpDialog.show(context, newLevel);
    });

    _milestoneAvatarSubscription = UserLevelingService.instance.onMilestoneAvatarUnlockStream.listen((milestoneData) {
      if (!mounted) return;
      _showMilestoneAvatarUnlockedDialog(context, milestoneData);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authService = Provider.of<AuthService>(context, listen: false);
      _authService?.addListener(_onAuthServiceChanged);
      _syncProfileFromAuth();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _reactorSpinController.dispose();
    _levelUpSubscription?.cancel();
    _milestoneAvatarSubscription?.cancel();
    if (_authService != null) {
      _authService!.removeListener(_onAuthServiceChanged);
      _authService = null;
    }
    _nameController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onAuthServiceChanged() {
    if (!mounted || _authService == null) return;
    final profile = _authService!.userProfile;
    final user = _authService!.user ?? FirebaseService.auth.currentUser;
    if (profile != null) {
      if (!mounted) return;
      setState(() {
        _nameController.text = AuthService.resolveDisplayName(
          name: profile['name']?.toString() ?? profile['displayName']?.toString() ?? profile['display_name']?.toString() ?? user?.displayName,
          username: profile['username']?.toString(),
          email: user?.email,
        );
        _usernameController.text = profile['username']?.toString() ?? user?.displayName ?? user?.email?.split('@').first ?? '';
        _ageController.text = profile['age']?.toString() ?? '';
        _avatarUrl = profile['photo_url']?.toString() ??
            profile['photoUrl']?.toString() ??
            profile['profilePicUrl']?.toString() ??
            profile['avatar_url']?.toString() ??
            user?.photoURL;
        if (profile['bio'] != null && profile['bio'].toString().isNotEmpty) {
          _userStatusBio = profile['bio'].toString();
        }
      });
    }
  }

  Future<void> _syncProfileFromAuth() async {
    if (!mounted) return;
    final authService = _authService ?? Provider.of<AuthService>(context, listen: false);
    final user = authService.user ?? FirebaseService.auth.currentUser;
    if (user == null) return;

    final cached = authService.userProfile;
    if (cached != null && mounted) {
      setState(() {
        _nameController.text = AuthService.resolveDisplayName(
          name: cached['name']?.toString() ?? cached['displayName']?.toString() ?? cached['display_name']?.toString() ?? user.displayName,
          username: cached['username']?.toString(),
          email: user.email,
        );
        _usernameController.text = cached['username']?.toString() ?? user.displayName ?? user.email?.split('@').first ?? '';
        _ageController.text = cached['age']?.toString() ?? '';
        _avatarUrl = cached['photo_url']?.toString() ??
            cached['photoUrl']?.toString() ??
            cached['profilePicUrl']?.toString() ??
            cached['avatar_url']?.toString() ??
            user.photoURL;
        if (cached['bio'] != null && cached['bio'].toString().isNotEmpty) {
          _userStatusBio = cached['bio'].toString();
        }
      });
      return;
    }

    try {
      await authService.fetchUserProfile(user: user);
      final profileData = authService.userProfile;
      if (profileData != null && mounted) {
        setState(() {
          _nameController.text = AuthService.resolveDisplayName(
            name: profileData['name']?.toString() ?? profileData['displayName']?.toString() ?? profileData['display_name']?.toString() ?? user.displayName,
            username: profileData['username']?.toString(),
            email: user.email,
          );
          _usernameController.text = profileData['username']?.toString() ?? user.displayName ?? user.email?.split('@').first ?? '';
          _ageController.text = profileData['age']?.toString() ?? '';
          _avatarUrl = profileData['photo_url']?.toString() ??
              profileData['photoUrl']?.toString() ??
              profileData['profilePicUrl']?.toString() ??
              profileData['avatar_url']?.toString() ??
              user.photoURL;
          if (profileData['bio'] != null && profileData['bio'].toString().isNotEmpty) {
            _userStatusBio = profileData['bio'].toString();
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }

    if (mounted) {
      setState(() {
        _nameController.text = AuthService.resolveDisplayName(
          name: user.displayName,
          username: null,
          email: user.email,
        );
        _usernameController.text = user.displayName ?? user.email?.split('@').first ?? '';
        _ageController.text = '';
        _avatarUrl = user.photoURL;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final result = await FilePicker.pickFile(type: FileType.image);
      if (result == null || result.path == null) return;

      final bytes = await result.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() {
        _selectedImageBytes = bytes;
        _isUploading = true;
      });

      final uploadedUrl = await authService.uploadAvatar(
        bytes: bytes,
        fileName: result.name,
      );
      UserLevelingService.instance.revertToCustomAvatar();

      if (!mounted) return;
      setState(() {
        _avatarUrl = uploadedUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update avatar: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name.')),
      );
      return;
    }

    int? ageValue;
    final ageText = _ageController.text.trim();
    if (ageText.isNotEmpty) {
      ageValue = int.tryParse(ageText);
      if (ageValue == null || ageValue <= 0 || ageValue > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid age between 1 and 120.')),
        );
        return;
      }
    }

    try {
      await authService.updateProfile(
        displayName: displayName,
        username: _usernameController.text.trim(),
        age: ageValue,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save profile: $e')),
      );
    }
  }

  ImageProvider<Object>? _avatarImageProvider() {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!);
    }
    final milestoneAsset = UserLevelingService.instance.activeMilestoneAvatarAsset;
    if (milestoneAsset != null) {
      return AssetImage(milestoneAsset);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    final user = _authService?.user ?? FirebaseService.auth.currentUser;
    if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      return NetworkImage(user.photoURL!);
    }
    return null;
  }

  String _displayNameForUser(dynamic user) {
    return AuthService.resolveDisplayName(
      name: user?.displayName?.toString() ?? _nameController.text,
      username: null,
      email: user?.email?.toString(),
    );
  }

  Color _getAuraColor() {
    switch (_auraColor) {
      case 'purple':
        return const Color(0xFFC084FC);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'emerald':
        return const Color(0xFF00FF66);
      case 'flame':
        return const Color(0xFFFF4500);
      case 'cyan':
      default:
        return const Color(0xFF00E5FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final tokenProvider = Provider.of<token_provider.TokenProvider>(context);
    final animationProvider = Provider.of<AnimationProvider>(context);
    final userLeveling = UserLevelingService.instance;
    final user = authService.user;
    final bonusAvailable = !tokenProvider.dailyBonusClaimed;
    final referralLink = _buildReferralLink(user?.uid);
    final auraColor = _getAuraColor();
    final equippedProfileId = animationProvider.equippedProfileAnimation;

    final profileBadges = authService.userProfile != null
        ? List<String>.from(authService.userProfile!['game_badges'] is List ? authService.userProfile!['game_badges'] : <String>[])
        : FirebaseService.defaultGameBadges();

    return AnimatedBuilder(
      animation: userLeveling,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF050814),
          appBar: AppBar(
            title: const Text(
              'PROFILE TO THE MAX',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
            ),
            backgroundColor: const Color(0xFF050814),
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () => _showQrShareDialog(context, user),
                icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00E5FF)),
                tooltip: 'Share QR Profile',
              ),
              IconButton(
                onPressed: () => _showEditProfileDialog(context, authService),
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                tooltip: 'Edit Profile',
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: equippedProfileId != null
                    ? buildSciFiAnimation(equippedProfileId)
                    : const CyberBackground(
                        backgroundColors: [
                          Color(0xFF010308),
                          Color(0xFF050816),
                          Color(0xFF081122),
                          Color(0xFF02040D),
                        ],
                        leftAuroraColors: [
                          Color(0xFF00F0B6),
                          Color(0xFF5A50FF),
                          Color(0x00000000),
                        ],
                        rightAuroraColors: [
                          Color(0xFFB14BFF),
                          Color(0xFF3B82F6),
                          Color(0x00000000),
                        ],
                        fogColor: Color(0x2AFFFFFF),
                        leftAuroraCenter: Alignment(-0.28, -0.26),
                        rightAuroraCenter: Alignment(0.8, -0.16),
                      ),
              ),
              if (equippedProfileId != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              SafeArea(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // ── 1. Cyber Glass Avatar & Identity Header ─────────────────
                    _buildCyberHeroCard(user, auraColor, userLeveling),

                    const SizedBox(height: 12),

                    // ── 2. Quick Action Pills Row ───────────────────────────────
                    _buildQuickActionButtons(context, user),

                    const SizedBox(height: 14),

                    // ── 3. High-Tech Cyber Segmented Tab Bar ────────────────────
                    _buildProfileTabBar(auraColor),

                    const SizedBox(height: 16),

                    // ── 4. Dynamic Tab View ─────────────────────────────────────
                    if (_selectedProfileTab == 0) ...[
                      // ── 1.5. MAD UNLIMITED LEVELING SYSTEM ────────────────────
                      _buildLimitlessLevelingCard(userLeveling, auraColor),

                      const SizedBox(height: 16),

                      // ── 1.5.1 GOD-TIER MILESTONE AVATAR ARSENAL ───────────────
                      _buildMilestoneAvatarsShowcaseCard(userLeveling, auraColor),

                      const SizedBox(height: 16),

                      // ── 1.8. DAILY OPERATIVE MISSIONS & BOUNTY HUB ────────────
                      _buildDailyMissionsCard(userLeveling, tokenProvider, auraColor),

                      const SizedBox(height: 16),

                      // ── 1.9. PRESTIGE SKILL TREE & PERK LOCKER ────────────────
                      _buildPrestigePerksCard(userLeveling, auraColor),
                    ] else if (_selectedProfileTab == 1) ...[
                      // ── 1.6. ONLINE & GAME ONLINE TIME TELEMETRY ──────────────
                      _buildOnlineTimeTelemetryCard(userLeveling, auraColor),

                      const SizedBox(height: 16),

                      // ── 1.7. COMBAT & GAMING ANALYTICS ────────────────────────
                      _buildCombatAnalyticsCard(userLeveling, auraColor),

                      const SizedBox(height: 16),

                      // ── 1.11. CYBER CLAN & SYNDICATE SQUADRON ─────────────────
                      _buildSyndicateCard(auraColor),

                      const SizedBox(height: 16),

                      // ── 1.15. DEVICE STORAGE & SCANNER TELEMETRY ───────────────
                      _buildDeviceStorageCleanerWidget(auraColor),
                    ] else if (_selectedProfileTab == 2) ...[
                      // ── 2. WhatsApp-Style Bio & Status Editor ──────────────────
                      _buildStatusBioCard(),

                      const SizedBox(height: 16),

                      // ── 1.13. OPERATIVE CALL-SIGN & ELITE TITLE ────────────────
                      _buildOperativeCallSignCard(auraColor),

                      const SizedBox(height: 16),

                      // ── 1.14. OPERATIVE AURA GLOW SELECTOR ────────────────────
                      _buildAuraColorCustomizerCard(),

                      const SizedBox(height: 16),

                      // ── 1.10. EQUIPPED SCI-FI ARMORY & HOLO-DECKS ──────────────
                      _buildEquippedAnimationsShowcase(animationProvider, auraColor),

                      const SizedBox(height: 16),

                      // ── 1.12. HAPTIC & AUDIO FX ENGINE CONSOLE ────────────────
                      _buildProfileFxCard(auraColor),
                    ] else if (_selectedProfileTab == 3) ...[
                      // ── 4. Tokens Treasury & Daily Streak Section ─────────────
                      _buildTokensTreasuryCard(tokenProvider, bonusAvailable),

                      const SizedBox(height: 16),

                      // ── 7. Gamer Hall of Fame & Badges ────────────────────────
                      _buildGamerBadgesSection(profileBadges),

                      const SizedBox(height: 16),

                      // ── 6. End-to-End Encryption & Security Fingerprint ───────
                      _buildSecurityEncryptionCard(user),

                      const SizedBox(height: 16),

                      // ── 5. Media, Links & Docs Showcase ───────────────────────
                      _buildMediaShowcaseSection(),

                      const SizedBox(height: 16),

                      // ── 8. Referral Program Hub ───────────────────────────────
                      _buildReferralProgramCard(referralLink),

                      const SizedBox(height: 16),

                      // ── 9. Cyber Notes Scratchpad ─────────────────────────────
                      _buildQuickNotesCard(tokenProvider),
                    ],

                    const SizedBox(height: 24),

                    // ── 10. Sign Out Button ─────────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                      label: const Text(
                        'SIGN OUT OPERATIVE',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1014),
                        foregroundColor: const Color(0xFFFF5252),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 0. Cyber Segmented Navigation Bar ────────────────────────────────────
  Widget _buildProfileTabBar(Color auraColor) {
    final tabs = [
      {'icon': Icons.all_inclusive_rounded, 'label': 'ASCENSION'},
      {'icon': Icons.insights_rounded, 'label': 'TELEMETRY'},
      {'icon': Icons.badge_rounded, 'label': 'DOSSIER'},
      {'icon': Icons.lock_clock_rounded, 'label': 'VAULT'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedProfileTab == index;
          final tab = tabs[index];
          final icon = tab['icon'] as IconData;
          final label = tab['label'] as String;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedProfileTab != index) {
                  HapticFeedback.selectionClick();
                  GameSoundService().playTick();
                  setState(() => _selectedProfileTab = index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            auraColor.withValues(alpha: 0.35),
                            auraColor.withValues(alpha: 0.12),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: auraColor.withValues(alpha: 0.6), width: 1.2)
                      : Border.all(color: Colors.transparent),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: auraColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? auraColor : Colors.white54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 9.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 1. Cyber Hero Card ───────────────────────────────────────────────────
  Widget _buildCyberHeroCard(dynamic user, Color auraColor, UserLevelingService leveling) {
    final displayName = _displayNameForUser(user);
    final username = _usernameController.text.isNotEmpty ? '@${_usernameController.text}' : '@alex_nex';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            auraColor.withValues(alpha: 0.18),
            const Color(0xFF0F172A).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: auraColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: auraColor.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with glowing animated aura
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: auraColor.withValues(alpha: 0.4 + _glowController.value * 0.6),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: auraColor.withValues(alpha: 0.3 * _glowController.value),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFF1E293B),
                          backgroundImage: _avatarImageProvider(),
                          child: _selectedImageBytes == null && (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? const Icon(Icons.person_rounded, color: Colors.white, size: 40)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploading ? null : _pickAndUploadAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: auraColor,
                                shape: BoxShape.circle,
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 16),

              // User name, level & status chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 18),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username,
                      style: TextStyle(
                        color: auraColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'cyber_operative@nex.app',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: leveling.rankColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: leveling.rankColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(leveling.rankIcon, color: leveling.rankColor, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                'LVL ${leveling.currentLevel} • ${leveling.rankTitle}',
                                style: TextStyle(color: leveling.rankColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        if (leveling.prestigeLevel > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8F00)]),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 8),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.black, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  'PRESTIGE ${leveling.prestigeLevel}',
                                  style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Reality Tier Subtitle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      leveling.realityTierTitle,
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                  ],
                ),
                Text(
                  leveling.anomalousPower,
                  style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── God-Tier Milestone Avatar Quick Control ─────────────────────────
          _buildMilestoneAvatarQuickControl(leveling, auraColor),

          const SizedBox(height: 14),

          // Aura Color Swatches
          Row(
            children: [
              const Text('AURA:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              _buildAuraDot('cyan', const Color(0xFF00E5FF)),
              _buildAuraDot('emerald', const Color(0xFF00FF66)),
              _buildAuraDot('purple', const Color(0xFFC084FC)),
              _buildAuraDot('gold', const Color(0xFFFFD700)),
              _buildAuraDot('flame', const Color(0xFFFF4500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── God-Tier Milestone Avatar Quick Control Widget ───────────────────────────
  Widget _buildMilestoneAvatarQuickControl(UserLevelingService leveling, Color auraColor) {
    final isMilestoneActive = leveling.isMilestoneAvatarActive;
    final activeData = leveling.currentMilestoneAvatarData;
    final unlockedCount = leveling.unlockedMilestoneAvatars.length;
    final themeColor = isMilestoneActive ? (activeData?['color'] as Color? ?? auraColor) : auraColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMilestoneActive
            ? themeColor.withValues(alpha: 0.12)
            : const Color(0xFF0F172A).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMilestoneActive
              ? themeColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMilestoneActive
                  ? themeColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(
              isMilestoneActive ? Icons.auto_awesome_rounded : Icons.photo_camera_front_rounded,
              size: 16,
              color: isMilestoneActive ? themeColor : Colors.white70,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isMilestoneActive ? 'GOD-TIER SKIN ACTIVE' : 'PERSONAL AVATAR',
                      style: TextStyle(
                        color: isMilestoneActive ? themeColor : Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (isMilestoneActive && activeData != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LVL ${activeData['level']}',
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isMilestoneActive
                      ? (activeData?['title'] as String? ?? 'Equipped')
                      : (unlockedCount > 0
                          ? '$unlockedCount God-Tier Skins Available'
                          : 'Unlocks at Level 100, 1K, 10K, 100K+'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMilestoneActive) ...[
            Tooltip(
              message: 'Revert to Personal Photo',
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  GameSoundService().playTick();
                  leveling.revertToCustomAvatar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Restored your personal profile photo.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.undo_rounded, size: 12, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        'REVERT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              GameSoundService().playTick();
              _showMilestoneAvatarSelector(context, leveling);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMilestoneActive
                      ? [
                          themeColor.withValues(alpha: 0.4),
                          themeColor.withValues(alpha: 0.2),
                        ]
                      : [
                          const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMilestoneActive
                      ? themeColor.withValues(alpha: 0.6)
                      : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.style_rounded,
                    size: 12,
                    color: isMilestoneActive ? themeColor : const Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SKINS',
                    style: TextStyle(
                      color: isMilestoneActive ? themeColor : Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Milestone Avatar Selector Bottom Sheet ──────────────────────────────────
  void _showMilestoneAvatarSelector(BuildContext context, UserLevelingService leveling) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMilestoneActive = leveling.isMilestoneAvatarActive;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0B0E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6600E5FF),
                    blurRadius: 30,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF7C3AED)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GOD-TIER AVATAR ARSENAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Reality-Bending Milestone Transformations',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // Auto-Equip Toggle & Revert Controls
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFFFD700), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto-Equip on Level Up',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    'Equip milestone skins instantly when unlocked',
                                    style: TextStyle(color: Colors.white54, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: leveling.autoEquipMilestones,
                              activeThumbColor: const Color(0xFF00E5FF),
                              activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                              onChanged: (val) {
                                leveling.setAutoEquipMilestones(val);
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                        if (isMilestoneActive) ...[
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              GameSoundService().playTick();
                              leveling.revertToCustomAvatar();
                              setModalState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reverted to personal profile photo.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white70),
                                  SizedBox(width: 6),
                                  Text(
                                    'RESTORE PERSONAL PROFILE PHOTO',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Skins List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: UserLevelingService.milestoneAvatars.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final m = UserLevelingService.milestoneAvatars[index];
                        final reqLevel = m['level'] as int;
                        final isUnlocked = leveling.currentLevel >= reqLevel || leveling.prestigeLevel > 0;
                        final isEquipped = isMilestoneActive && leveling.activeMilestoneAvatarAsset == m['asset'];
                        final itemColor = m['color'] as Color;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isEquipped
                                  ? [
                                      itemColor.withValues(alpha: 0.25),
                                      const Color(0xFF0F172A).withValues(alpha: 0.8),
                                    ]
                                  : [
                                      const Color(0xFF111827).withValues(alpha: 0.85),
                                      const Color(0xFF0B0F19).withValues(alpha: 0.95),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isEquipped
                                  ? itemColor
                                  : isUnlocked
                                      ? itemColor.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.08),
                              width: isEquipped ? 1.8 : 1.0,
                            ),
                            boxShadow: isEquipped
                                ? [
                                    BoxShadow(
                                      color: itemColor.withValues(alpha: 0.3),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar Image Preview
                              Stack(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isUnlocked ? itemColor : Colors.white24,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        m['asset'] as String,
                                        fit: BoxFit.cover,
                                        color: isUnlocked ? null : Colors.black54,
                                        colorBlendMode: isUnlocked ? null : BlendMode.darken,
                                      ),
                                    ),
                                  ),
                                  if (!isUnlocked)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.lock_rounded, color: Colors.white70, size: 24),
                                        ),
                                      ),
                                    ),
                                  if (isEquipped)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: itemColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.black, size: 12),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(width: 12),

                              // Info & Actions
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: itemColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: itemColor.withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            'LEVEL ${m['level']}',
                                            style: TextStyle(
                                              color: itemColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            m['powerRating'] as String,
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m['title'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m['description'] as String,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // Action / Status Button
                                    if (isEquipped)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: itemColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: itemColor),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded, size: 12, color: itemColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              'CURRENTLY EQUIPPED',
                                              style: TextStyle(
                                                color: itemColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 9.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isUnlocked)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          HapticFeedback.heavyImpact();
                                          GameSoundService().playLevelUp();
                                          leveling.equipMilestoneAvatar(m['asset'] as String);
                                          setModalState(() {});
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Equipped "${m['title']}" avatar!'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.bolt_rounded, size: 13, color: Colors.black),
                                        label: const Text(
                                          'EQUIP NOW',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: itemColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      )
                                    else ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: (leveling.currentLevel / reqLevel).clamp(0.0, 1.0),
                                                backgroundColor: Colors.white10,
                                                valueColor: AlwaysStoppedAnimation<Color>(itemColor),
                                                minHeight: 5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${((leveling.currentLevel / reqLevel) * 100).clamp(0, 99).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Reach Level $reqLevel to unlock automatically',
                                        style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                                      ),
                                    ],
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
          },
        );
      },
    );
  }

  // ── Milestone Avatar Unlocked Celebration Dialog ─────────────────────────────
  void _showMilestoneAvatarUnlockedDialog(BuildContext context, Map<String, dynamic> milestoneData) {
    HapticFeedback.heavyImpact();
    GameSoundService().playWin();

    final itemColor = milestoneData['color'] as Color? ?? const Color(0xFF00E5FF);
    final reqLevel = milestoneData['level'] ?? 100;
    final title = milestoneData['title'] ?? 'God-Tier Avatar';
    final asset = milestoneData['asset'] as String? ?? 'assets/images/level_100_avatar.jpg';
    final description = milestoneData['description'] ?? '';
    final powerRating = milestoneData['powerRating'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF190D36),
                  Color(0xFF0D0620),
                  Color(0xFF05030B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: itemColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: itemColor.withValues(alpha: 0.5),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: itemColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: itemColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'MILESTONE LEVEL $reqLevel UNLOCKED',
                        style: TextStyle(
                          color: itemColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'GOD-TIER AVATAR EQUIPPED!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 14),

                // Large Glowing Avatar Preview
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: itemColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: itemColor.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Image.asset(asset, fit: BoxFit.cover),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),

                Text(
                  powerRating,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Friendly note explaining user choice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Text(
                    '⚡ This avatar has been automatically set on your profile! You can keep it or revert to your original photo at any time.',
                    style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.25),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 18),

                // Buttons: Keep or Revert
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          UserLevelingService.instance.revertToCustomAvatar();
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Restored your personal profile photo.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'REVERT TO PHOTO',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          GameSoundService().playWin();
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: itemColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                        ),
                        child: const Text(
                          'KEEP & ENGAGE ⚡',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 1.5.1 GOD-TIER MILESTONE AVATARS SHOWCASE CARD (TAB 0) ──────────────────
  Widget _buildMilestoneAvatarsShowcaseCard(UserLevelingService leveling, Color auraColor) {
    final unlockedCount = leveling.unlockedMilestoneAvatars.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F0B28),
            Color(0xFF080616),
            Color(0xFF02040D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF7C3AED)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.style_rounded, color: Colors.black, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GOD-TIER AVATAR VAULT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '$unlockedCount/4 Milestone Transformations Unlocked',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showMilestoneAvatarSelector(context, leveling);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ARSENAL',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF00E5FF)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4 Grid / Row items for the Milestones
          Row(
            children: UserLevelingService.milestoneAvatars.map((m) {
              final reqLevel = m['level'] as int;
              final isUnlocked = leveling.currentLevel >= reqLevel || leveling.prestigeLevel > 0;
              final isEquipped = leveling.isMilestoneAvatarActive && leveling.activeMilestoneAvatarAsset == m['asset'];
              final itemColor = m['color'] as Color;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showMilestoneAvatarSelector(context, leveling);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isEquipped
                          ? itemColor.withValues(alpha: 0.2)
                          : const Color(0xFF131B2E).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEquipped
                            ? itemColor
                            : isUnlocked
                                ? itemColor.withValues(alpha: 0.4)
                                : Colors.white12,
                        width: isEquipped ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.asset(
                                  m['asset'] as String,
                                  fit: BoxFit.cover,
                                  color: isUnlocked ? null : Colors.black54,
                                  colorBlendMode: isUnlocked ? null : BlendMode.darken,
                                ),
                              ),
                            ),
                            if (!isUnlocked)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(Icons.lock_rounded, color: Colors.white70, size: 16),
                                ),
                              ),
                            if (isEquipped)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: itemColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 8),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'LVL $reqLevel',
                          style: TextStyle(
                            color: isUnlocked ? itemColor : Colors.white38,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          isEquipped
                              ? 'ACTIVE'
                              : isUnlocked
                                  ? 'READY'
                                  : 'LOCKED',
                          style: TextStyle(
                            color: isEquipped
                                ? itemColor
                                : isUnlocked
                                    ? Colors.white70
                                    : Colors.white24,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 1.5. MAD UNLIMITED LEVELING SYSTEM (CRAZILY UNREALISTIC) ─────────────
  Widget _buildLimitlessLevelingCard(UserLevelingService leveling, Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF14082C),
            Color(0xFF0B061A),
            Color(0xFF030510),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: leveling.rankColor.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: leveling.rankColor.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Reality Badge and Roadmap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: leveling.rankColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: leveling.rankColor.withValues(alpha: 0.5), blurRadius: 12),
                      ],
                    ),
                    child: Icon(leveling.rankIcon, color: leveling.rankColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REALITY ASCENSION MATRIX ∞',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                      ),
                      Text(
                        leveling.realityTierTitle,
                        style: TextStyle(color: leveling.rankColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () => LevelingRoadmapModal.show(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: leveling.rankColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: leveling.rankColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_rounded, color: leveling.rankColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'ROADMAP ∞',
                        style: TextStyle(color: leveling.rankColor, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Rotating Holographic Reactor Core Visual ──
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer spinning reactor ring (Clockwise)
                  RotationTransition(
                    turns: _reactorSpinController,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: leveling.rankColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        gradient: SweepGradient(
                          colors: [
                            leveling.rankColor.withValues(alpha: 0.0),
                            leveling.rankColor,
                            const Color(0xFF00E5FF),
                            leveling.rankColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Inner reverse-spinning reactor ring (Counter-clockwise)
                  RotationTransition(
                    turns: Tween<double>(begin: 1.0, end: 0.0).animate(_reactorSpinController),
                    child: Container(
                      width: 135,
                      height: 135,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        gradient: const SweepGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF00E5FF),
                            Color(0xFFB44FFF),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Central Core Orb
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          leveling.rankColor.withValues(alpha: 0.35),
                          const Color(0xFF090616),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: leveling.rankColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (leveling.prestigeLevel > 0)
                          Text(
                            'PRESTIGE ${leveling.prestigeLevel} ★',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w900,
                              fontSize: 8.5,
                              letterSpacing: 0.5,
                            ),
                          )
                        else
                          const Text(
                            'CORE ENGINE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w800,
                              fontSize: 7.5,
                              letterSpacing: 1.2,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'LVL ${leveling.currentLevel}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(color: leveling.rankColor, blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(leveling.levelProgress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: leveling.rankColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Animated XP Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final barWidth = constraints.maxWidth * leveling.levelProgress.clamp(0.0, 1.0);
                return Container(
                  height: 12,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.08),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: barWidth,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF),
                          leveling.rankColor,
                          const Color(0xFFFF007F),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: leveling.rankColor.withValues(alpha: 0.8), blurRadius: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // XP Numbers & Total XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leveling.isMaxLevel
                    ? 'MAX LEVEL 9,999 REACHED (SINGULARITY ACTIVE)'
                    : '${leveling.xpInCurrentLevel} / ${leveling.xpRequiredForNextLevel} XP to Ascend',
                style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                'SINGULARITY: ${leveling.totalXP} XP',
                style: TextStyle(color: leveling.rankColor, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── UNREALISTIC SCI-FI ANOMALOUS TELEMETRY (6 GOD-TIER STATS) ──
          const Text(
            'ANOMALOUS REALITY TELEMETRY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          // 3x2 Grid of god-tier stats
          Row(
            children: [
              Expanded(
                child: _buildSciFiMetricTile(
                  icon: Icons.speed_rounded,
                  label: 'CORE FREQUENCY',
                  value: leveling.coreClockSpeed,
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSciFiMetricTile(
                  icon: Icons.grain_rounded,
                  label: 'REALITY WARP',
                  value: leveling.realityDistortion,
                  color: const Color(0xFFB44FFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSciFiMetricTile(
                  icon: Icons.shield_rounded,
                  label: 'KINETIC SHIELD',
                  value: leveling.kineticShielding,
                  color: const Color(0xFF00FF88),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSciFiMetricTile(
                  icon: Icons.sync_alt_rounded,
                  label: 'NEURAL SYNC',
                  value: leveling.neuralSyncRate,
                  color: const Color(0xFFFF007F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSciFiMetricTile(
                  icon: Icons.memory_rounded,
                  label: 'QUANTUM COMPUTE',
                  value: leveling.quantumCompute,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSciFiMetricTile(
                  icon: Icons.offline_bolt_rounded,
                  label: 'ANOMALOUS POWER',
                  value: leveling.anomalousPower,
                  color: const Color(0xFFFFD700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Action Buttons Deck: Overclock Bursts + Reality Warp + Prestige ──
          Row(
            children: [
              // Quantum Overclock (+1,500 XP)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    leveling.overclockCore();
                    GameSoundService().playLaser();
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF13092A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        content: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 8),
                            Text(
                              '⚡ OVERCLOCK: +1,500 XP! (${leveling.coreClockSpeed})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          const Color(0xFF0077FF).withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), blurRadius: 10),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF), size: 16),
                        SizedBox(width: 5),
                        Text(
                          '+1,500 OVERCLOCK',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reality Warp (+10,000 XP)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    leveling.realityWarp();
                    GameSoundService().playMagic();
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF2A093D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        content: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB44FFF)),
                            const SizedBox(width: 8),
                            Text(
                              '🌌 REALITY WARPED: +10,000 XP! (${leveling.anomalousPower})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFB44FFF).withValues(alpha: 0.2),
                          const Color(0xFFFF007F).withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.6)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFB44FFF).withValues(alpha: 0.2), blurRadius: 10),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.all_inclusive_rounded, color: Color(0xFFB44FFF), size: 16),
                        SizedBox(width: 5),
                        Text(
                          '+10,000 WARP',
                          style: TextStyle(
                            color: Color(0xFFB44FFF),
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Prestige Rebirth + Fanfare Preview
          Row(
            children: [
              // Prestige Rebirth
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPrestigeAscensionDialog(context, leveling),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700).withValues(alpha: 0.2),
                          const Color(0xFFFF8F00).withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 15),
                        SizedBox(width: 5),
                        Text(
                          'ASCEND PRESTIGE 🔱',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Fanfare preview button
              Expanded(
                child: GestureDetector(
                  onTap: () => CinematicLevelUpDialog.show(context, leveling.currentLevel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.celebration_rounded, color: Colors.white70, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'FANFARE PREVIEW',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSciFiMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrestigeAscensionDialog(BuildContext context, UserLevelingService leveling) {
    showDialog(
      context: context,
      builder: (ctx) {
        final canAscend = leveling.canAscendPrestige;
        return Dialog(
          backgroundColor: const Color(0xFF09061A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 18),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD700), size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PRESTIGE REALITY ASCENSION',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  canAscend
                      ? 'INITIATE QUANTUM REBIRTH PROTOCOL?\n\nYour level will reset to Level 1, but you will ascend to PRESTIGE ${leveling.prestigeLevel + 1} with a permanent +2.5x anomalous power multiplier, exclusive prestige star badge, and reality distortion expansion!'
                      : 'PRESTIGE ASCENSION LOCKED\n\nRequires Level 100 or 50,000 Total Singularity XP.\n\nCurrent Total XP: ${leveling.totalXP} XP.\n\nTip: Use "REALITY WARP" (+10,000 XP per tap) in the Ascension console to reach the threshold instantly!',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (canAscend)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('ABORT', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final success = leveling.ascendPrestige();
                            if (success) {
                              GameSoundService().playWin();
                              HapticFeedback.heavyImpact();
                              CinematicLevelUpDialog.show(context, leveling.currentLevel);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('ASCEND 🔱', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: const Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 1.6. ONLINE & GAME ONLINE TIME TELEMETRY CARD ─────────────────────────
  Widget _buildOnlineTimeTelemetryCard(UserLevelingService leveling, Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A1428),
            Color(0xFF050E1C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timer_rounded, color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ACTIVE TIME TELEMETRY',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FF88),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'TRACKING LIVE',
                    style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: 0.8),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // Total App Online Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.phone_android_rounded, color: Color(0xFF00E5FF), size: 16),
                          SizedBox(width: 6),
                          Text('App Online Time', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        leveling.formattedTotalOnlineTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Today: ${leveling.formattedTodayOnlineTime}',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Game Online Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sports_esports_rounded, color: Color(0xFF00FF88), size: 16),
                          SizedBox(width: 6),
                          Text('Game Online Time', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        leveling.formattedTotalGamingTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'In-Game Match Time',
                        style: TextStyle(color: const Color(0xFF00FF88).withValues(alpha: 0.8), fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1.7. COMBAT & GAMING ANALYTICS CARD ──────────────────────────────────
  Widget _buildCombatAnalyticsCard(UserLevelingService leveling, Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F0D15),
            Color(0xFF0E0812),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3366).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_martial_arts_rounded, color: Color(0xFFFF3366), size: 20),
              SizedBox(width: 8),
              Text(
                'COMBAT & ARENA ANALYTICS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
              ),
            ],
          ),

          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _statPill('MATCHES PLAYED', '${leveling.totalGamesPlayed}', Icons.videogame_asset_rounded, const Color(0xFF00E5FF)),
              _statPill('WIN RATE', '${leveling.winRate.toStringAsFixed(1)}%', Icons.emoji_events_rounded, const Color(0xFFFFD700)),
              _statPill('TOTAL KILLS', '${leveling.totalKills}', Icons.crisis_alert_rounded, const Color(0xFFFF3366)),
              _statPill('K/D RATIO', leveling.kdRatio.toStringAsFixed(2), Icons.track_changes_rounded, const Color(0xFF00FF88)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String val, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: col, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1.8. DAILY OPERATIVE MISSIONS & BOUNTY HUB ───────────────────────────
  Widget _buildDailyMissionsCard(UserLevelingService leveling, token_provider.TokenProvider tokenProvider, Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF140D26),
            Color(0xFF090616),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFFFB300), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'OPERATIVE DAILY BOUNTIES',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: Color(0xFFFFB300), size: 12),
                    SizedBox(width: 4),
                    Text('RESETS IN 06h:42m', style: TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Mission 1: Arcade Infiltrator
          _buildMissionItem(
            title: 'Arcade Infiltrator',
            description: 'Play 2 games in Gaming Hub',
            progress: 0.5,
            progressText: '1 / 2',
            rewardText: '+350 XP • 1,000 🪙',
            isClaimed: false,
            isReadyToClaim: false,
            onClaim: null,
          ),

          const SizedBox(height: 10),

          // Mission 2: Cipher Comms
          _buildMissionItem(
            title: 'Quantum Transmission',
            description: 'Send 5 encrypted chat messages',
            progress: 1.0,
            progressText: '5 / 5',
            rewardText: '+250 XP • 500 🪙',
            isClaimed: _claimedMission2,
            isReadyToClaim: !_claimedMission2,
            onClaim: () {
              setState(() => _claimedMission2 = true);
              leveling.addXP(250);
              tokenProvider.addTokens(500);
              GameSoundService().playCoin();
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF140D26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  content: const Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700)),
                      SizedBox(width: 8),
                      Text('+250 XP & +500 Tokens Claimed!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Mission 3: Visual Matrix Sync
          _buildMissionItem(
            title: 'Visual Matrix Sync',
            description: 'Equip any sci-fi animation',
            progress: 1.0,
            progressText: '1 / 1',
            rewardText: '+200 XP • 500 🪙',
            isClaimed: _claimedMission3,
            isReadyToClaim: false,
            onClaim: null,
          ),

          const SizedBox(height: 10),

          // Mission 4: Hyper-Streak
          _buildMissionItem(
            title: 'Quantum Hyper-Streak',
            description: 'Maintain 7-day login streak',
            progress: 1.0,
            progressText: '7 / 7',
            rewardText: '+500 XP • 2,000 🪙',
            isClaimed: _claimedMission4,
            isReadyToClaim: false,
            onClaim: null,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionItem({
    required String title,
    required String description,
    required double progress,
    required String progressText,
    required String rewardText,
    required bool isClaimed,
    required bool isReadyToClaim,
    required VoidCallback? onClaim,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReadyToClaim
              ? const Color(0xFFFFB300).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    Text(rewardText, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isClaimed ? const Color(0xFF00FF88) : const Color(0xFFFFB300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progressText,
                      style: TextStyle(
                        color: isClaimed ? const Color(0xFF00FF88) : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isReadyToClaim) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onClaim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.5), blurRadius: 8),
                  ],
                ),
                child: const Text(
                  'CLAIM',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.8),
                ),
              ),
            ),
          ] else if (isClaimed) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 16),
            ),
          ],
        ],
      ),
    );
  }

  // ── 1.9. PRESTIGE SKILL TREE & PERK LOCKER ───────────────────────────────
  Widget _buildPrestigePerksCard(UserLevelingService leveling, Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B1B2B),
            Color(0xFF060F1A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'PRESTIGE SKILL & CYBER PERK MATRIX',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${leveling.activePerks.length} ACTIVE',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _buildPerkRow(
            id: 'overclock_stream',
            icon: Icons.bolt_rounded,
            name: 'Data Stream Overclock',
            reqLevel: 1,
            leveling: leveling,
            benefit: '+15% XP accrual speed from chatting and gaming',
            col: const Color(0xFF00E5FF),
          ),
          _buildPerkRow(
            id: 'quantum_aegis',
            icon: Icons.shield_rounded,
            name: 'Quantum Aegis Matrix',
            reqLevel: 5,
            leveling: leveling,
            benefit: '2.0x Daily bonus token streak multipliers',
            col: const Color(0xFF00FF88),
          ),
          _buildPerkRow(
            id: 'ghost_cloak',
            icon: Icons.visibility_off_rounded,
            name: 'Ghost Cloaking Protocol',
            reqLevel: 15,
            leveling: leveling,
            benefit: 'Zero-trace stealth mode profile & hidden online presence',
            col: const Color(0xFFC084FC),
          ),
          _buildPerkRow(
            id: 'plasma_charge',
            icon: Icons.local_fire_department_rounded,
            name: 'Plasma Overcharge',
            reqLevel: 30,
            leveling: leveling,
            benefit: '3x Arena Combat XP & double victory badges',
            col: const Color(0xFFFF5252),
          ),
          _buildPerkRow(
            id: 'singularity_drive',
            icon: Icons.all_inclusive_rounded,
            name: 'Singularity Warp Drive',
            reqLevel: 50,
            leveling: leveling,
            benefit: 'Instant cooldowns & reality bending quantum field',
            col: const Color(0xFFFF007F),
          ),
          _buildPerkRow(
            id: 'apex_aura',
            icon: Icons.auto_awesome_rounded,
            name: 'Apex Sovereign Core',
            reqLevel: 100,
            leveling: leveling,
            benefit: 'God-tier omnipotent particle glow & prestige nameplate',
            col: const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkRow({
    required String id,
    required IconData icon,
    required String name,
    required int reqLevel,
    required UserLevelingService leveling,
    required String benefit,
    required Color col,
  }) {
    final unlocked = leveling.currentLevel >= reqLevel || leveling.prestigeLevel > 0;
    final isActive = leveling.isPerkActive(id) && unlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () {
          if (!unlocked) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1E0B12),
                content: Text(
                  'Perk Locked! Reach Level $reqLevel or Ascend to engage.',
                  style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
                ),
              ),
            );
            return;
          }
          leveling.togglePerk(id);
          HapticFeedback.mediumImpact();
          GameSoundService().playTick();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? col.withValues(alpha: 0.12) : (unlocked ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.015)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? col.withValues(alpha: 0.6) : (unlocked ? Colors.white24 : Colors.white.withValues(alpha: 0.05)),
              width: isActive ? 1.4 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(color: col.withValues(alpha: 0.2), blurRadius: 10),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive ? col.withValues(alpha: 0.25) : (unlocked ? Colors.white10 : Colors.white.withValues(alpha: 0.04)),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isActive ? col : (unlocked ? Colors.white70 : Colors.white24), size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: unlocked ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? col.withValues(alpha: 0.25)
                                : (unlocked ? Colors.white12 : Colors.white.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? col.withValues(alpha: 0.6) : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : (unlocked ? 'ENGAGE' : 'LVL $reqLevel'),
                            style: TextStyle(
                              color: isActive ? col : (unlocked ? Colors.white70 : Colors.white38),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      benefit,
                      style: TextStyle(color: unlocked ? Colors.white60 : Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1.10. EQUIPPED SCI-FI ARMORY & HOLO-DECKS ────────────────────────────
  Widget _buildEquippedAnimationsShowcase(AnimationProvider ap, Color auraColor) {
    String getAnimName(String? id) {
      if (id == null) return 'Default Aurora';
      final match = AnimationProvider.catalog.where((a) => a.id == id);
      return match.isNotEmpty ? match.first.name : id;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A1028),
            Color(0xFF0C0716),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC084FC).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_motion_rounded, color: Color(0xFFC084FC), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ARMORY & EQUIPPED HOLO-DECKS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/animation-store'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC084FC).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shopping_bag_rounded, color: Color(0xFFC084FC), size: 12),
                      SizedBox(width: 4),
                      Text('STORE', style: TextStyle(color: Color(0xFFC084FC), fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _buildHoloSlot('🏠 Home Screen', getAnimName(ap.equippedHomeAnimation), Icons.home_rounded, const Color(0xFF00E5FF)),
          _buildHoloSlot('🚀 Splash Screen', getAnimName(ap.equippedSplashAnimation), Icons.rocket_launch_rounded, const Color(0xFFFF5252)),
          _buildHoloSlot('👤 Profile Screen', getAnimName(ap.equippedProfileAnimation), Icons.account_circle_rounded, const Color(0xFF00FF88)),
          _buildHoloSlot('🎮 Gaming Hub', getAnimName(ap.equippedGamingHubAnimation), Icons.sports_esports_rounded, const Color(0xFFFFD700)),
          _buildHoloSlot('🛍️ Animation Store', getAnimName(ap.equippedStoreAnimation), Icons.storefront_rounded, const Color(0xFFC084FC)),
        ],
      ),
    );
  }

  Widget _buildHoloSlot(String screen, String animName, IconData icon, Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: col, size: 16),
            const SizedBox(width: 10),
            Text(screen, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: col.withValues(alpha: 0.4)),
              ),
              child: Text(
                animName,
                style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1.11. CYBER CLAN & SYNDICATE SQUADRON ─────────────────────────────────
  Widget _buildSyndicateCard(Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F0E14),
            Color(0xFF0F070C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF2A6D).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2A6D).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_moon_rounded, color: Color(0xFFFF2A6D), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CYBER SYNDICATE & CLAN',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A6D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF2A6D).withValues(alpha: 0.4)),
                ),
                child: const Text('RANK #3 GLOBAL', style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 9.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFF2A6D), Color(0xFF791834)]),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF2A6D).withValues(alpha: 0.4), blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.token_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEO-TOKYO VANGUARD',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tag: [NEX-01] • Tier-1 Mythic Clan',
                      style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '28/30 Operatives Online • 48,920 Clan Honor XP',
                      style: TextStyle(color: Colors.white54, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/gaming-hub');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2A6D).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF2A6D).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech_rounded, color: Color(0xFFFF2A6D), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'ENTER CLAN WAR ROOM & SQUADS',
                    style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1.12. HAPTIC & AUDIO FX ENGINE CONSOLE ────────────────────────────────
  Widget _buildProfileFxCard(Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F1824),
            Color(0xFF080D14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF00FF88), size: 20),
              SizedBox(width: 8),
              Text(
                'CYBER HAPTICS & AUDIO FX ENGINE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Haptic Resonance Level
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Haptic Intensity:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              Row(
                children: ['Low', 'Med', 'High', 'Max'].map((lvl) {
                  final isSel = _hapticLevel == lvl;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _hapticLevel = lvl);
                      HapticFeedback.heavyImpact();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF00FF88) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? const Color(0xFF00FF88) : Colors.white12,
                        ),
                      ),
                      child: Text(
                        lvl,
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Holographic Sheen Switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Holographic Card Sheen', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: const Text('Render dynamic reflective foil on hero badges', style: TextStyle(color: Colors.white38, fontSize: 10)),
            value: _holoSheenEnabled,
            activeThumbColor: const Color(0xFF00FF88),
            onChanged: (val) {
              setState(() => _holoSheenEnabled = val);
              HapticFeedback.selectionClick();
            },
          ),

          // Cyber SFX Audio Switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cyber Audio Feedback', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: const Text('Play interactive sci-fi audio sounds on tap', style: TextStyle(color: Colors.white38, fontSize: 10)),
            value: _cyberSfxEnabled,
            activeThumbColor: const Color(0xFF00FF88),
            onChanged: (val) {
              setState(() => _cyberSfxEnabled = val);
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuraDot(String key, Color color) {
    final isSelected = _auraColor == key;
    return GestureDetector(
      onTap: () {
        setState(() => _auraColor = key);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isSelected ? 22 : 16,
        height: isSelected ? 22 : 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)] : null,
        ),
      ),
    );
  }

  // ── 1.13. OPERATIVE CALL-SIGN & TITLE SELECTOR ─────────────────────────
  Widget _buildOperativeCallSignCard(Color auraColor) {
    const titles = [
      'Quantum Spectre',
      'Cyber Vanguard',
      'Nexus Archon',
      'Zero-Day Phantom',
      'Glitch Hunter',
      'Overclock Sovereign',
      'Solar Sentinel',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'OPERATIVE CALL-SIGN',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.5)),
                ),
                child: Text(
                  _operativeTitle.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select your operative classification displayed across clans, leaderboards, and battle lobbies:',
            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: titles.map((title) {
                final isSelected = _operativeTitle == title;
                return GestureDetector(
                  onTap: () {
                    setState(() => _operativeTitle = title);
                    HapticFeedback.selectionClick();
                    GameSoundService().playHoloEngage();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6)])
                          : null,
                      color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white12,
                        width: isSelected ? 1.2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.35), blurRadius: 8)]
                          : null,
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1.14. OPERATIVE AURA COLOR SELECTOR ─────────────────────────────────
  Widget _buildAuraColorCustomizerCard() {
    final auras = [
      {'id': 'cyan', 'name': 'Cyan Plasma', 'color': const Color(0xFF00E5FF)},
      {'id': 'purple', 'name': 'Neon Violet', 'color': const Color(0xFFC084FC)},
      {'id': 'emerald', 'name': 'Matrix Green', 'color': const Color(0xFF00FF66)},
      {'id': 'gold', 'name': 'Solar Amber', 'color': const Color(0xFFFFD700)},
      {'id': 'flame', 'name': 'Crimson Flare', 'color': const Color(0xFFFF4500)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.blur_on_rounded, color: Color(0xFFB44FFF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'OPERATIVE AURA GLOW',
                    style: TextStyle(
                      color: Color(0xFFB44FFF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _getAuraColor(),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _getAuraColor(), blurRadius: 8)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: auras.map((aura) {
              final id = aura['id'] as String;
              final col = aura['color'] as Color;
              final isSel = _auraColor == id;
              return GestureDetector(
                onTap: () {
                  setState(() => _auraColor = id);
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: isSel ? 0.35 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: isSel ? Colors.white : col.withValues(alpha: 0.5), width: isSel ? 2 : 1),
                    boxShadow: isSel ? [BoxShadow(color: col, blurRadius: 10)] : null,
                  ),
                  child: Center(
                    child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 1.15. DEVICE STORAGE & SCANNER TELEMETRY ────────────────────────────
  Widget _buildDeviceStorageCleanerWidget(Color auraColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C192E), Color(0xFF060D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.cleaning_services_rounded, color: Color(0xFF00FF88), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'DEVICE STORAGE & CLEANER',
                    style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('READY', style: TextStyle(color: Color(0xFF00FF88), fontSize: 9.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Instant device storage scan, temporary cache cleaner, and security audit engine.',
            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(context, FileManagerScreen.routeName);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FF88), Color(0xFF00B0FF)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'LAUNCH DEVICE CLEANER & SCANNER',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Cyber Operative Bio & Transmission Status ────────────────────────
  Widget _buildStatusBioCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF190C33),
            Color(0xFF0F0721),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB44FFF).withValues(alpha: 0.1),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: Color(0xFFB44FFF), size: 18),
                  SizedBox(width: 8),
                  Text('TRANSMISSION STATUS & BIO', style: TextStyle(color: Color(0xFFC084FC), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
              GestureDetector(
                onTap: _showStatusEditDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB44FFF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.4)),
                  ),
                  child: const Text('EDIT', style: TextStyle(color: Color(0xFFB44FFF), fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _userStatusBio,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Preset status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusPresetChip("Available • Online ⚡"),
                _buildStatusPresetChip("In Combat Match 🎮"),
                _buildStatusPresetChip("Overclocking Code 💻"),
                _buildStatusPresetChip("Stealth Protocol 👻"),
                _buildStatusPresetChip("AFK in Hyperspace 🚀"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPresetChip(String text) {
    final isSelected = _userStatusBio == text;
    return GestureDetector(
      onTap: () {
        setState(() => _userStatusBio = text);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB44FFF).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFB44FFF) : Colors.white12),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFB44FFF).withValues(alpha: 0.3), blurRadius: 6)] : null,
        ),
        child: Text(
          text,
          style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500),
        ),
      ),
    );
  }

  // ── 3. Quick Action Buttons Row ─────────────────────────────────────────
  Widget _buildQuickActionButtons(BuildContext context, dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickPill(
          icon: Icons.edit_rounded,
          label: 'Edit Info',
          color: const Color(0xFF00E5FF),
          onTap: () => _showEditProfileDialog(context, Provider.of<AuthService>(context, listen: false)),
        ),
        _buildQuickPill(
          icon: Icons.qr_code_rounded,
          label: 'QR Code',
          color: const Color(0xFFB44FFF),
          onTap: () => _showQrShareDialog(context, user),
        ),
        _buildQuickPill(
          icon: Icons.vpn_key_rounded,
          label: 'Keys',
          color: const Color(0xFFFFD700),
          onTap: () => _showEncryptionDialog(),
        ),
        _buildQuickPill(
          icon: Icons.shield_rounded,
          label: 'Privacy',
          color: const Color(0xFF00FF88),
          onTap: () => _showPrivacySheet(),
        ),
      ],
    );
  }

  Widget _buildQuickPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13092A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── 4. Tokens Treasury Card ─────────────────────────────────────────────
  Widget _buildTokensTreasuryCard(token_provider.TokenProvider tokenProvider, bool bonusAvailable) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'NEX TREASURY',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.5)),
                ),
                child: Text(
                  '🔥 ${tokenProvider.streakCount} DAY STREAK',
                  style: const TextStyle(color: Color(0xFFFF9800), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tokenProvider.isInitialized ? '${tokenProvider.balance} TOKENS' : 'Loading...',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: bonusAvailable
                      ? () {
                          HapticFeedback.mediumImpact();
                          tokenProvider.claimDailyBonus(2500);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Daily reward claimed: +2,500 Tokens!'),
                              backgroundColor: Color(0xFF00A884),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.card_giftcard_rounded, color: Colors.black, size: 18),
                  label: Text(
                    bonusAvailable ? 'CLAIM +2,500' : 'CLAIMED',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF66),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/animation-store');
                  },
                  icon: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF00E5FF), size: 18),
                  label: const Text(
                    'STORE',
                    style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Media, Links & Docs Showcase ─────────────────────────────────────
  Widget _buildMediaShowcaseSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13092A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEDIA, LINKS, & ATTACHMENTS',
                style: TextStyle(color: Color(0xFFC084FC), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFC084FC), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, color: Colors.white38, size: 20),
                SizedBox(width: 8),
                Text('No media transmission logs yet', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. End-to-End Encryption & Security Fingerprint ─────────────────────
  Widget _buildSecurityEncryptionCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13092A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF00E5FF), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End-to-End Quantum Encryption', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('AES-256 GCM • Diffie-Hellman Protocol', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
            ),
            child: const Text(
              'FINGERPRINT :: 9A81-BC02-771E-554A-FF01-0982-3321',
              style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 11, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. Gamer Hall of Fame & Badges ───────────────────────────────────────
  Widget _buildGamerBadgesSection(List<String> profileBadges) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13092A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB800), size: 20),
              SizedBox(width: 8),
              Text('OPERATIVE HALL OF FAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTrophyChip('Combat Master 🏆', const Color(0xFFFF5252)),
              _buildTrophyChip('Matrix Hacker 🟩', const Color(0xFF00FF88)),
              _buildTrophyChip('Cyber Pioneer 🚀', const Color(0xFF00E5FF)),
              _buildTrophyChip('Action Ace ⚡', const Color(0xFFFFD700)),
              _buildTrophyChip('Void Sovereign 🌀', const Color(0xFFB44FFF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // ── 8. Referral Program Card ────────────────────────────────────────────
  Widget _buildReferralProgramCard(String referralLink) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13092A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SYNDICATE RECRUITMENT', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          const Text('Earn 10,000 tokens for each operative who joins NEXDROID with your link!', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                  child: Text(referralLink, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: referralLink));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral link copied!')));
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.black, size: 16),
                label: const Text('COPY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 9. Cyber Notes Card ──────────────────────────────────────────────────
  Widget _buildQuickNotesCard(token_provider.TokenProvider tokenProvider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13092A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENCRYPTED SCRATCHPAD & LOGS', style: TextStyle(color: Color(0xFFC084FC), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 4,
            controller: TextEditingController(text: tokenProvider.quickNotes),
            onChanged: (val) => tokenProvider.updateQuickNotes(val),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Encrypted tactical notes, reminders, mission logs...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF090414),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  String _buildReferralLink(String? uid) {
    final userId = uid ?? 'user_nexus';
    return 'https://nexapp.com/invite?ref=$userId';
  }

  void _showQrShareDialog(BuildContext context, dynamic user) {
    final name = _displayNameForUser(user);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13092A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFB44FFF), width: 1.5)),
        title: Center(child: Text('$name\'s QR Identity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.qr_code_2_rounded, color: Colors.black, size: 160),
            ),
            const SizedBox(height: 14),
            const Text('Scan this QR code to add me on NEXDROID', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF00E5FF)))),
        ],
      ),
    );
  }

  void _showStatusEditDialog() {
    final controller = TextEditingController(text: _userStatusBio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13092A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFB44FFF))),
        title: const Text('Edit Transmission Bio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Status', labelStyle: TextStyle(color: Color(0xFF00E5FF))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              setState(() => _userStatusBio = controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB44FFF), foregroundColor: Colors.white),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13092A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Privacy & Security Protocol', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFFB44FFF)),
              title: const Text('Biometric App Lock', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Require fingerprint/face to unlock NEXDROID', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _biometricLock,
              activeThumbColor: const Color(0xFFB44FFF),
              onChanged: (val) => setState(() => _biometricLock = val),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded, color: Color(0xFF00E5FF)),
              title: const Text('Ghost Cloak Mode', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Hide online telemetry and last seen status', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _stealthMode,
              activeThumbColor: const Color(0xFF00E5FF),
              onChanged: (val) => setState(() => _stealthMode = val),
            ),
          ],
        ),
      ),
    );
  }

  void _showEncryptionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13092A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_rounded, color: Color(0xFFFFD700), size: 48),
            const SizedBox(height: 12),
            const Text('Quantum Encryption Certificate', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Your profile and direct messages are guarded with elliptic curve Diffie-Hellman keys and AES-256 Galois Counter Mode.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
              child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthService authService) {
    _nameController.text = authService.user?.displayName ??
        authService.user?.email?.split('@').first ??
        'Guest Operative';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13092A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFB44FFF))),
        title: const Text('Edit Operative Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFFB44FFF).withValues(alpha: 0.2),
                    backgroundImage: _avatarImageProvider(),
                    child: _selectedImageBytes == null && (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, color: Color(0xFFB44FFF), size: 40)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Display Name', labelStyle: TextStyle(color: Color(0xFF00E5FF))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Username', labelStyle: TextStyle(color: Color(0xFF00E5FF))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Age', labelStyle: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: _isUploading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB44FFF), foregroundColor: Colors.white),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
