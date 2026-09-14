import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../services/token_purchase_service.dart';
import '../utils/constants.dart';

class TokenPurchaseSheet extends StatefulWidget {
  final TokenPackage? initialPackage;
  final int? initialAmount;
  final bool initialIsSell;

  const TokenPurchaseSheet({
    super.key,
    this.initialPackage,
    this.initialAmount,
    this.initialIsSell = false,
  });

  static Future<void> show(
    BuildContext context, {
    TokenPackage? package,
    int? customAmount,
    bool isSell = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TokenPurchaseSheet(
        initialPackage: package,
        initialAmount: customAmount,
        initialIsSell: isSell,
      ),
    );
  }

  @override
  State<TokenPurchaseSheet> createState() => _TokenPurchaseSheetState();
}

class _TokenPurchaseSheetState extends State<TokenPurchaseSheet> {
  late TokenPackage _selectedPackage;
  bool _isCustom = false;
  final TextEditingController _customController = TextEditingController();
  int _customTokens = 10000;

  @override
  void initState() {
    super.initState();
    if (widget.initialPackage != null) {
      _selectedPackage = widget.initialPackage!;
    } else if (widget.initialAmount != null) {
      _isCustom = true;
      _customTokens = widget.initialAmount!;
      _customController.text = widget.initialAmount.toString();
      _selectedPackage = TokenPurchaseService.standardPackages.first;
    } else {
      _selectedPackage = TokenPurchaseService.standardPackages[1]; // Pro bundle
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = Provider.of<TokenProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final int activeTokens = _isCustom ? _customTokens : _selectedPackage.tokenAmount;
    final double activePrice = _isCustom
        ? TokenPurchaseService.estimatePriceForCustomTokens(_customTokens)
        : _selectedPackage.priceUsd;
    final String activePackageName = _isCustom ? 'Custom ($activeTokens Tokens)' : _selectedPackage.title;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF0C091A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF00B8F4), width: 1.5),
          left: BorderSide(color: Colors.white12),
          right: BorderSide(color: Colors.white12),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3300B8F4),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B8F4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00B8F4).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.generating_tokens_rounded,
                    color: Color(0xFF00B8F4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BUY NEX TOKENS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text(
                          'Rate: 10,000 Tokens = \$1.00 • ',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF229ED9).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '@Vershdit',
                            style: TextStyle(
                              color: Color(0xFF29B6F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white10),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: Colors.white54, size: 18),
                            SizedBox(width: 8),
                            Text('Your Token Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        Text(
                          '${tokenProvider.balance} Tokens',
                          style: const TextStyle(
                            color: kNeonGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // BUY MODE CONTENT
                    const Text(
                      'SELECT TOKEN PACKAGE (10,000 TOKENS = \$1.00)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Standard Packages
                    ...TokenPurchaseService.standardPackages.map((pkg) {
                      final isSelected = !_isCustom && _selectedPackage.id == pkg.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustom = false;
                            _selectedPackage = pkg;
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? pkg.color.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? pkg.color : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: pkg.color.withValues(alpha: 0.25), blurRadius: 15)]
                                : [],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: pkg.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(pkg.icon, color: pkg.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          pkg.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (pkg.badge != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: pkg.color.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: pkg.color.withValues(alpha: 0.6), width: 0.8),
                                            ),
                                            child: Text(
                                              pkg.badge!,
                                              style: TextStyle(
                                                color: pkg.color,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 8.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${pkg.formattedAmount} Tokens • ${pkg.subtitle}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? pkg.color : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  pkg.formattedPrice,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Custom Amount Option
                    GestureDetector(
                      onTap: () {
                        setState(() => _isCustom = true);
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(top: 2, bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isCustom
                              ? const Color(0xFF00B8F4).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isCustom ? const Color(0xFF00B8F4) : Colors.white.withValues(alpha: 0.08),
                            width: _isCustom ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B8F4).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF00B8F4), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Custom Token Amount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '10,000 Tokens = \$1.00 USD',
                                        style: TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isCustom)
                                  Text(
                                    '\$${activePrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF00B8F4),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                            if (_isCustom) ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: _customController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 50000',
                                  hintStyle: const TextStyle(color: Colors.white30),
                                  suffixText: 'TOKENS',
                                  suffixStyle: const TextStyle(color: Color(0xFF00B8F4), fontWeight: FontWeight.w900),
                                  filled: true,
                                  fillColor: Colors.black38,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00B8F4))),
                                ),
                                onChanged: (val) {
                                  final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                                  final amount = int.tryParse(clean) ?? 0;
                                  setState(() => _customTokens = amount);
                                },
                              ),
                            ],
                          ],
                    ),
                  ),
                ),

                  const SizedBox(height: 12),

                  // Telegram Order Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF229ED9).withValues(alpha: 0.15),
                          const Color(0xFF00B8F4).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.telegram, color: Color(0xFF29B6F6), size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'How Purchasing Works',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '1. Select package or custom amount (10,000 tokens = \$1.00 USD).\n'
                          '2. Tap "ORDER ON TELEGRAM" to message @Vershdit with pre-filled details.\n'
                          '3. Complete payment and tokens will be credited instantly!',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0B22),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$activeTokens TOKENS',
                        style: const TextStyle(
                          color: Color(0xFF00B8F4),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Total: \$${activePrice.toStringAsFixed(2)} USD',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: activeTokens > 0
                      ? () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          await TokenPurchaseService.launchTelegramOrder(
                            context: context,
                            tokenAmount: activeTokens,
                            packageName: activePackageName,
                            priceUsd: activePrice,
                            isSell: false,
                            payoutMethod: null,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'ORDER ON TELEGRAM',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF229ED9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
