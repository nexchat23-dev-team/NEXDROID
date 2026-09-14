import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_service.dart';

class TokenPackage {
  final String id;
  final String title;
  final String subtitle;
  final int tokenAmount;
  final double priceUsd;
  final Color color;
  final IconData icon;
  final String? badge;
  final int bonusPercent;

  const TokenPackage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tokenAmount,
    required this.priceUsd,
    required this.color,
    required this.icon,
    this.badge,
    this.bonusPercent = 0,
  });

  String get formattedPrice => '\$${priceUsd.toStringAsFixed(2)}';
  String get formattedAmount => tokenAmount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

class TokenPurchaseService {
  static const String telegramUsername = 'Vershdit';
  static const String telegramUrl = 'https://t.me/$telegramUsername';

  // Base Rate: 10,000 Tokens = $1.00 USD
  static const List<TokenPackage> standardPackages = [
    TokenPackage(
      id: 'starter',
      title: 'Starter Pack',
      subtitle: 'Great for casual gaming & mini-bets',
      tokenAmount: 10000,
      priceUsd: 1.00,
      color: Color(0xFF43E97B),
      icon: Icons.flash_on_rounded,
    ),
    TokenPackage(
      id: 'pro',
      title: 'Pro Bundle',
      subtitle: 'Unlock multiplayer & high stakes',
      tokenAmount: 50000,
      priceUsd: 5.00,
      color: Color(0xFF00B8F4),
      icon: Icons.bolt_rounded,
      badge: 'POPULAR (+5% BONUS)',
      bonusPercent: 5,
    ),
    TokenPackage(
      id: 'elite',
      title: 'Elite Pack',
      subtitle: 'Best value for active operatives',
      tokenAmount: 100000,
      priceUsd: 10.00,
      color: Color(0xFFB23BFF),
      icon: Icons.military_tech_rounded,
      badge: '+10% BONUS',
      bonusPercent: 10,
    ),
    TokenPackage(
      id: 'master',
      title: 'Master Pack',
      subtitle: 'Heavy stakes, vault games & sci-fi skins',
      tokenAmount: 250000,
      priceUsd: 25.00,
      color: Color(0xFFFF9800),
      icon: Icons.workspace_premium_rounded,
      badge: '+20% BONUS',
      bonusPercent: 20,
    ),
    TokenPackage(
      id: 'champion',
      title: 'Grand Champion',
      subtitle: 'Dominate arenas & sci-fi galaxy stores',
      tokenAmount: 500000,
      priceUsd: 50.00,
      color: Color(0xFFFF3366),
      icon: Icons.diamond_rounded,
      badge: '+30% BONUS',
      bonusPercent: 30,
    ),
    TokenPackage(
      id: 'whale',
      title: 'Ultimate Whale',
      subtitle: 'Maximum VIP prestige & infinite play',
      tokenAmount: 1000000,
      priceUsd: 100.00,
      color: Color(0xFFFFD700),
      icon: Icons.stars_rounded,
      badge: '+50% MEGA BONUS',
      bonusPercent: 50,
    ),
  ];

  static double estimatePriceForCustomTokens(int tokenAmount) {
    if (tokenAmount <= 0) return 0.0;
    // 10,000 tokens = $1.00 USD
    return tokenAmount / 10000.0;
  }

  static double estimatePayoutForSellingTokens(int tokenAmount) {
    if (tokenAmount <= 0) return 0.0;
    // 10,000 tokens = $1.00 USD payout
    return tokenAmount / 10000.0;
  }

  static String generateOrderRef({bool isSell = false}) {
    final prefix = isSell ? 'NEX-SELL' : 'NEX-BUY';
    final hex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    return '$prefix-$hex';
  }

  static String buildOrderMessage({
    required int tokenAmount,
    String? packageName,
    double? priceUsd,
    String? orderRef,
  }) {
    final user = FirebaseService.auth.currentUser;
    final username = user?.displayName ?? (user?.email?.split('@').first) ?? 'NEX User';
    final uid = user?.uid ?? 'GUEST-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
    final orderId = orderRef ?? generateOrderRef();
    final price = priceUsd ?? estimatePriceForCustomTokens(tokenAmount);
    final formattedTokens = tokenAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return '''
🔥 NEX TOKEN PURCHASE ORDER 🔥
━━━━━━━━━━━━━━━━━━━━
👤 User: $username (UID: $shortUid)
📦 Package: ${packageName ?? 'Custom Token Order'}
🪙 Token Amount: $formattedTokens Tokens (Rate: 10,000 = \$1.00)
💵 Price Total: \$${price.toStringAsFixed(2)} USD
🆔 Order Ref: $orderId
━━━━━━━━━━━━━━━━━━━━
Hello @$telegramUsername! I would like to buy $formattedTokens tokens for my NEX account. Please send payment instructions!''';
  }

  static String buildSellOrderMessage({
    required int tokenAmount,
    double? payoutUsd,
    String? orderRef,
    String? payoutMethod,
  }) {
    final user = FirebaseService.auth.currentUser;
    final username = user?.displayName ?? (user?.email?.split('@').first) ?? 'NEX User';
    final uid = user?.uid ?? 'GUEST-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
    final orderId = orderRef ?? generateOrderRef(isSell: true);
    final payout = payoutUsd ?? estimatePayoutForSellingTokens(tokenAmount);
    final formattedTokens = tokenAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return '''
💰 NEX TOKEN CASHOUT / SELL ORDER 💰
━━━━━━━━━━━━━━━━━━━━
👤 Operative: $username (UID: $shortUid)
🪙 Tokens to Sell: $formattedTokens Tokens
💵 Payout Value: \$${payout.toStringAsFixed(2)} USD (Rate: 10,000 = \$1.00)
💳 Payout Method: ${payoutMethod ?? 'Crypto (USDT/TON) / Bank / PayPal'}
🆔 Cashout Ref: $orderId
━━━━━━━━━━━━━━━━━━━━
Hello @$telegramUsername! I would like to sell/cash out $formattedTokens NEX Tokens for \$${payout.toStringAsFixed(2)} USD. Please verify my order and send payout instructions!''';
  }

  static Future<bool> launchTelegramOrder({
    required BuildContext context,
    required int tokenAmount,
    String? packageName,
    double? priceUsd,
    String? orderRef,
    bool isSell = false,
    String? payoutMethod,
  }) async {
    final orderId = orderRef ?? generateOrderRef(isSell: isSell);
    final message = isSell
        ? buildSellOrderMessage(
            tokenAmount: tokenAmount,
            payoutUsd: priceUsd,
            orderRef: orderId,
            payoutMethod: payoutMethod,
          )
        : buildOrderMessage(
            tokenAmount: tokenAmount,
            packageName: packageName,
            priceUsd: priceUsd,
            orderRef: orderId,
          );

    final encodedText = Uri.encodeComponent(message);
    final telegramAppUri = Uri.parse('https://t.me/$telegramUsername?text=$encodedText');

    try {
      final launched = await launchUrl(
        telegramAppUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        final webUri = Uri.parse('https://telegram.me/$telegramUsername?text=$encodedText');
        final webLaunched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (!webLaunched) {
          await Clipboard.setData(ClipboardData(text: message));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Order copied to clipboard! Message @Vershdit on Telegram.',
                ),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return false;
        }
      }
      return true;
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order details copied! Reach out to @$telegramUsername on Telegram.',
            ),
            backgroundColor: const Color(0xFF00B8F4),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }
}
