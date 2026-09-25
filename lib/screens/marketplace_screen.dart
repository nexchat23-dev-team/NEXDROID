import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/token_provider.dart';
import '../services/token_purchase_service.dart';
import '../utils/constants.dart';
import '../widgets/token_purchase_sheet.dart';

class MarketplaceScreen extends StatefulWidget {
  static const routeName = '/market';
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> with TickerProviderStateMixin {
  final TextEditingController promoController = TextEditingController();
  String promoMessage = '';
  late TabController _tabController;
  late AnimationController _bgAnimationController;
  Set<String> _ownedCosmetics = {};
  Set<String> _activePowerUps = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadUserInventory();
  }

  Future<void> _loadUserInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getStringList('owned_marketplace_items') ?? [];
    final powerUps = prefs.getStringList('active_power_ups') ?? [];
    if (mounted) {
      setState(() {
        _ownedCosmetics = owned.toSet();
        _activePowerUps = powerUps.toSet();
      });
    }
  }

  Future<void> _saveCosmetic(String title) async {
    final prefs = await SharedPreferences.getInstance();
    _ownedCosmetics.add(title);
    await prefs.setStringList('owned_marketplace_items', _ownedCosmetics.toList());
    if (mounted) setState(() {});
  }

  Future<void> _savePowerUp(String title) async {
    final prefs = await SharedPreferences.getInstance();
    _activePowerUps.add(title);
    await prefs.setStringList('active_power_ups', _activePowerUps.toList());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    promoController.dispose();
    _tabController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  void redeemPromo(TokenProvider tokenProvider) {
    final code = promoController.text.trim().toUpperCase();
    if (code == 'NEXBONUS') {
      tokenProvider.addTokens(5000);
      setState(() {
        promoMessage = 'Promo applied: 5,000 free tokens added!';
      });
    } else if (code == 'MEGABOOST') {
      tokenProvider.addTokens(12000);
      setState(() {
        promoMessage = 'Promo applied: 12,000 free tokens added!';
      });
    } else {
      setState(() {
        promoMessage = 'Invalid promo code. Try NEXBONUS or MEGABOOST.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = Provider.of<TokenProvider>(context);

    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NEX Marketplace',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Buy Tokens via Telegram',
            icon: const Icon(Icons.generating_tokens_rounded, color: Color(0xFF00B8F4)),
            onPressed: () => TokenPurchaseSheet.show(context),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Animated Starfield Background
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return CustomPaint(
                painter: StarfieldPainter(_bgAnimationController.value),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                // Hero Balance Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kSurfaceColor, kSurfaceColor.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: kNeonBlue.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(color: kNeonBlue.withValues(alpha: 0.15), blurRadius: 25, spreadRadius: 2),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR TOKEN BALANCE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: tokenProvider.balance),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Text(
                                value.toString().replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (m) => '${m[1]},',
                                    ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  shadows: [BoxShadow(color: kNeonBlue, blurRadius: 12)],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: () => TokenPurchaseSheet.show(context),
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                        label: const Text(
                          'TOP UP',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF229ED9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Official Seller Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.telegram, color: Color(0xFF29B6F6), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Token orders redirect to official seller @Vershdit on Telegram',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton(
                        onPressed: () => TokenPurchaseSheet.show(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'BUY NOW',
                          style: TextStyle(color: Color(0xFF29B6F6), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: kNeonBlue,
                  labelColor: kNeonBlue,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'TOKEN PACKS'),
                    Tab(text: 'COSMETICS'),
                    Tab(text: 'POWER-UPS'),
                  ],
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTokenPacks(tokenProvider),
                      _buildCosmetics(tokenProvider),
                      _buildPowerUps(tokenProvider),
                    ],
                  ),
                ),

                // Promo Code Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: kSurfaceColor.withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(top: BorderSide(color: kNeonBlue.withValues(alpha: 0.2))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: promoController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter Promo Code (e.g. NEXBONUS)',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kNeonBlue)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => redeemPromo(tokenProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kNeonBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          )
                        ],
                      ),
                      if (promoMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            promoMessage,
                            style: TextStyle(
                              color: promoMessage.contains('Invalid') ? Colors.redAccent : kNeonGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
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

  Widget _buildTokenPacks(TokenProvider tokenProvider) {
    final packages = TokenPurchaseService.standardPackages;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: packages.length + 1,
      itemBuilder: (context, index) {
        if (index == packages.length) {
          // Custom Token Order Card
          return _buildStoreItem(
            title: 'Custom Token Order',
            subtitle: 'Order any specific token amount via Telegram',
            price: 'Custom',
            accentColor: const Color(0xFF00B8F4),
            icon: Icons.tune_rounded,
            onBuy: () => TokenPurchaseSheet.show(context, customAmount: 50000),
          );
        }

        final pack = packages[index];
        return _buildStoreItem(
          title: pack.title,
          subtitle: '${pack.formattedAmount} tokens • ${pack.subtitle}',
          price: pack.formattedPrice,
          badge: pack.badge,
          accentColor: pack.color,
          icon: pack.icon,
          onBuy: () => TokenPurchaseSheet.show(context, package: pack),
        );
      },
    );
  }

  Widget _buildCosmetics(TokenProvider tokenProvider) {
    final items = [
      {'title': 'Neon Avatar Frame', 'price': 500, 'color': kNeonBlue, 'icon': Icons.account_box},
      {'title': 'Cyberpunk Chat Theme', 'price': 1500, 'color': kNeonPurple, 'icon': Icons.chat},
      {'title': 'Gold Name Color', 'price': 2500, 'color': Colors.amber, 'icon': Icons.format_paint},
      {'title': 'Elite Profile Badge', 'price': 5000, 'color': Colors.redAccent, 'icon': Icons.verified},
      {'title': 'Matrix Particle Trail', 'price': 8000, 'color': kNeonGreen, 'icon': Icons.auto_awesome},
      {'title': 'Cyber Dragon Banner', 'price': 15000, 'color': const Color(0xFFFF3366), 'icon': Icons.shield_rounded},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final title = item['title'] as String;
        final price = item['price'] as int;
        final isOwned = _ownedCosmetics.contains(title);

        return _buildStoreItem(
          title: title,
          subtitle: isOwned ? 'UNLOCKED / EQUIPPED' : 'Cosmetic Upgrade',
          price: isOwned ? 'OWNED' : '$price Tokens',
          accentColor: item['color'] as Color,
          icon: item['icon'] as IconData,
          isPurchased: isOwned,
          onBuy: isOwned
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title is already equipped on your profile!'),
                      backgroundColor: kNeonBlue,
                    ),
                  );
                }
              : () async {
                  if (tokenProvider.balance >= price) {
                    tokenProvider.deductTokens(price);
                    await _saveCosmetic(title);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully purchased & equipped $title!'),
                          backgroundColor: kNeonGreen,
                        ),
                      );
                    }
                  } else {
                    _showInsufficientTokensPrompt(context, price);
                  }
                },
        );
      },
    );
  }

  Widget _buildPowerUps(TokenProvider tokenProvider) {
    final items = [
      {'title': 'Double XP (24h)', 'price': 500, 'color': Colors.orange, 'icon': Icons.trending_up},
      {'title': 'Lucky Boost (10 Games)', 'price': 800, 'color': Colors.green, 'icon': Icons.casino},
      {'title': 'Energy Shield', 'price': 1200, 'color': Colors.cyan, 'icon': Icons.shield},
      {'title': 'Auto-Claim Bot (7 Days)', 'price': 2500, 'color': Colors.purple, 'icon': Icons.smart_toy},
      {'title': 'VIP High-Roller Pass', 'price': 6000, 'color': Colors.amber, 'icon': Icons.workspace_premium},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final title = item['title'] as String;
        final price = item['price'] as int;
        final isActive = _activePowerUps.contains(title);

        return _buildStoreItem(
          title: title,
          subtitle: isActive ? 'ACTIVE BOOST' : 'Consumable Boost',
          price: isActive ? 'ACTIVE' : '$price Tokens',
          accentColor: item['color'] as Color,
          icon: item['icon'] as IconData,
          isPurchased: isActive,
          onBuy: isActive
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title is already active!'),
                      backgroundColor: kNeonBlue,
                    ),
                  );
                }
              : () async {
                  if (tokenProvider.balance >= price) {
                    tokenProvider.deductTokens(price);
                    await _savePowerUp(title);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Activated $title! ⚡'),
                          backgroundColor: kNeonGreen,
                        ),
                      );
                    }
                  } else {
                    _showInsufficientTokensPrompt(context, price);
                  }
                },
        );
      },
    );
  }

  void _showInsufficientTokensPrompt(BuildContext context, int needed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.toll_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Need More Tokens', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'You need $needed tokens for this purchase. Would you like to buy tokens on Telegram via official seller @Vershdit?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              TokenPurchaseSheet.show(context, customAmount: needed);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Buy via Telegram'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF229ED9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItem({
    required String title,
    required String subtitle,
    required String price,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onBuy,
    String? badge,
    bool isPurchased = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPurchased ? kNeonGreen.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onBuy,
          splashColor: accentColor.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentColor.withValues(alpha: 0.8), accentColor]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.35), blurRadius: 8)],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 0.6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 8),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPurchased
                        ? kNeonGreen.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPurchased ? kNeonGreen : accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    price,
                    style: TextStyle(
                      color: isPurchased ? kNeonGreen : accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StarfieldPainter extends CustomPainter {
  final double animationValue;
  StarfieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final random = math.Random(42);

    for (int i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final yOffset = random.nextDouble() * size.height;
      final speed = random.nextDouble() * 0.5 + 0.1;

      final y = (yOffset + (animationValue * size.height * speed)) % size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;

      paint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.5 + 0.2);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => true;
}
