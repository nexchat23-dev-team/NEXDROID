import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../screens/video_post_screen.dart';
import '../services/ai_service.dart';
import '../services/reel_service.dart';
import '../utils/constants.dart';

class VideoFeedScreen extends StatefulWidget {
  static const routeName = '/video-feed';
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _discAnim;
  late AnimationController _equalizerAnim;
  late AnimationController _heartBurstAnim;
  String _selectedCategory = 'For You';
  int _currentPage = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _reelsSubscription;

  // Double-tap heart particles
  final List<_FloatingHeart> _floatingHearts = [];

  final List<String> _categories = const ['For You', 'Trending', 'Gaming', 'Music', 'Tech', 'Comedy'];

  static final List<Map<String, dynamic>> _curatedTemplates = [
    {
      'id': 'template_1',
      'username': 'alex_creates',
      'avatar': 'A',
      'category': 'Music',
      'title': 'Studio Session Drop',
      'description': 'Fresh synth beats recorded live in the NEX audio engine. Sound on!',
      'hashtags': '#beats #nexreels #synthwave',
      'soundTrack': 'Alex Creates • Cyber Midnight Mix',
      'likes': 14250,
      'comments': 942,
      'shares': 310,
      'saves': 187,
      'views': 89400,
      'duration': '0:45',
      'liked': false,
      'saved': false,
      'followed': false,
      'accent': const Color(0xFF8B5CF6),
      'mediaLabel': 'Music mix',
      'videoUrl': '',
    },
    {
      'id': 'template_2',
      'username': 'dev_life',
      'avatar': 'D',
      'category': 'For You',
      'title': 'Building NEXDROID',
      'description': 'Shipping real-time group chat, dark neon design system and quantum UI.',
      'hashtags': '#flutter #buildinpublic #nexchat',
      'soundTrack': 'Dev Life • Code & Chill Lofi',
      'likes': 28910,
      'comments': 1487,
      'shares': 923,
      'saves': 512,
      'views': 234500,
      'duration': '1:15',
      'liked': true,
      'saved': true,
      'followed': true,
      'accent': const Color(0xFF22C55E),
      'mediaLabel': 'Tech Dev Vlog',
      'videoUrl': '',
    },
    {
      'id': 'template_3',
      'username': 'gaming_pro',
      'avatar': 'G',
      'category': 'Gaming',
      'title': 'High Stakes Aviator Clutch',
      'description': 'Multiplied by 48.5x at the exact last second! Pure tension.',
      'hashtags': '#aviator #gaming #nexbets',
      'soundTrack': 'NEX Gaming Core • Hype Bass',
      'likes': 45934,
      'comments': 3203,
      'shares': 1567,
      'saves': 890,
      'views': 567000,
      'duration': '0:32',
      'liked': false,
      'saved': false,
      'followed': false,
      'accent': const Color(0xFF3B82F6),
      'mediaLabel': 'Gameplay clip',
      'videoUrl': '',
    },
    {
      'id': 'template_4',
      'username': 'cosmic_art',
      'avatar': 'C',
      'category': 'Trending',
      'title': 'Cyberpunk Shaders',
      'description': 'Procedural aurora particle simulations rendered at 60 FPS in Flutter canvas.',
      'hashtags': '#cyberpunk #art #motion',
      'soundTrack': 'Cosmic Art • Neon Waves',
      'likes': 19820,
      'comments': 876,
      'shares': 430,
      'saves': 324,
      'views': 145800,
      'duration': '1:00',
      'liked': false,
      'saved': false,
      'followed': false,
      'accent': const Color(0xFFEC4899),
      'mediaLabel': 'Motion graphics',
      'videoUrl': '',
    },
    {
      'id': 'template_5',
      'username': 'tech_insider',
      'avatar': 'T',
      'category': 'Tech',
      'title': 'Rust Security Engine Demo',
      'description': 'NEXDROID root scanner detecting unauthorized su binaries in real-time.',
      'hashtags': '#security #rust #nexdroid',
      'soundTrack': 'Tech Insider • Digital Fortress',
      'likes': 33200,
      'comments': 2100,
      'shares': 1200,
      'saves': 670,
      'views': 410000,
      'duration': '0:58',
      'liked': false,
      'saved': false,
      'followed': false,
      'accent': const Color(0xFF06B6D4),
      'mediaLabel': 'Security Demo',
      'videoUrl': '',
    },
    {
      'id': 'template_6',
      'username': 'comedy_king',
      'avatar': 'K',
      'category': 'Comedy',
      'title': 'When the code compiles first try',
      'description': 'That feeling when flutter analyze returns 0 errors...',
      'hashtags': '#coding #comedy #relatable',
      'soundTrack': 'Comedy King • Laugh Track Remix',
      'likes': 67300,
      'comments': 4800,
      'shares': 2900,
      'saves': 1400,
      'views': 890000,
      'duration': '0:22',
      'liked': false,
      'saved': false,
      'followed': false,
      'accent': const Color(0xFFF59E0B),
      'mediaLabel': 'Comedy skit',
      'videoUrl': '',
    },
  ];

