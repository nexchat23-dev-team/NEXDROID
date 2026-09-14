import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../providers/animation_provider.dart';
import '../../providers/token_provider.dart';
import '../../services/game_sound_service.dart';
import '../../widgets/scifi_animations.dart';

/// Shared full-screen detail scaffold used by all 20 individual animation screens.
class SciFiDetailScreen extends StatefulWidget {
  final String animationId;
  const SciFiDetailScreen({super.key, required this.animationId});

  @override
  State<SciFiDetailScreen> createState() => _SciFiDetailScreenState();
}

class _SciFiDetailScreenState extends State<SciFiDetailScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _gyroSub;
  double _gyroX = 0;
  double _gyroY = 0;
  bool _panelExpanded = true;
  late AnimationController _panelCtrl;
  late Animation<double> _panelAnim;

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _panelAnim = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeInOut);
    _panelCtrl.forward();
    _startGyro();
  }

  void _startGyro() {
    _gyroSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _gyroX = (event.x / 10).clamp(-1.0, 1.0);
        _gyroY = (event.y / 10).clamp(-1.0, 1.0);
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _panelCtrl.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() => _panelExpanded = !_panelExpanded);
    if (_panelExpanded) {
      _panelCtrl.forward();
    } else {
      _panelCtrl.reverse();
    }
  }

  void _playPreviewSound(String id) {
    final sound = GameSoundService();
    switch (id) {
      case 'cosmic_zoom_bigbang':
      case 'interstellar_wormhole':
      case 'tesseract_cascade':
        sound.playHyperspace();
        break;
      case 'alien_invasion_ship':
      case 'predator_cloak':
      case 'xenomorph_shadow':
        sound.playAlienBeam();
        break;
      case 'shooting_stars_field':
        sound.playShootingStar();
        break;
      case 'warship_beam_cannon':
      case 'iron_man_arc':
        sound.playSuperLaser();
        break;
      case 'space_battle_war':
      case 'optimus_transform':
      case 'district9_mech':
        sound.playSpaceBattle();
        break;
      case 'lightsaber_duel':
        sound.playSlash();
        break;
      case 'terminator_endoskeleton':
      case 'robocop_hud':
        sound.playSniper();
        break;
      default:
        sound.playHoloEngage();
    }
  }

  void _handleBuy(SciFiAnimationModel anim, AnimationProvider ap, TokenProvider tp) {
    if (tp.balance < anim.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A0020),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Insufficient tokens. Need ${anim.price - tp.balance} more.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0C0C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: anim.glowColor.withValues(alpha: 0.5), width: 1.5),
          ),
          title: Text(
            anim.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(anim.movie, style: TextStyle(color: anim.glowColor, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Purchase for ${anim.price} tokens?', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: anim.glowColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: anim.glowColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your balance:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    Text('${tp.balance} tokens', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final ok = ap.purchaseAnimation(anim.id, anim.price, tp);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF001A10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    content: Text('${anim.name} unlocked!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ));
                  setState(() {});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: anim.glowColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Confirm — ${anim.price} Tokens',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEquip(SciFiAnimationModel anim, AnimationProvider ap) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          decoration: const BoxDecoration(
            color: Color(0xEE0A0A1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: Colors.white24, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: anim.glowColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.palette_rounded, color: anim.glowColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Equip ${anim.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select any screen or equip to all screens at once',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
              const SizedBox(height: 16),

              // 👑 GLOBAL EQUIP BUTTON (All Screens)
              GestureDetector(
                onTap: () {
                  ap.equipAllScreens(anim.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    _successSnack('👑 Equipped ${anim.name} to ALL screens globally!'),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        anim.glowColor.withValues(alpha: 0.35),
                        anim.accentColor.withValues(alpha: 0.25),
                        const Color(0xFF6366F1).withValues(alpha: 0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: anim.glowColor.withValues(alpha: 0.7), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: anim.glowColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: anim.glowColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'APPLY TO ALL SCREENS (GLOBAL)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Sets this live animation across the entire app ecosystem',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Individual Screens Grid
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _equipTile(
                        label: 'Home Screen',
                        icon: Icons.home_rounded,
                        color: anim.glowColor,
                        active: ap.isEquippedHome(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'home');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Home Screen'));
                        },
                      ),
                      _equipTile(
                        label: 'Splash Screen',
                        icon: Icons.play_arrow_rounded,
                        color: anim.accentColor,
                        active: ap.isEquippedSplash(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'splash');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Splash Screen'));
                        },
                      ),
                      _equipTile(
                        label: 'Profile Screen',
                        icon: Icons.person_rounded,
                        color: const Color(0xFF00E5FF),
                        active: ap.isEquippedProfile(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'profile');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Profile Screen'));
                        },
                      ),
                      _equipTile(
                        label: 'Gaming Hub',
                        icon: Icons.sports_esports_rounded,
                        color: const Color(0xFF00FF88),
                        active: ap.isEquippedGamingHub(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'gaming_hub');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Gaming Hub'));
                        },
                      ),
                      _equipTile(
                        label: 'Animation Store',
                        icon: Icons.storefront_rounded,
                        color: const Color(0xFFB44FFF),
                        active: ap.isEquippedStore(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'store');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Animation Store'));
                        },
                      ),
                      _equipTile(
                        label: 'Chat Screen',
                        icon: Icons.chat_bubble_rounded,
                        color: const Color(0xFFFF9800),
                        active: ap.isEquippedChat(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'chat');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Chat Screen'));
                        },
                      ),
                      _equipTile(
                        label: 'Chat List',
                        icon: Icons.forum_rounded,
                        color: const Color(0xFF00FFC2),
                        active: ap.isEquippedChatList(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'chat_list');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Chat List Screen'));
                        },
                      ),
                      _equipTile(
                        label: 'Settings',
                        icon: Icons.settings_rounded,
                        color: const Color(0xFFFF4081),
                        active: ap.isEquippedSettings(anim.id),
                        onTap: () {
                          ap.equipAnimation(anim.id, 'settings');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(_successSnack('Equipped to Settings'));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _equipTile({
    required String label,
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.22) : const Color(0xFF13132B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.white12,
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (active)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      Text(
                        active ? 'Active' : 'Apply',
                        style: TextStyle(
                          color: active ? color : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _successSnack(String msg) => SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF001A10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AnimationProvider>();
    final tp = context.watch<TokenProvider>();
    final anim = AnimationProvider.catalog.firstWhere(
      (a) => a.id == widget.animationId,
      orElse: () => AnimationProvider.catalog.first,
    );
    final isOwned = ap.isOwned(anim.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen animation
          Positioned.fill(
            child: buildSciFiAnimation(anim.id, gyroX: _gyroX, gyroY: _gyroY),
          ),

          // Gyro hint
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _panelExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Tilt device to interact with the animation',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const Spacer(),
                    // Sound FX Preview Button
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _playPreviewSound(anim.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF0F172A),
                            duration: const Duration(seconds: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: Row(
                              children: [
                                Icon(Icons.volume_up_rounded, color: anim.glowColor, size: 18),
                                const SizedBox(width: 8),
                                Text('Playing ${anim.name} Sound FX', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.volume_up_rounded, color: anim.glowColor),
                      tooltip: 'Play Sci-Fi Sound FX',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Panel toggle
                    IconButton(
                      onPressed: _togglePanel,
                      icon: Icon(
                        _panelExpanded ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom info panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _panelAnim,
              builder: (_, __) {
                return Transform.translate(
                  offset: Offset(0, 320 * (1 - _panelAnim.value)),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          border: Border(
                            top: BorderSide(color: anim.glowColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drag handle
                            GestureDetector(
                              onTap: _togglePanel,
                              child: Center(
                                child: Container(
                                  width: 44,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Movie source badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: anim.glowColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: anim.glowColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                anim.movie.toUpperCase(),
                                style: TextStyle(
                                  color: anim.glowColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Title
                            Text(
                              anim.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Description
                            Text(
                              anim.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Status row
                            Row(
                              children: [
                                _statusChip('HOME', ap.isEquippedHome(anim.id), anim.glowColor),
                                const SizedBox(width: 8),
                                _statusChip('SPLASH', ap.isEquippedSplash(anim.id), anim.accentColor),
                                const Spacer(),
                                if (!isOwned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: anim.glowColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: anim.glowColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      '${anim.price} TOKENS',
                                      style: TextStyle(
                                        color: anim.glowColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Action button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: isOwned
                                  ? ElevatedButton.icon(
                                      onPressed: () => _handleEquip(anim, ap),
                                      icon: const Icon(Icons.check_circle_rounded),
                                      label: const Text('EQUIP ANIMATION',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: anim.glowColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () => _handleBuy(anim, ap, tp),
                                      icon: const Icon(Icons.lock_open_rounded),
                                      label: Text('UNLOCK FOR ${anim.price} TOKENS',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: tp.balance >= anim.price
                                            ? anim.glowColor
                                            : Colors.grey.shade800,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.white24,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? color : Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
