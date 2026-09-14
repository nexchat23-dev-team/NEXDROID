import 'package:flutter/material.dart';

import '../services/backend_service.dart';
import 'bet_screen.dart';
import 'marketplace_screen.dart';
import 'settings_screen.dart';
import '../utils/constants.dart';

class AdvertisementScreen extends StatefulWidget {
  static const routeName = '/advertisements';
  const AdvertisementScreen({super.key});

  @override
  State<AdvertisementScreen> createState() => _AdvertisementScreenState();
}

class _AdvertisementScreenState extends State<AdvertisementScreen> {
  Stream<List<Map<String, dynamic>>> get _adsStream {
    return SupabaseService.client
        .from('advertisements')
        .stream(primaryKey: ['id'])
        .order('createdAt', ascending: false);
  }

  final List<Map<String, dynamic>> _sampleAds = [
    {
      'id': 'sample1',
      'title': 'Welcome Bonus Campaign',
      'description':
          'Launch a special offer to onboard new members with token rewards and premium perks.',
      'type': 'promo',
      'cta': 'View Offer',
      'expires': '2d left',
    },
    {
      'id': 'sample2',
      'title': 'VIP Tournament Invite',
      'description':
          'Invite top players to join your exclusive gaming tournament and reward high performers.',
      'type': 'event',
      'cta': 'Join Now',
      'expires': '1w left',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628), // Professional Deep Navy
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1E36),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kNeonBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kNeonBlue.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, color: kNeonBlue, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kNeonBlue, kNeonBlue.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: kNeonBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.campaign_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Marketplace Ads',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
          ],
        ),
        actions: [
          _buildAppBarButton(
            icon: Icons.filter_list_rounded,
            color: kNeonBlue,
            onTap: () => _showFilterDialog(context),
          ),
          _buildAppBarButton(
            icon: Icons.add_rounded,
            color: kNeonGreen,
            onTap: () => _showCreateAdDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kNeonBlue,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Ad',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () => _showCreateAdDialog(context),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildAdsList(_sampleAds,
                errorMessage: 'Live feed unavailable. Showing local ads.');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: kNeonBlue,
                strokeWidth: 3,
              ),
            );
          }

          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return _buildEmptyAdsState();
          }

          final ads = docs.map((doc) {
            return {
              'id': doc['id']?.toString() ?? 'unknown',
              'title': doc['title'] ?? 'Exclusive Deal',
              'description': doc['description'] ?? 'No description provided.',
              'type': doc['type'] ?? 'promo',
              'cta': doc['cta'] ?? 'View Details',
              'expires': doc['expires'],
            };
          }).toList();

          return _buildAdsList(ads);
        },
      ),
    );
  }

  // Professional helper for AppBar action buttons
  Widget _buildAppBarButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      width: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final Color adColor = _getAdTypeColor(ad['type'] as String);
    final IconData adIcon = _getAdTypeIcon(ad['type'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF13233B), // Solid base for professional look
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: adColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Gradient Backdrop
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [adColor.withValues(alpha: 0.15), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: adColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(adIcon, color: adColor, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: adColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getAdTypeLabel(ad['type'] as String).toUpperCase(),
                            style: TextStyle(
                              color: adColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ad['expires'] != null)
                    _buildExpiryBadge(ad['expires'] as String),
                ],
              ),
            ),
            // Body Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                ad['description'] as String,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // Call to Action Area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleAdAction(ad),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [adColor, adColor.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: adColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        ad['cta'] as String,
                        style: const TextStyle(
                          color: Colors
                              .black, // High contrast for professional accessibility
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryBadge(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on_rounded, color: Colors.redAccent, size: 14),
          const SizedBox(width: 4),
          Text(
            time,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsList(List<Map<String, dynamic>> ads, {String? errorMessage}) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: kNeonBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            20, 20, 20, 100), // Extra bottom padding for FAB
        itemCount: ads.length + (errorMessage != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (errorMessage != null && index == 0) {
            return _buildErrorBanner(errorMessage);
          }
          final adIndex = errorMessage != null ? index - 1 : index;
          return _buildAdCard(ads[adIndex]);
        },
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAdsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 80, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 24),
            const Text(
              'Marketplace is Quiet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to promote something to the NEX community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAdDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final ctaController = TextEditingController();
    final expiresController = TextEditingController();
    String selectedType = 'promo';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: kNeonBlue.withValues(alpha: 0.2)),
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kNeonBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_chart_rounded,
                              color: kNeonBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'New Advertisement',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('AD TITLE'),
                    _buildStyledTextField(
                        titleController, 'e.g., Summer Token Sale'),
                    const SizedBox(height: 16),
                    _buildInputLabel('DESCRIPTION'),
                    _buildStyledTextField(
                        descriptionController, 'What is your ad about?',
                        maxLines: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('BUTTON TEXT'),
                              _buildStyledTextField(
                                  ctaController, 'e.g., Claim Now'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('EXPIRY (OPTIONAL)'),
                              _buildStyledTextField(
                                  expiresController, 'e.g., 2 days left'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel('CAMPAIGN CATEGORY'),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: const Color(0xFF0D1E36),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: kNeonBlue),
                      decoration: _inputDecoration(''),
                      items: const [
                        DropdownMenuItem(
                            value: 'promo', child: Text('Promotion')),
                        DropdownMenuItem(
                            value: 'sale', child: Text('Flash Sale')),
                        DropdownMenuItem(
                            value: 'subscription', child: Text('Premium/VIP')),
                        DropdownMenuItem(
                            value: 'referral', child: Text('Referral Program')),
                        DropdownMenuItem(
                            value: 'event', child: Text('Tournament/Event')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => selectedType = value);
                      },
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: kNeonBlue.withValues(alpha: 0.4),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        final cta = ctaController.text.trim();

                        if (title.isEmpty || description.isEmpty || cta.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Please fill in the required fields.'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        _createAd({
                          'title': title,
                          'description': description,
                          'cta': cta,
                          'type': selectedType,
                          'expires': expiresController.text.trim().isEmpty
                              ? null
                              : expiresController.text.trim(),
                          'createdAt': DateTime.now().toUtc().toIso8601String(),
                        });

                        Navigator.pop(context);
                      },
                      child: const Text(
                        'PUBLISH ADVERT',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper for professional labels
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
            color: kNeonBlue.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2),
      ),
    );
  }

  // Helper for modern TextFields
  Widget _buildStyledTextField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0A1628),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: kNeonBlue, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _createAd(Map<String, dynamic> adData) async {
    try {
      await SupabaseService.client.from('advertisements').insert(adData).select();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Advert published to live feed.'),
          backgroundColor: kNeonBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getAdTypeColor(String type) {
    // Keeping your logic: everything is kNeonBlue but using consistent reference
    return kNeonBlue;
  }

  IconData _getAdTypeIcon(String type) {
    switch (type) {
      case 'promo':
        return Icons.card_giftcard_rounded;
      case 'subscription':
        return Icons.auto_awesome_rounded;
      case 'sale':
        return Icons.local_offer_rounded;
      case 'referral':
        return Icons.people_alt_rounded;
      case 'event':
        return Icons.emoji_events_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _getAdTypeLabel(String type) {
    switch (type) {
      case 'promo':
        return 'PROMOTION';
      case 'subscription':
        return 'PREMIUM';
      case 'sale':
        return 'FLASH SALE';
      case 'referral':
        return 'REFERRAL';
      case 'event':
        return 'EVENT';
      default:
        return 'ADVERT';
    }
  }

  void _handleAdAction(Map<String, dynamic> ad) {
    switch (ad['type']) {
      case 'promo':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claiming ${ad['title']}...'),
            backgroundColor: kNeonBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 'subscription':
        Navigator.pushNamed(context, SettingsScreen.routeName);
        break;
      case 'sale':
        Navigator.pushNamed(context, MarketplaceScreen.routeName);
        break;
      case 'referral':
        _showReferralDialog(context);
        break;
      case 'event':
        Navigator.pushNamed(context, BettingScreen.routeName);
        break;
    }
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1E36),
      elevation: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Campaign Filters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a category to refine your feed',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildFilterOption('All Campaigns', true, Icons.grid_view_rounded),
            _buildFilterOption(
                'Promotions', false, Icons.card_giftcard_rounded),
            _buildFilterOption('Flash Sales', false, Icons.local_offer_rounded),
            _buildFilterOption(
                'Tournaments', false, Icons.emoji_events_rounded),
            _buildFilterOption('Referrals', false, Icons.people_alt_rounded),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, bool isActive, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? kNeonBlue.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? kNeonBlue.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: isActive ? kNeonBlue : Colors.white38, size: 22),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (isActive)
                  const Icon(Icons.check_circle_rounded,
                      color: kNeonBlue, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReferralDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: kNeonBlue.withValues(alpha: 0.2)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kNeonBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(Icons.share_rounded, color: kNeonBlue, size: 22),
            ),
            const SizedBox(width: 16),
            const Text(
              'Invite & Earn',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get your friends on NEX and receive 200 bonus tokens instantly when they join!',
              style:
                  TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            Text(
              'YOUR UNIQUE LINK',
              style: TextStyle(
                color: kNeonBlue.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kNeonBlue.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'nexchat.com/ref/user123',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kNeonBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'MAYBE LATER',
              style: TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonBlue,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Referral link copied!'),
                    backgroundColor: kNeonBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('COPY LINK',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
} // End of _AdvertisementScreenState