  List<Map<String, dynamic>> _allVideos = List.from(_curatedTemplates);

  List<Map<String, dynamic>> get _videos {
    if (_selectedCategory == 'For You') return _allVideos;
    return _allVideos.where((v) => v['category'] == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();
    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _equalizerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _heartBurstAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _listenToLiveReels();
  }

  void _listenToLiveReels() {
    _reelsSubscription = ReelService.instance.getReelsStream().listen(
      (firestoreReels) {
        if (!mounted) return;
        setState(() {
          final Set<String> existingIds = {};
          final merged = <Map<String, dynamic>>[];

          for (final reel in firestoreReels) {
            final id = reel['id']?.toString() ?? '';
            if (id.isNotEmpty) existingIds.add(id);
            reel['accent'] = reel['accent'] ?? _pickAccentColor(id);
            reel['mediaLabel'] = reel['mediaLabel'] ?? 'NEX Clip';
            reel['category'] = reel['category'] ?? 'For You';
            merged.add(reel);
          }

          for (final template in _curatedTemplates) {
            final tid = template['id']?.toString() ?? '';
            if (!existingIds.contains(tid)) {
              merged.add(Map<String, dynamic>.from(template));
            }
          }

          _allVideos = merged;
        });
      },
      onError: (err) {
        debugPrint('[VideoFeedScreen] Firestore reels stream notice: $err');
      },
    );
  }

  Color _pickAccentColor(String seed) {
    const accents = [
      kNeonPurple,
      kNeonBlue,
      kNeonGreen,
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFFF59E0B),
    ];
    return accents[seed.hashCode.abs() % accents.length];
  }

