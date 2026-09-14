import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_sound_service.dart';
import '../services/user_leveling_service.dart';

// ============================================================
// CINEMATIC LEVEL UP CELEBRATION MODAL
// ============================================================
class CinematicLevelUpDialog extends StatefulWidget {
  final int newLevel;
  final int? oldLevel;

  const CinematicLevelUpDialog({
    super.key,
    required this.newLevel,
    this.oldLevel,
  });

  static Future<void> show(BuildContext context, int newLevel, {int? oldLevel}) async {
    GameSoundService().playLevelUp();
    HapticFeedback.heavyImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LevelUp',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (ctx, anim1, anim2) => CinematicLevelUpDialog(
        newLevel: newLevel,
        oldLevel: oldLevel,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<CinematicLevelUpDialog> createState() => _CinematicLevelUpDialogState();
}

class _CinematicLevelUpDialogState extends State<CinematicLevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _vortexController;
  late AnimationController _pulseController;
  late AnimationController _badgeController;

  @override
  void initState() {
    super.initState();
    _vortexController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _vortexController.dispose();
    _pulseController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leveling = UserLevelingService.instance;
    final rankColor = leveling.rankColor;
    final rankTitle = leveling.rankTitle;
    final rankIcon = leveling.rankIcon;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: min(MediaQuery.of(context).size.width * 0.9, 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF140C2C), Color(0xFF070B18), Color(0xFF04060E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: rankColor.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.35),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Rotating Sci-Fi Particle Vortex Background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _vortexController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _VortexCelebrationPainter(
                        angle: _vortexController.value * 2 * pi,
                        pulse: _pulseController.value,
                        primaryColor: rankColor,
                      ),
                    );
                  },
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Banner: LEVEL REACHED
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [rankColor.withValues(alpha: 0.3), Colors.transparent],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rankColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: rankColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          widget.newLevel >= 9999 ? 'MAX OPERATIVE ASCENSION' : 'OPERATIVE LEVEL UP!',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Center Holographic Crest
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsing Aura
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: rankColor.withValues(alpha: 0.4 + _pulseController.value * 0.3),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        // Hexagon / Circle Crest Base
                        Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                rankColor.withValues(alpha: 0.35),
                                const Color(0xFF0E1326),
                              ],
                            ),
                            border: Border.all(color: rankColor, width: 2.5),
                          ),
                          child: Center(
                            child: Icon(rankIcon, color: rankColor, size: 52),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Level Number Big Text
                  Text(
                    'LEVEL ${widget.newLevel}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 36,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: rankColor.withValues(alpha: 0.8), blurRadius: 20),
                        const Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Rank Title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rankTitle,
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Rewards & Unlocked Perks Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1429).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildRewardItem(Icons.bolt_rounded, 'Neural Core Overclock', leveling.coreClockSpeed, rankColor),
                        const SizedBox(height: 8),
                        _buildRewardItem(Icons.shield_rounded, 'Kinetic Shielding Output', leveling.kineticShielding, const Color(0xFF00E5FF)),
                        const SizedBox(height: 8),
                        _buildRewardItem(Icons.auto_awesome_rounded, 'Reality Distortion Singularity', leveling.realityDistortion, const Color(0xFF00FF88)),
                        const SizedBox(height: 8),
                        _buildRewardItem(Icons.token_rounded, 'Anomalous Power Multiplier', leveling.anomalousPower, const Color(0xFFFFD700)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Claim / Continue Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: rankColor,
                        foregroundColor: Colors.black,
                        elevation: 10,
                        shadowColor: rankColor.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text(
                        'CONTINUE CONQUEST',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String title, String desc, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
              Text(desc, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// LEVELING ROADMAP FULLSCREEN SHOWCASE (1 ➔ 9999)
// ============================================================
class LevelingRoadmapModal extends StatelessWidget {
  const LevelingRoadmapModal({super.key});

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    GameSoundService().playHoloEngage();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LevelingRoadmapModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leveling = UserLevelingService.instance;
    final currentLvl = leveling.currentLevel;

    final milestones = [
      _Milestone(9999, 'NEXUS SINGULARITY (MAX)', 'Infinite Holo Aura, God-Tier Prestige Title, Ultimate Cyber Crown', const Color(0xFFFF00FF), Icons.all_inclusive_rounded),
      _Milestone(9000, 'ETERNAL COSMOS ARCHITECT', 'Radiant Celestial Flare, 50x Combat Multiplier', const Color(0xFFFFD700), Icons.auto_awesome_rounded),
      _Milestone(7500, 'INFINITE REALITY WEAVER', 'Reality Warp Shield, 40x Token Payout', const Color(0xFFFFD700), Icons.star_purple500_rounded),
      _Milestone(6000, 'SUPREME MULTIVERSE GOD', 'Multiverse Plasma Beam, 30x Token Boost', const Color(0xFF00FFFF), Icons.whatshot_rounded),
      _Milestone(4500, 'DIMENSIONAL DOMINATOR', 'Interdimensional Matrix Aura, 20x Combat Boost', const Color(0xFF00FFFF), Icons.stars_rounded),
      _Milestone(3000, 'CHRONO-LORD OF TIME', 'Time Warp Vortex Skin, 15x Token Multiplier', const Color(0xFFFF3366), Icons.local_fire_department_rounded),
      _Milestone(2000, 'STELLAR SOVEREIGN TITAN', 'Titan Shielding Badge, 10x XP Rate', const Color(0xFFE040FB), Icons.workspace_premium_rounded),
      _Milestone(1000, 'OMNIPOTENT DEITY', 'Gold Deity Halo, 8x Token Yield', const Color(0xFFE040FB), Icons.diamond_rounded),
      _Milestone(500, 'TRANSCENDENT EMPEROR', 'Crimson Shockwave, 5x Match Bonus', const Color(0xFFFF0055), Icons.military_tech_rounded),
      _Milestone(250, 'QUANTUM SOVEREIGN', 'Purple Quantum Singularity Badge', const Color(0xFFB44FFF), Icons.shield_rounded),
      _Milestone(100, 'APEX PHANTOM', 'Apex Emerald Cyber Tag', const Color(0xFF00FF88), Icons.bolt_rounded),
      _Milestone(50, 'TACTICAL WARRIOR', 'Tactical Cyan Glow & Battle Callout', const Color(0xFF00D4FF), Icons.shield_moon_rounded),
      _Milestone(15, 'ELITE OPERATIVE', 'Blue Cyber Badge & +1000 Token Welcome', const Color(0xFF3B82F6), Icons.military_tech_rounded),
      _Milestone(1, 'NOVICE RECRUIT', 'Starting Operative Station', const Color(0xFF94A3B8), Icons.person_rounded),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF060914),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OPERATIVE ASCENSION ROADMAP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Level 1 ➔ 9,999 Unlimited Progression',
                      style: TextStyle(color: const Color(0xFF00E5FF).withValues(alpha: 0.8), fontSize: 11),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: leveling.rankColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: leveling.rankColor),
                  ),
                  child: Text(
                    'YOU: LVL $currentLvl',
                    style: TextStyle(color: leveling.rankColor, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // Milestone list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: milestones.length,
              itemBuilder: (context, index) {
                final m = milestones[index];
                final isUnlocked = currentLvl >= m.level;
                final isNextTarget = !isUnlocked && (index == milestones.length - 1 || currentLvl >= milestones[index + 1].level);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? m.color.withValues(alpha: 0.12)
                        : (isNextTarget ? const Color(0xFF101830) : const Color(0xFF0A0F1E)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isUnlocked
                          ? m.color.withValues(alpha: 0.6)
                          : (isNextTarget ? const Color(0xFF00E5FF).withValues(alpha: 0.6) : Colors.white10),
                      width: isUnlocked || isNextTarget ? 1.5 : 1,
                    ),
                    boxShadow: isUnlocked
                        ? [BoxShadow(color: m.color.withValues(alpha: 0.15), blurRadius: 10)]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked ? m.color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: isUnlocked ? m.color : Colors.white24),
                        ),
                        child: Center(
                          child: Icon(
                            isUnlocked ? m.icon : Icons.lock_outline_rounded,
                            color: isUnlocked ? m.color : Colors.white38,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  m.title,
                                  style: TextStyle(
                                    color: isUnlocked ? Colors.white : Colors.white60,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isUnlocked ? m.color : Colors.white12).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'LVL ${m.level}',
                                    style: TextStyle(
                                      color: isUnlocked ? m.color : Colors.white54,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.perks,
                              style: TextStyle(
                                color: isUnlocked ? m.color : Colors.white38,
                                fontSize: 10.5,
                                height: 1.3,
                              ),
                            ),
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
}

class _Milestone {
  final int level;
  final String title;
  final String perks;
  final Color color;
  final IconData icon;

  _Milestone(this.level, this.title, this.perks, this.color, this.icon);
}

// ============================================================
// VORTEX CELEBRATION PAINTER
// ============================================================
class _VortexCelebrationPainter extends CustomPainter {
  final double angle;
  final double pulse;
  final Color primaryColor;

  _VortexCelebrationPainter({
    required this.angle,
    required this.pulse,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    final radius = size.width * 0.42;

    // Glowing energy ring
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15 + pulse * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.7, ringPaint);

    // Orbital particles
    for (int i = 0; i < 8; i++) {
      final pAngle = angle + (i * pi / 4);
      final px = center.dx + cos(pAngle) * radius;
      final py = center.dy + sin(pAngle) * radius;

      final pPaint = Paint()
        ..color = primaryColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(px, py), 4.0, pPaint);
      canvas.drawCircle(Offset(px, py), 2.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _VortexCelebrationPainter old) => true;
}
