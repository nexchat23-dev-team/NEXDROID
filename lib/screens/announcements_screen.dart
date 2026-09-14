import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/announcement_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  static const routeName = '/announcements';
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> with TickerProviderStateMixin {
  final AnnouncementService _service = AnnouncementService();
  String _activeCategory = 'ALL';
  final List<String> _categories = ['ALL', 'UPDATES', 'EVENTS', 'ALERTS', 'SYSTEM'];

  late AnimationController _headerController;
  late AnimationController _refreshController;
  final Set<String> _expandedIds = {};

  final List<Map<String, dynamic>> _demoData = [
    {
      'id': '1',
      'title': 'NEX Core Upgrade Complete',
      'badge': 'SYSTEM',
      'content': 'The central mainframe has been updated to version 12.4. Performance improvements and bug fixes applied across all nodes.',
      'author': 'Admin Zero',
      'pinned': true,
      'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': '2',
      'title': 'Security Breach Attempt Blocked',
      'badge': 'URGENT',
      'content': 'Multiple unauthorized access attempts were blocked at Node 42. No data was compromised. Security protocols are active.',
      'author': 'SecOps Team',
      'pinned': true,
      'createdAt': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': '3',
      'title': 'New Theme Packs Available',
      'badge': 'UPDATE',
      'content': 'We have added 5 new holographic themes to the customization menu. Try them out now in your settings.',
      'author': 'Design Lead',
      'pinned': false,
      'createdAt': DateTime.now().subtract(const Duration(days: 2)),
    },
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _refreshController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _headerController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _refresh() {
    _refreshController.forward(from: 0);
  }

  Color _getBadgeColor(String badge) {
    switch (badge.toUpperCase()) {
      case 'URGENT': return Colors.redAccent;
      case 'IMPORTANT': return Colors.amber;
      case 'SYSTEM': return kNeonPurple;
      case 'UPDATE': return kNeonGreen;
      case 'INFO':
      default: return kNeonBlue;
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) {
      return 'Unknown time';
    }
    DateTime dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      dt = (timestamp).toDate();
    }
    
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      body: Stack(
        children: [
          // Background Grid Pattern
          CustomPaint(
            painter: GridPainter(),
            size: Size.infinite,
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildAnimatedHeader(),
                _buildCategoryTabs(),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _service.getAnnouncements(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: kNeonBlue));
                      }
                      
                      List<Map<String, dynamic>> items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        items = _demoData;
                      }

                      if (_activeCategory != 'ALL') {
                        items = items.where((item) {
                          String badge = item['badge']?.toString().toUpperCase() ?? '';
                          if (_activeCategory == 'ALERTS' && badge == 'URGENT') return true;
                          if (_activeCategory == 'EVENTS' && badge == 'EVENT') return true;
                          return badge == _activeCategory;
                        }).toList();
                      }

                      if (items.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildAnnouncementCard(items[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        backgroundColor: kSurfaceColor,
        child: RotationTransition(
          turns: _refreshController,
          child: const Icon(Icons.sync, color: kNeonBlue),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.white, size: 28),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1B2A65),
                kNeonPurple.withValues(alpha: 0.3),
              ],
              stops: [0.0, 0.5 + 0.5 * (1 + _headerController.value)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kNeonBlue.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: _headerController.value > 0.5 ? 1 : 0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE BROADCAST',
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: _headerController.value > 0.5 ? 1 : 0.5),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'NEX COMMAND\nCENTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.radar, color: Colors.white30, size: 64),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isActive = _activeCategory == category;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? kNeonBlue.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? kNeonBlue : Colors.white24,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive ? [
                  BoxShadow(color: kNeonBlue.withValues(alpha: 0.3), blurRadius: 8)
                ] : [],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isActive ? kNeonBlue : Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> data) {
    final bool isExpanded = _expandedIds.contains(data['id']);
    final bool isPinned = data['pinned'] == true;
    final String badge = data['badge'] ?? 'INFO';
    final Color badgeColor = _getBadgeColor(badge);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedIds.remove(data['id']);
          } else {
            _expandedIds.add(data['id']);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isPinned ? badgeColor.withValues(alpha: 0.5) : Colors.white10),
          boxShadow: [
            BoxShadow(
              color: isPinned ? badgeColor.withValues(alpha: 0.1) : Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.flare, color: badgeColor.withValues(alpha: 0.1), size: 100),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (isPinned)
                              Icon(Icons.push_pin, color: badgeColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(data['createdAt']),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['content'] ?? '',
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: badgeColor.withValues(alpha: 0.3),
                          child: Text(
                            (data['author'] ?? 'S')[0],
                            style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['author'] ?? 'System',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Spacer(),
                        if (isExpanded) ...[
                          IconButton(
                            icon: const Icon(Icons.favorite_border, color: Colors.white54, size: 20),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.bookmark_border, color: Colors.white54, size: 20),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ]
                      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _headerController,
            child: const Icon(Icons.satellite_alt, color: Colors.white24, size: 80),
          ),
          const SizedBox(height: 24),
          const Text(
            'No signals detected',
            style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const double step = 30;
    
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