  @override
  void dispose() {
    _reelsSubscription?.cancel();
    _discAnim.dispose();
    _equalizerAnim.dispose();
    _heartBurstAnim.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openCreateReel() async {
    final result = await Navigator.pushNamed(context, VideoPostScreen.routeName);
    if (!mounted || result == null) return;

    final reel = Map<String, dynamic>.from(result as Map);
    setState(() {
      _allVideos.insert(0, {
        ...reel,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'saves': 0,
        'views': 0,
        'liked': false,
        'saved': false,
        'followed': false,
        'accent': reel['accent'] ?? kNeonPurple,
        'videoUrl': reel['mediaUrl'] ?? reel['videoUrl'] ?? '',
      });
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _toggleLike(int index) {
    if (index >= _videos.length) return;
    final video = _videos[index];
    final bool currentlyLiked = (video['liked'] as bool?) ?? false;
    final int currentLikes = (video['likes'] as int?) ?? 0;

    setState(() {
      video['liked'] = !currentlyLiked;
      video['likes'] = !currentlyLiked ? currentLikes + 1 : (currentLikes > 0 ? currentLikes - 1 : 0);
    });

    final reelId = video['id']?.toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (reelId != null && uid != null && !reelId.startsWith('template_')) {
      ReelService.instance.toggleLikeReel(reelId, uid, currentlyLiked);
    }
  }

  void _toggleSave(int index) {
    if (index >= _videos.length) return;
    setState(() {
      _videos[index]['saved'] = !((_videos[index]['saved'] as bool?) ?? false);
    });
  }

  void _toggleFollow(int index) {
    if (index >= _videos.length) return;
    setState(() {
      _videos[index]['followed'] = !((_videos[index]['followed'] as bool?) ?? false);
    });
  }

  // Double-tap to like with floating heart particle burst
  void _onDoubleTap(int index, TapDownDetails? details) {
    if (index >= _videos.length) return;
    if (!((_videos[index]['liked'] as bool?) ?? false)) {
      _toggleLike(index);
    }
    _heartBurstAnim.forward(from: 0.0);
    final rng = math.Random();
    final baseX = details?.localPosition.dx ?? 150.0;
    final baseY = details?.localPosition.dy ?? 300.0;
    for (int i = 0; i < 8; i++) {
      _floatingHearts.add(_FloatingHeart(
        x: baseX + rng.nextDouble() * 60 - 30,
        y: baseY,
        dx: rng.nextDouble() * 4 - 2,
        dy: -(rng.nextDouble() * 6 + 3),
        scale: rng.nextDouble() * 0.6 + 0.6,
        opacity: 1.0,
        color: [Colors.redAccent, Colors.pinkAccent, const Color(0xFFFF2A85), Colors.white][rng.nextInt(4)],
      ));
    }
    _animateHearts();
  }

  void _animateHearts() {
    Future.delayed(const Duration(milliseconds: 30), () {
      if (!mounted) return;
      setState(() {
        _floatingHearts.removeWhere((h) => h.opacity <= 0.01);
        for (final h in _floatingHearts) {
          h.x += h.dx;
          h.y += h.dy;
          h.opacity -= 0.04;
          h.scale *= 0.97;
        }
      });
      if (_floatingHearts.isNotEmpty) _animateHearts();
    });
  }

  void _showCommentSheet(int index) {
    if (index >= _videos.length) return;
    final video = _videos[index];
    final reelId = video['id']?.toString() ?? '';
    final controller = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '${_formatCount(video['comments'] as int? ?? 0)} comments',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: reelId.isNotEmpty && !reelId.startsWith('template_')
                  ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ReelService.instance.getCommentsStream(reelId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 48),
                                SizedBox(height: 8),
                                Text('No comments yet.', style: TextStyle(color: Colors.white54)),
                                SizedBox(height: 4),
                                Text('Be the first to share your thoughts.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final cData = docs[i].data();
                            final author = cData['authorName']?.toString() ?? 'NEX User';
                            final text = cData['text']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: kNeonPurple.withValues(alpha: 0.3),
                                    child: Text(
                                      author.isNotEmpty ? author[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(author, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    )
                  : _buildFallbackCommentsList(scrollController),
            ),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: kNeonBlue),
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      controller.clear();
                      setState(() {
                        video['comments'] = ((video['comments'] as int?) ?? 0) + 1;
                      });
                      if (reelId.isNotEmpty && !reelId.startsWith('template_')) {
                        final authorId = user?.uid ?? 'anon';
                        final authorName = user?.displayName ?? user?.email?.split('@').first ?? 'NEX User';
                        final authorPic = user?.photoURL ?? '';
                        await ReelService.instance.addComment(
                          reelId,
                          text,
                          authorId: authorId,
                          authorName: authorName,
                          authorPic: authorPic,
                        );
                      }
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Comment posted.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCommentsList(ScrollController scrollController) {
    const List<Map<String, String>> comments = [
      {'user': 'nex_fan_01', 'text': 'This is incredible work!'},
      {'user': 'flutter_dev', 'text': 'Super smooth flow. How long did this take?'},
      {'user': 'cyber_ninja', 'text': 'The particle animations are top tier.'},
    ];
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: comments.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kNeonPurple.withValues(alpha: 0.3),
              child: Text(comments[i]['user']![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comments[i]['user']!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(comments[i]['text']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareReel(int index) {
    if (index >= _videos.length) return;
    final reel = _videos[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shared ${reel['title']} to your circle.')),
    );
    setState(() => _videos[index]['shares'] = ((_videos[index]['shares'] as int?) ?? 0) + 1);
  }

  void _showAIHelperSheet(BuildContext context) async {
    final navigator = Navigator.of(context);
    final status = await AIService.instance.getIntegrationStatus();
    if (!mounted || !context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 40,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'NEX AI Reels Helper',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final response = await AIService.instance.explainReelStyle('Explain how to make NEX-Reels more engaging.');
                if (!mounted || !context.mounted) return;
                if (navigator.canPop()) {
                  navigator.pop();
                }
                _showInfoDialog(context, 'Reels Tips', response);
              },
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('AI Reels Tips'),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonBlue),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final caption = await AIService.instance.generateCaption('Create a remix caption for NEX Reels.');
                if (!mounted || !context.mounted) return;
                if (navigator.canPop()) {
                  navigator.pop();
                }
                _showInfoDialog(context, 'AI Caption', caption);
              },
              icon: const Icon(Icons.message),
              label: const Text('Generate Caption'),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonGreen, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kNeonGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('NEX-Reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Upload Reel',
            onPressed: _openCreateReel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (_) => _showAIHelperSheet(context),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20),
                    SizedBox(width: 12),
                    Text('Search'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'ai',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 20),
                    SizedBox(width: 12),
                    Text('AI Helper'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateReel,
        backgroundColor: kNeonPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: const Text('Create Reel', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.video_camera_back),
      ),
      body: Stack(
        children: [
          // Vertical Full-Screen TikTok/Instagram style PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return _buildVideoCard(_videos[index], index);
            },
          ),
          // Category chips at top below AppBar
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: kNeonPurple,
                      backgroundColor: Colors.black54,
                      side: BorderSide(
                        color: isSelected ? kNeonPurple : Colors.white24,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Floating heart particles for double-tap
          ..._floatingHearts.map((h) => Positioned(
            left: h.x - 12,
            top: h.y - 12,
            child: Opacity(
              opacity: h.opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: h.scale,
                child: Icon(Icons.favorite, color: h.color, size: 28),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, int index) {
    final accent = (video['accent'] is Color) ? video['accent'] as Color : kNeonPurple;
    final videoUrl = video['videoUrl']?.toString() ?? video['media_url']?.toString() ?? '';
    final hasVideo = videoUrl.isNotEmpty;
    final isCurrent = _currentPage == index;
    TapDownDetails? lastTapDown;

    return GestureDetector(
      onDoubleTapDown: (details) => lastTapDown = details,
      onDoubleTap: () => _onDoubleTap(index, lastTapDown),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-size Video Background or Ambient Animated Particle Canvas
          if (hasVideo)
            _ReelVideoPlayer(
              videoUrl: videoUrl,
              isPlaying: isCurrent,
              accent: accent,
            )
          else
            _buildAmbientBackground(accent),

          // 2. Top Vignette Gradient for clean header legibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom Vignette Gradient for caption & buttons legibility
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),

          // 4. View Count Badge (Top-left, below categories)
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 104,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(video['views'] as int? ?? 0),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 3),
                  const Text('views', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),

          // 5. Bottom Overlay: Creator info, caption, audio track
          Positioned(
            left: 16,
            right: 80,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          (video['avatar']?.toString().isNotEmpty ?? false) ? video['avatar']![0].toUpperCase() : 'N',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${video['username'] ?? 'creator'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${video['duration'] ?? '0:30'} • ${video['mediaLabel'] ?? 'Reel'}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleFollow(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: (video['followed'] == true) ? Colors.white.withValues(alpha: 0.2) : kNeonPurple,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (video['followed'] == true) ? Colors.white30 : kNeonPurple),
                        ),
                        child: Text(
                          (video['followed'] == true) ? 'Following' : 'Follow',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title & Caption
                if ((video['title']?.toString().isNotEmpty ?? false))
                  Text(
                    video['title'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if ((video['description']?.toString().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 4),
                  Text(
                    video['description'].toString(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                // Hashtags
                if ((video['hashtags']?.toString().isNotEmpty ?? false))
                  Text(
                    video['hashtags'].toString(),
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 10),
                // Sound track bar with mini equalizer
                _buildSoundTrackBar(video, accent),
              ],
            ),
          ),

          // 6. Right Side Action Bar (Likes, comments, shares, save, vinyl disc)
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReelSideButton(
                  icon: (video['liked'] == true) ? Icons.favorite : Icons.favorite_border,
                  label: _formatCount(video['likes'] as int? ?? 0),
                  color: (video['liked'] == true) ? Colors.redAccent : Colors.white,
                  onTap: () => _toggleLike(index),
                ),
                const SizedBox(height: 14),
                _buildReelSideButton(
                  icon: Icons.chat_bubble_outline,
                  label: _formatCount(video['comments'] as int? ?? 0),
                  color: Colors.white,
                  onTap: () => _showCommentSheet(index),
                ),
                const SizedBox(height: 14),
                _buildReelSideButton(
                  icon: Icons.share_outlined,
                  label: _formatCount(video['shares'] as int? ?? 0),
                  color: Colors.white,
                  onTap: () => _shareReel(index),
                ),
                const SizedBox(height: 14),
                _buildReelSideButton(
                  icon: (video['saved'] == true) ? Icons.bookmark : Icons.bookmark_border,
                  label: 'Save',
                  color: (video['saved'] == true) ? kNeonGreen : Colors.white,
                  onTap: () => _toggleSave(index),
                ),
                const SizedBox(height: 14),
                // Spinning vinyl disc
                AnimatedBuilder(
                  animation: _discAnim,
                  builder: (_, __) {
                    return Transform.rotate(
                      angle: _discAnim.value * 2 * math.pi,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [accent, Colors.black, accent.withValues(alpha: 0.7), Colors.black, accent],
                          ),
                          border: Border.all(color: Colors.white30, width: 2),
                        ),
                        child: const Center(
                          child: CircleAvatar(radius: 6, backgroundColor: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground(Color accent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF070B14),
                accent.withValues(alpha: 0.28),
                kDarkBackground,
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _equalizerAnim,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ReelsParticlePainter(
                progress: _equalizerAnim.value,
                accent: accent,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSoundTrackBar(Map<String, dynamic> video, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note_rounded, color: accent, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              video['soundTrack']?.toString() ?? 'Original Audio',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Mini equalizer bars
          AnimatedBuilder(
            animation: _equalizerAnim,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (i) {
                  final h = 7.0 + (_equalizerAnim.value * (i % 2 == 0 ? 9 : 5));
                  return Container(
                    width: 2.5,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReelSideButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _ReelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isPlaying;
  final Color accent;

  const _ReelVideoPlayer({
    required this.videoUrl,
    required this.isPlaying,
    required this.accent,
  });

  @override
  State<_ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<_ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl.isEmpty) return;
    try {
      if (widget.videoUrl.startsWith('http://') || widget.videoUrl.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isPlaying && !_userPaused) {
          _controller!.play();
        }
      }
    } catch (e) {
      debugPrint('[ReelVideoPlayer] Video load notice: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _initPlayer();
    } else if (oldWidget.isPlaying != widget.isPlaying && _controller != null && _isInitialized) {
      if (widget.isPlaying && !_userPaused) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _userPaused = true;
      } else {
        _controller!.play();
        _userPaused = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || !_isInitialized || _controller == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF070B14),
              widget.accent.withValues(alpha: 0.35),
              kDarkBackground,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: kNeonPurple, strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (!_controller!.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
            ),
        ],
      ),
    );
  }
}

class _FloatingHeart {
  double x, y, dx, dy, scale, opacity;
  Color color;

  _FloatingHeart({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.opacity,
    required this.color,
  });
}

class _ReelsParticlePainter extends CustomPainter {
  final double progress;
  final Color accent;

  _ReelsParticlePainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final y = (baseY + progress * 40 * (i % 2 == 0 ? 1 : -1)) % size.height;
      final r = rng.nextDouble() * 2.5 + 0.5;
      final alpha = (rng.nextDouble() * 0.3 + 0.05).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = accent.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReelsParticlePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
