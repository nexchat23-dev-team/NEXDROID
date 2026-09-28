import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../services/marketplace_service.dart';
import '../widgets/token_purchase_sheet.dart';
import 'chat_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  static const routeName = '/market';
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceService _marketService = MarketplaceService();

  // Navigation state: 'browse', 'upload', 'myads', 'cart'
  String _currentView = 'browse';
  bool _isGridView = true;

  // Filter state
  String _selectedCategory = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Post Ad Form state
  final TextEditingController _adNameController = TextEditingController();
  final TextEditingController _adPriceController = TextEditingController();
  final TextEditingController _adDescController = TextEditingController();
  String _selectedFormCategory = 'electronics';
  String _selectedDurationKey = '48';
  File? _adMediaFile;
  bool _isAdVideo = false;
  bool _isPublishing = false;
  String _publishStatus = '';

  // Cart state
  List<Map<String, dynamic>> _cartItems = [];

  // Theme colors
  final Color _bgDark = const Color(0xFF060914);
  final Color _surfaceDark = const Color(0xFF0C1226);
  final Color _cyberCyan = const Color(0xFF00E5FF);
  final Color _cyberGreen = const Color(0xFF00FF88);
  final Color _cyberGold = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _adNameController.dispose();
    _adPriceController.dispose();
    _adDescController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    final items = await _marketService.getCartItems();
    if (mounted) setState(() => _cartItems = items);
  }

  Future<void> _addToCart(Map<String, dynamic> ad) async {
    HapticFeedback.mediumImpact();
    await _marketService.addToCart(ad);
    await _loadCart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${ad['productName']}" to Cart'),
        backgroundColor: const Color(0xFF0C1A30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _cyberCyan, width: 1),
        ),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: _cyberCyan,
          onPressed: () => setState(() => _currentView = 'cart'),
        ),
      ),
    );
  }

  Future<void> _removeFromCart(String adId) async {
    HapticFeedback.lightImpact();
    await _marketService.removeFromCart(adId);
    await _loadCart();
  }

  Future<void> _pickMedia() async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov'],
    );
    if (result != null && result.path != null) {
      final p = result.path!;
      final isVideo = p.endsWith('.mp4') || p.endsWith('.mov');
      setState(() {
        _adMediaFile = File(p);
        _isAdVideo = isVideo;
      });
    }
  }

  Future<void> _submitAd(TokenProvider tokenProvider) async {
    final name = _adNameController.text.trim();
    final priceStr = _adPriceController.text.trim();
    final price = double.tryParse(priceStr) ?? 0.0;
    final desc = _adDescController.text.trim();
    final plan = MarketplaceService.durationPlans[_selectedDurationKey]!;

    if (_adMediaFile == null) {
      _showToast('Please select a product photo or video.');
      return;
    }
    if (name.length < 3) {
      _showToast('Product title must be at least 3 characters.');
      return;
    }
    if (price <= 0) {
      _showToast('Please enter a valid price in USD.');
      return;
    }
    if (tokenProvider.balance < plan.tokens) {
      _showToast('Insufficient tokens! Required: ${plan.tokens}, Balance: ${tokenProvider.balance}');
      return;
    }

    setState(() {
      _isPublishing = true;
      _publishStatus = 'Uploading media to NEX-VAULT...';
    });

    try {
      final user = _marketService.currentUser;
      if (user == null) throw Exception('User not signed in');

      final mediaUrl = await _marketService.uploadMedia(
        _adMediaFile!,
        uid: user.uid,
        isVideo: _isAdVideo,
      );

      setState(() => _publishStatus = 'Publishing listing to NEXCHAT Marketplace...');

      await _marketService.publishAdvertisement(
        productName: name,
        productDescription: desc.isNotEmpty ? desc : 'Verified listing on NEXCHAT Market',
        productPrice: price,
        productCategory: _selectedFormCategory,
        imageURL: mediaUrl,
        mediaType: _isAdVideo ? 'video' : 'image',
        durationHours: plan.hours,
        durationTokens: plan.tokens,
      );

      tokenProvider.deductTokens(plan.tokens);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88)),
              SizedBox(width: 8),
              Text('Advertisement live on NEXCHAT Marketplace!'),
            ],
          ),
          backgroundColor: Color(0xFF071C14),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset form
      _adNameController.clear();
      _adPriceController.clear();
      _adDescController.clear();
      _adMediaFile = null;

      setState(() {
        _isPublishing = false;
        _currentView = 'browse';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      _showToast('Failed to post ad: $e');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E0A16),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF2A85)),
        ),
      ),
    );
  }

  void _openChatWithSeller(String sellerUid, String sellerName, String productName) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          participantId: sellerUid,
          participantName: sellerName,
        ),
      ),
    );
  }

  String _formatHoursRemaining(dynamic exp) {
    if (exp == null) return 'Active';
    DateTime? expiryDate;
    if (exp is DateTime) {
      expiryDate = exp;
    } else {
      try {
        expiryDate = exp.toDate();
      } catch (_) {
        expiryDate = DateTime.tryParse(exp.toString());
      }
    }
    if (expiryDate == null) return 'Active';
    final diff = expiryDate.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final hours = diff.inHours;
    if (hours >= 24) {
      return '${(hours / 24).floor()}d left';
    }
    return '${hours}h left';
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = Provider.of<TokenProvider>(context);

    return Scaffold(
      backgroundColor: _bgDark,
      // ── TOP HEADER BAR ───────────────────────────────────────────────────
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00E5FF), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () => setState(() => _currentView = 'browse'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NEXCHAT',
                style: TextStyle(
                  color: _cyberGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _cyberCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MARKET',
                  style: TextStyle(
                    color: _cyberCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Live Token Balance Pill
          InkWell(
            onTap: () => TokenPurchaseSheet.show(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cyberGold.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    '${tokenProvider.balance}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Shopping Cart Header Button with Count Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                onPressed: () => setState(() => _currentView = 'cart'),
                tooltip: 'Shopping Cart',
              ),
              if (_cartItems.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _cyberCyan,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_cartItems.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ── MAIN BODY VIEWS ──────────────────────────────────────────────────
      body: _buildCurrentView(tokenProvider),

      // ── BOTTOM NAVIGATION BAR ────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090D1C),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  viewKey: 'browse',
                  icon: Icons.storefront_rounded,
                  label: 'Explore',
                ),
                _buildBottomNavItem(
                  viewKey: 'upload',
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Post Ad',
                ),
                _buildBottomNavItem(
                  viewKey: 'myads',
                  icon: Icons.receipt_long_rounded,
                  label: 'My Ads',
                ),
                _buildBottomNavItem(
                  viewKey: 'cart',
                  icon: Icons.shopping_bag_outlined,
                  label: 'Cart',
                  badgeCount: _cartItems.length,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required String viewKey,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final active = _currentView == viewKey;
    final color = active ? _cyberCyan : Colors.white54;

    return InkWell(
      onTap: () => setState(() => _currentView = viewKey),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _cyberGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(TokenProvider tokenProvider) {
    switch (_currentView) {
      case 'upload':
        return _buildUploadAdView(tokenProvider);
      case 'myads':
        return _buildMyAdsView();
      case 'cart':
        return _buildCartView();
      case 'browse':
      default:
        return _buildBrowseView();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 1: EXPLORE / BROWSE MARKETPLACE (Exact Port)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBrowseView() {
    return Column(
      children: [
        // ── Search & Grid/List View Controls Row ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white38, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search products, gear, services...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 12.5),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close, color: Colors.white54, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Grid / List Toggle
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: _surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_rounded,
                        color: _isGridView ? _cyberCyan : Colors.white38,
                        size: 18,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isGridView = true),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.view_list_rounded,
                        color: !_isGridView ? _cyberCyan : Colors.white38,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Category Filter Chips (Horizontally Scrollable) ──────────────────
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: MarketplaceService.categories.length,
            itemBuilder: (_, idx) {
              final cat = MarketplaceService.categories[idx];
              final catId = cat['id'] as String;
              final isSelected = _selectedCategory == catId;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'] as IconData, size: 13, color: isSelected ? Colors.black : Colors.white70),
                      const SizedBox(width: 4),
                      Text(cat['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: _cyberGreen,
                  backgroundColor: _surfaceDark,
                  side: BorderSide(
                    color: isSelected ? _cyberGreen : Colors.white.withValues(alpha: 0.08),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = catId);
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // ── Live Stream of Advertisements ────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _marketService.getActiveAdsStream(
              category: _selectedCategory,
              searchQuery: _searchQuery,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final ads = snapshot.data ?? [];

              if (ads.isEmpty) {
                return _buildEmptyState();
              }

              if (_isGridView) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: ads.length,
                  itemBuilder: (_, idx) => _buildProductGridCard(ads[idx]),
                );
              } else {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  itemCount: ads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) => _buildProductListCard(ads[idx]),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _cyberGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_rounded, color: _cyberGreen, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty ? 'No Matching Products' : 'No Listings in this Category',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search keyword.'
                  : 'Be the first seller to broadcast an item in this category!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentView = 'upload'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('POST AN AD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyberGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGridCard(Map<String, dynamic> ad) {
    final name = ad['productName']?.toString() ?? 'Product';
    final price = (ad['productPrice'] as num?)?.toDouble() ?? 0.0;
    final img = ad['imageURL']?.toString() ?? '';
    final isVideo = ad['mediaType'] == 'video';
    final seller = ad['sellerUsername']?.toString() ?? 'NEX User';
    final remaining = _formatHoursRemaining(ad['expiresAt']);

    return InkWell(
      onTap: () => _showProductDetailSheet(ad),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Image Thumbnail
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      child: img.isNotEmpty
                          ? Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF10162B),
                                child: const Icon(Icons.broken_image, color: Colors.white24),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF10162B),
                              child: const Icon(Icons.image_not_supported, color: Colors.white24),
                            ),
                    ),
                  ),

                  // Media Type Badge (Video)
                  if (isVideo)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.play_arrow, color: Color(0xFF00FF88), size: 12),
                            SizedBox(width: 2),
                            Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  // Remaining Time Chip
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        remaining,
                        style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Meta Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(color: _cyberGreen, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'by $seller',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                  const SizedBox(height: 8),

                  // Actions: Add to Cart & Chat
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _addToCart(ad),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _cyberCyan,
                            side: BorderSide(color: _cyberCyan.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_shopping_cart, size: 12),
                              SizedBox(width: 3),
                              Text('Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _openChatWithSeller(
                          ad['sellerUID'] ?? '',
                          ad['sellerUsername'] ?? 'Seller',
                          name,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _cyberGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, color: _cyberGreen, size: 14),
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

  Widget _buildProductListCard(Map<String, dynamic> ad) {
    final name = ad['productName']?.toString() ?? 'Product';
    final price = (ad['productPrice'] as num?)?.toDouble() ?? 0.0;
    final img = ad['imageURL']?.toString() ?? '';
    final seller = ad['sellerUsername']?.toString() ?? 'NEX User';
    final remaining = _formatHoursRemaining(ad['expiresAt']);

    return InkWell(
      onTap: () => _showProductDetailSheet(ad),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 74,
                height: 74,
                child: img.isNotEmpty
                    ? Image.network(img, fit: BoxFit.cover)
                    : Container(color: Colors.white10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text('by $seller • $remaining', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('\$${price.toStringAsFixed(2)}', style: TextStyle(color: _cyberGreen, fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_shopping_cart, color: _cyberCyan, size: 20),
              onPressed: () => _addToCart(ad),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 2: POST ADVERTISEMENT FORM (Exact Port)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildUploadAdView(TokenProvider tokenProvider) {
    final selectedPlan = MarketplaceService.durationPlans[_selectedDurationKey]!;
    final user = _marketService.currentUser;
    final userHasEnough = tokenProvider.balance >= selectedPlan.tokens;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cyberGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: _cyberGreen, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post an Advertisement',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Broadcast your item or service to all active NEXCHAT users.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 1. Product Media
          const Text('Product Photo or Video *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickMedia,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _adMediaFile != null ? _cyberGreen : Colors.white24,
                  style: BorderStyle.solid,
                ),
              ),
              child: _adMediaFile != null
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: _isAdVideo
                                ? Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(Icons.movie_filter_rounded, color: Color(0xFF00FF88), size: 48),
                                    ),
                                  )
                                : Image.file(_adMediaFile!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => setState(() => _adMediaFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: _cyberCyan, size: 36),
                        const SizedBox(height: 8),
                        const Text('Tap to upload product media', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('JPG, PNG, WebP, MP4 (Max 50MB)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // 2. Title
          const Text('Product / Service Title *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildFormTextField(
            controller: _adNameController,
            hint: 'e.g. Cyberpunk Mechanical Keyboard RGB',
            maxLength: 100,
          ),

          const SizedBox(height: 12),

          // 3. Category Dropdown
          const Text('Category *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFormCategory,
                dropdownColor: _surfaceDark,
                isExpanded: true,
                items: MarketplaceService.categories
                    .where((c) => c['id'].toString().isNotEmpty)
                    .map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Row(
                      children: [
                        Icon(c['icon'] as IconData, color: _cyberCyan, size: 16),
                        const SizedBox(width: 8),
                        Text(c['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFormCategory = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Price (USD)
          const Text('Price (USD) *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildFormTextField(
            controller: _adPriceController,
            hint: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '\$ ',
          ),

          const SizedBox(height: 12),

          // 5. Description
          const Text('Description', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildFormTextField(
            controller: _adDescController,
            hint: 'Detail condition, features, pickup or delivery options...',
            maxLines: 3,
            maxLength: 500,
          ),

          const SizedBox(height: 14),

          // 6. Duration Plan & Token Fee (Exact 4 Cards)
          const Text('Advertisement Duration & Token Fee', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Column(
            children: MarketplaceService.durationPlans.entries.map((entry) {
              final planKey = entry.key;
              final plan = entry.value;
              final isSelected = _selectedDurationKey == planKey;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDurationKey = planKey);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? _cyberGreen.withValues(alpha: 0.12) : _surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _cyberGreen : Colors.white12,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? _cyberGreen : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(plan.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? _cyberGreen.withValues(alpha: 0.25) : Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      plan.badge,
                                      style: TextStyle(
                                        color: isSelected ? _cyberGreen : Colors.white54,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${plan.tokens} Tokens',
                              style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Token Verification Info Box
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: userHasEnough ? _cyberGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: userHasEnough ? _cyberGreen.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  userHasEnough ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: userHasEnough ? _cyberGreen : Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userHasEnough
                        ? 'Balance verified: ${tokenProvider.balance} Tokens available (${selectedPlan.tokens} Tokens will be deducted upon posting).'
                        : 'Insufficient tokens! You need ${selectedPlan.tokens} tokens, but have ${tokenProvider.balance}.',
                    style: TextStyle(
                      color: userHasEnough ? _cyberGreen : Colors.redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Auto-filled Seller Meta
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Seller Account: ${user?.displayName ?? user?.email ?? 'NEX User'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isPublishing ? null : () => _submitAd(tokenProvider),
              icon: _isPublishing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(
                _isPublishing ? _publishStatus : 'PUBLISH ADVERTISEMENT',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyberGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText,
          prefixStyle: TextStyle(color: _cyberGreen, fontWeight: FontWeight.bold, fontSize: 14),
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
          border: InputBorder.none,
          counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 3: MY ADVERTISEMENTS (Exact Port)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMyAdsView() {
    final uid = _marketService.currentUserId ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Listings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Track views, expiry time, and manage products', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentView = 'upload'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Ad'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyberGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _marketService.getMyAdsStream(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }
              final ads = snapshot.data ?? [];
              if (ads.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 48),
                      SizedBox(height: 10),
                      Text('No listings yet', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Tap "New Ad" to post your first product', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, idx) {
                  final ad = ads[idx];
                  final name = ad['productName'] ?? 'Listing';
                  final price = (ad['productPrice'] as num?)?.toDouble() ?? 0.0;
                  final views = ad['views'] ?? 0;
                  final remaining = _formatHoursRemaining(ad['expiresAt']);
                  final img = ad['imageURL']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: img.isNotEmpty
                                ? Image.network(img, fit: BoxFit.cover)
                                : Container(color: Colors.white10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 3),
                              Text('\$${price.toStringAsFixed(2)} • $remaining', style: TextStyle(color: _cyberGreen, fontSize: 12)),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.visibility_outlined, color: Colors.white38, size: 12),
                                  const SizedBox(width: 4),
                                  Text('$views views', style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            final conf = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: _surfaceDark,
                                title: const Text('Delete Listing?', style: TextStyle(color: Colors.white)),
                                content: const Text('Are you sure you want to remove this advertisement?', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            );
                            if (conf == true) {
                              await _marketService.deleteAd(ad['id']);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 4: SHOPPING CART (Exact Port)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCartView() {
    if (_cartItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_shopping_cart_outlined, color: Colors.white38, size: 54),
              const SizedBox(height: 12),
              const Text('Your cart is empty', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Explore the marketplace and tap "Add to Cart" on items you like', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentView = 'browse'),
                icon: const Icon(Icons.storefront, size: 16),
                label: const Text('Explore Marketplace'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyberGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double subtotal = 0.0;
    for (final item in _cartItems) {
      final p = (item['productPrice'] as num?)?.toDouble() ?? 0.0;
      subtotal += p;
    }
    final fee = subtotal * 0.02; // 2% Escrow fee
    final total = subtotal + fee;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, idx) {
              final item = _cartItems[idx];
              final name = item['productName'] ?? 'Item';
              final price = (item['productPrice'] as num?)?.toDouble() ?? 0.0;
              final img = item['imageURL']?.toString() ?? '';
              final seller = item['sellerUsername']?.toString() ?? 'Seller';

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: img.isNotEmpty
                            ? Image.network(img, fit: BoxFit.cover)
                            : Container(color: Colors.white12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Seller: $seller', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          Text('\$${price.toStringAsFixed(2)}', style: TextStyle(color: _cyberGreen, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _removeFromCart(item['id']),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Cart Summary & Checkout
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceDark,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(color: Colors.white70)),
                  Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Platform Escrow Fee (2%):', style: TextStyle(color: Colors.white70)),
                  Text('\$${fee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('\$${total.toStringAsFixed(2)}', style: TextStyle(color: _cyberGreen, fontWeight: FontWeight.w900, fontSize: 17)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Connect with first seller
                    if (_cartItems.isNotEmpty) {
                      final first = _cartItems.first;
                      _openChatWithSeller(
                        first['sellerUID'] ?? '',
                        first['sellerUsername'] ?? 'Seller',
                        first['productName'] ?? '',
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat & Purchase from Seller'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyberGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 5: PRODUCT DETAIL SHEET (Modal Overlay)
  // ═══════════════════════════════════════════════════════════════════════════
  void _showProductDetailSheet(Map<String, dynamic> ad) {
    _marketService.incrementView(ad['id']);

    final name = ad['productName']?.toString() ?? 'Product';
    final price = (ad['productPrice'] as num?)?.toDouble() ?? 0.0;
    final desc = ad['productDescription']?.toString() ?? 'No description provided.';
    final cat = ad['productCategory']?.toString() ?? 'Other';
    final img = ad['imageURL']?.toString() ?? '';
    final seller = ad['sellerUsername']?.toString() ?? 'Verified Seller';
    final sellerUid = ad['sellerUID']?.toString() ?? '';
    final remaining = _formatHoursRemaining(ad['expiresAt']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF080D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Hero Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 240,
                      child: img.isNotEmpty
                          ? Image.network(img, fit: BoxFit.cover)
                          : Container(color: Colors.white10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: TextStyle(color: _cyberGreen, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Badges: Category & Expiry
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cyberCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cat.toUpperCase(),
                          style: TextStyle(color: _cyberCyan, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white54, size: 12),
                            const SizedBox(width: 4),
                            Text(remaining, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text('Description', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),

                  const SizedBox(height: 20),

                  // Verified Seller Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _cyberGreen.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: _cyberGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified, color: Color(0xFF00FF88), size: 13),
                                  SizedBox(width: 4),
                                  Text('Verified Seller', style: TextStyle(color: Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(seller, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('UID: $sellerUid', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons: Chat & Add to Cart
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openChatWithSeller(sellerUid, seller, name);
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text('Chat with Seller'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cyberGreen,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _addToCart(ad);
                            },
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Add to Cart'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _cyberCyan,
                              side: BorderSide(color: _cyberCyan, width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
