import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/animation_provider.dart';
import '../providers/token_provider.dart';
import '../widgets/scifi_animations.dart';

class AnimationStoreScreen extends StatefulWidget {
  static const String routeName = '/animation-store';
  const AnimationStoreScreen({super.key});

  @override
  State<AnimationStoreScreen> createState() => _AnimationStoreScreenState();
}

class _AnimationStoreScreenState extends State<AnimationStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AnimationProvider>();
    final tp = context.watch<TokenProvider>();
    final equippedStoreId = ap.equippedStoreAnimation;

    const allAnims = AnimationProvider.catalog;
    final owned = allAnims.where((a) => ap.isOwned(a.id)).toList();
    final equipped = allAnims.where((a) => ap.getScreensEquipped(a.id).isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF03030F),
      body: Stack(
        children: [
          // Dynamic space star background or equipped sci-fi animation
          Positioned.fill(
            child: equippedStoreId != null
                ? buildSciFiAnimation(equippedStoreId)
                : CustomPaint(painter: _StoreBgPainter()),
          ),
          if (equippedStoreId != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'SCI-FI CUSTOMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'UNIVERSAL ANIMATION SUITES',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Token Balance Widget
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFD700),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Color(0xFFFFD700), blurRadius: 6),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${tp.balance}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs Navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF0088FF)],
                            ),
                          ),
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.white60,
                          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                          tabs: [
                            Tab(text: 'ALL (${allAnims.length})'),
                            Tab(text: 'OWNED (${owned.length})'),
                            Tab(text: 'ACTIVE (${equipped.length})'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGrid(allAnims, ap),
                      _buildGrid(owned, ap, emptyMsg: 'Unlock premium animations from the catalog.'),
                      _buildGrid(equipped, ap, emptyMsg: 'No animation equipped as home or splash background.'),
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

  Widget _buildGrid(List<SciFiAnimationModel> anims, AnimationProvider ap, {String? emptyMsg}) {
    if (anims.isEmpty) {
      return Center(
        child: Text(
          emptyMsg ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: anims.length,
      itemBuilder: (context, i) => _buildAnimCard(anims[i], ap),
    );
  }

  Widget _buildAnimCard(SciFiAnimationModel anim, AnimationProvider ap) {
    final isOwned = ap.isOwned(anim.id);
    final equippedScreens = ap.getScreensEquipped(anim.id);
    final isEquipped = equippedScreens.isNotEmpty;

    return GestureDetector(
      onTap: () {
        // Navigate directly to the individual Dart screen for this animation
        Navigator.pushNamed(context, anim.routeName);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isEquipped ? anim.glowColor : Colors.white.withValues(alpha: 0.08),
                width: isEquipped ? 1.8 : 1.0,
              ),
              boxShadow: isEquipped
                  ? [
                      BoxShadow(
                        color: anim.glowColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                      )
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon placeholder (Stylized glowing dots representing animation core)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: anim.glowColor,
                          boxShadow: [
                            BoxShadow(color: anim.glowColor, blurRadius: 8, spreadRadius: 1),
                          ],
                        ),
                      ),
                      if (isEquipped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: anim.glowColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: anim.glowColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            equippedScreens.length > 1 ? 'EQUIPPED (${equippedScreens.length})' : 'ACTIVE',
                            style: TextStyle(
                              color: anim.glowColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else if (isOwned)
                        Text(
                          'OWNED',
                          style: TextStyle(
                            color: anim.glowColor.withValues(alpha: 0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        )
                      else
                        Text(
                          anim.price == 0 ? 'FREE' : '${anim.price ~/ 1000}k TOKENS',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    anim.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Movie description
                  Text(
                    anim.movie.toUpperCase(),
                    style: TextStyle(
                      color: anim.glowColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF03030F));
    final rng = Random(12345);
    // Draw stars
    final starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final sizeStar = rng.nextDouble() * 1.2;
      canvas.drawCircle(Offset(x, y), sizeStar, starPaint..color = Colors.white.withValues(alpha: rng.nextDouble() * 0.7 + 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
