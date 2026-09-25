import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/media_downloader_service.dart';
import '../utils/constants.dart';

class MediaDownloaderScreen extends StatefulWidget {
  static const routeName = '/media-downloader';
  const MediaDownloaderScreen({super.key});

  @override
  State<MediaDownloaderScreen> createState() => _MediaDownloaderScreenState();
}

class _MediaDownloaderScreenState extends State<MediaDownloaderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final MediaDownloaderService _service = MediaDownloaderService();
  final FocusNode _urlFocus = FocusNode();

  MediaPlatform _detectedPlatform = MediaPlatform.unknown;
  String _selectedQuality = '1080p';
  String _selectedFormat = 'mp4';
  bool _isExtracting = false;
  bool _isAudioOnly = false;
  Map<String, dynamic>? _extractedMeta;
  String _historySearch = '';

  late AnimationController _pulseController;
  late AnimationController _warpController;
  late AnimationController _signalController;
  late Animation<double> _pulseAnim;

  // Format matrix data
  static const List<Map<String, String>> _formatMatrix = [
    {'label': '4K ULTRA', 'quality': '2160p', 'format': 'mp4', 'badge': '4K', 'bitrate': '45 Mbps', 'size': '~2.1 GB/hr'},
    {'label': '1080p FHD', 'quality': '1080p', 'format': 'mp4', 'badge': 'FHD', 'bitrate': '8 Mbps', 'size': '~500 MB/hr'},
    {'label': '720p HD', 'quality': '720p', 'format': 'mp4', 'badge': 'HD', 'bitrate': '5 Mbps', 'size': '~300 MB/hr'},
    {'label': '480p SD', 'quality': '480p', 'format': 'mp4', 'badge': 'SD', 'bitrate': '2.5 Mbps', 'size': '~150 MB/hr'},
    {'label': 'WEBM VP9', 'quality': '1080p', 'format': 'webm', 'badge': 'VP9', 'bitrate': '6 Mbps', 'size': '~380 MB/hr'},
    {'label': 'MKV HEVC', 'quality': '1080p', 'format': 'mkv', 'badge': 'H265', 'bitrate': '4 Mbps', 'size': '~250 MB/hr'},
    {'label': 'MP3 320K', 'quality': '320kbps', 'format': 'mp3', 'badge': 'MP3', 'bitrate': '320 kbps', 'size': '~144 MB/hr'},
    {'label': 'AAC HQ', 'quality': '256kbps', 'format': 'aac', 'badge': 'AAC', 'bitrate': '256 kbps', 'size': '~115 MB/hr'},
    {'label': 'FLAC LOSS', 'quality': '1411kbps', 'format': 'flac', 'badge': 'FLAC', 'bitrate': '1411 kbps', 'size': '~635 MB/hr'},
    {'label': 'MP3 128K', 'quality': '128kbps', 'format': 'mp3', 'badge': '128K', 'bitrate': '128 kbps', 'size': '~58 MB/hr'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service.addListener(_onServiceUpdate);
    _urlController.addListener(_onUrlChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _warpController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _signalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _tabController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    _urlFocus.dispose();
    _pulseController.dispose();
    _warpController.dispose();
    _signalController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim();
    final platform = MediaDownloaderService.detectPlatform(text);
    if (platform != _detectedPlatform) {
      setState(() {
        _detectedPlatform = platform;
        _extractedMeta = null;
        _isAudioOnly = false;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _urlController.text = data.text!;
    }
  }

  Future<void> _extractMetadata() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _isExtracting = true);
    try {
      final meta = await _service.inspectUrl(url);
      if (mounted) {
        setState(() {
          _extractedMeta = meta;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        _showSnack('Extraction failed: $e', icon: Icons.error_outline_rounded);
      }
    }
  }

  void _startDownload() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final title = _extractedMeta?['title'] as String? ?? 'Downloaded Media';
    final downloadUrl = _extractedMeta?['downloadUrl'] as String?;
    final thumb = _extractedMeta?['thumbnailUrl'] as String?;
    _service.startDownload(
      url: url,
      title: title,
      platform: _detectedPlatform,
      quality: _selectedQuality,
      format: _selectedFormat,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumb,
    );
    _tabController.animateTo(1);
    _showSnack('Download initiated', icon: Icons.rocket_launch_rounded, success: true);
  }

  void _showSnack(String message,
      {IconData icon = Icons.info_outline_rounded, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon,
                color: success ? kNeonGreen : Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF111828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hasActive = _service.activeTasks.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kNeonGreen, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF6B3D)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF3366).withValues(alpha: 0.3),
                      blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.downloading_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXUS INTERCEPTOR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                Text('MEDIA ACQUISITION SYSTEM',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
        actions: [
          // Signal strength indicator
          AnimatedBuilder(
            animation: _signalController,
            builder: (context, _) {
              final v = _signalController.value;
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(4, (i) {
                    final barH = 6.0 + i * 4.0;
                    final active = hasActive && (v > i * 0.25);
                    return Container(
                      margin: const EdgeInsets.only(right: 2),
                      width: 4,
                      height: barH,
                      decoration: BoxDecoration(
                        color: active
                            ? kNeonGreen.withValues(alpha: 0.6 + v * 0.4)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF3366),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1),
          tabs: [
            const Tab(text: 'INTERCEPT'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ACTIVE'),
                  if (_service.activeTasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kNeonGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_service.activeTasks.length}',
                          style: const TextStyle(
                              color: kNeonGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'ARCHIVE'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Warp tunnel background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _warpController,
              builder: (context, _) => CustomPaint(
                painter: _WarpTunnelPainter(
                  progress: _warpController.value,
                  isActive: hasActive,
                ),
              ),
            ),
          ),
          TabBarView(
            controller: _tabController,
            children: [
              _buildInterceptTab(),
              _buildActiveDownloadsTab(),
              _buildHistoryTab(),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: INTERCEPT (Downloader)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildInterceptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL Input
          _buildUrlInput(),
          const SizedBox(height: 16),

          // Platform detection chips
          _buildPlatformChips(),
          const SizedBox(height: 20),

          // Extract button
          if (_urlController.text.trim().isNotEmpty && _extractedMeta == null)
            _buildExtractButton(),
          if (_isExtracting) _buildExtractingIndicator(),
          if (_extractedMeta != null) ...[
            _buildMiniPlayerPreview(),
            const SizedBox(height: 20),
          ],

          // Format Matrix
          const Text('FORMAT MATRIX',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Select target encoding protocol',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
          const SizedBox(height: 12),
          _buildFormatMatrix(),
          const SizedBox(height: 24),

          // Download button
          _buildDownloadButton(),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    final platformColor = _platformColor(_detectedPlatform);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1222),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _urlController.text.trim().isNotEmpty
              ? platformColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: _urlController.text.trim().isNotEmpty
            ? [BoxShadow(color: platformColor.withValues(alpha: 0.08), blurRadius: 20)]
            : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) => Icon(
              Icons.link_rounded,
              color: _urlController.text.trim().isNotEmpty
                  ? platformColor.withValues(alpha: _pulseAnim.value)
                  : Colors.white24,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocus,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Paste target URL here...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          GestureDetector(
            onTap: _pasteFromClipboard,
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.content_paste_rounded,
                  color: Colors.white.withValues(alpha: 0.5), size: 18),
            ),
          ),
          if (_urlController.text.trim().isNotEmpty)
            GestureDetector(
              onTap: () {
                _urlController.clear();
                setState(() {
                  _extractedMeta = null;
                  _detectedPlatform = MediaPlatform.unknown;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.redAccent, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformChips() {
    final platforms = [
      {'name': 'YouTube', 'icon': Icons.play_circle_fill_rounded, 'color': Colors.red, 'platform': MediaPlatform.youtube},
      {'name': 'TikTok', 'icon': Icons.music_note_rounded, 'color': Colors.cyanAccent, 'platform': MediaPlatform.tiktok},
      {'name': 'Instagram', 'icon': Icons.camera_alt_rounded, 'color': const Color(0xFFE1306C), 'platform': MediaPlatform.instagram},
      {'name': 'X/Twitter', 'icon': Icons.tag_rounded, 'color': Colors.lightBlue, 'platform': MediaPlatform.twitter},
      {'name': 'SoundCloud', 'icon': Icons.graphic_eq_rounded, 'color': Colors.orange, 'platform': MediaPlatform.unknown},
      {'name': 'Spotify', 'icon': Icons.podcasts_rounded, 'color': const Color(0xFF1DB954), 'platform': MediaPlatform.unknown},
      {'name': 'Other', 'icon': Icons.movie_creation_rounded, 'color': const Color(0xFF8B5CF6), 'platform': MediaPlatform.unknown},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: platforms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = platforms[i];
          final isActive = _detectedPlatform == p['platform'] as MediaPlatform &&
              (_detectedPlatform != MediaPlatform.unknown || i == platforms.length - 1);
          final color = p['color'] as Color;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p['icon'] as IconData, color: color, size: 14),
                const SizedBox(width: 5),
                Text(p['name'] as String,
                    style: TextStyle(
                        color: isActive ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExtractButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: _extractMetadata,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _platformColor(_detectedPlatform).withValues(alpha: 0.3),
              _platformColor(_detectedPlatform).withValues(alpha: 0.1),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _platformColor(_detectedPlatform).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar_rounded,
                  color: _platformColor(_detectedPlatform), size: 18),
              const SizedBox(width: 8),
              Text('SCAN TARGET',
                  style: TextStyle(
                      color: _platformColor(_detectedPlatform),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtractingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1222),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _platformColor(_detectedPlatform).withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _platformColor(_detectedPlatform)),
              ),
            ),
            const SizedBox(height: 12),
            Text('INTERCEPTING SIGNAL...',
                style: TextStyle(
                    color: _platformColor(_detectedPlatform),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayerPreview() {
    final meta = _extractedMeta!;
    final title = meta['title'] as String? ?? 'Unknown Target';
    final platformColor = _platformColor(_detectedPlatform);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            platformColor.withValues(alpha: 0.08),
            const Color(0xFF0C1222),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: platformColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: platformColor.withValues(alpha: 0.06), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail placeholder
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: platformColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: platformColor.withValues(alpha: 0.3)),
            ),
            child: Icon(
              _isAudioOnly
                  ? Icons.audiotrack_rounded
                  : Icons.videocam_rounded,
              color: platformColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TARGET ACQUIRED',
                    style: TextStyle(
                        color: kNeonGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _infoBadge(
                        MediaDownloaderService.getPlatformName(
                            _detectedPlatform),
                        platformColor),
                    const SizedBox(width: 6),
                    _infoBadge(
                        '$_selectedQuality • $_selectedFormat',
                        Colors.white38),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildFormatMatrix() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _formatMatrix.length,
      itemBuilder: (context, i) {
        final fmt = _formatMatrix[i];
        final isSelected = _selectedQuality == fmt['quality'] &&
            _selectedFormat == fmt['format'];
        final isAudio = ['mp3', 'aac', 'flac'].contains(fmt['format']);
        final accentColor =
            isAudio ? const Color(0xFF8B5CF6) : const Color(0xFFFF3366);

        return GestureDetector(
          onTap: () => setState(() {
            _selectedQuality = fmt['quality']!;
            _selectedFormat = fmt['format']!;
            _isAudioOnly = isAudio;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.1)
                  : const Color(0xFF0C1222),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.06),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(fmt['badge']!,
                          style: TextStyle(
                              color: isSelected ? accentColor : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: accentColor, size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text(fmt['label']!,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                Text('${fmt['bitrate']} • ${fmt['size']}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 8)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadButton() {
    return GestureDetector(
      onTap: _urlController.text.trim().isNotEmpty ? _startDownload : null,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: _urlController.text.trim().isNotEmpty
                ? const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF6B3D)])
                : null,
            color: _urlController.text.trim().isEmpty
                ? Colors.white.withValues(alpha: 0.06)
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _urlController.text.trim().isNotEmpty
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF3366)
                          .withValues(alpha: 0.2 * _pulseAnim.value),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                color: _urlController.text.trim().isNotEmpty
                    ? Colors.white
                    : Colors.white24,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'LOCK TARGET & DOWNLOAD',
                style: TextStyle(
                  color: _urlController.text.trim().isNotEmpty
                      ? Colors.white
                      : Colors.white24,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: Active Downloads
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveDownloadsTab() {
    final active = _service.activeTasks;

    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1222),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Icon(Icons.cloud_done_outlined,
                  color: Colors.white.withValues(alpha: 0.15), size: 56),
            ),
            const SizedBox(height: 20),
            const Text('NO ACTIVE INTERCEPTS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('Paste a target URL to begin acquisition',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _tabController.animateTo(0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF3366), Color(0xFFFF6B3D)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_link_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('NEW INTERCEPT',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE INTERCEPTS (${active.length})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1)),
                    Text(
                      '${active.where((t) => t.status == DownloadStatus.downloading).length} streaming • ${active.where((t) => t.status == DownloadStatus.paused).length} suspended',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10),
                    ),
                  ],
                ),
              ),
              _actionChip(Icons.pause_circle_outline_rounded, 'HALT',
                  Colors.orange, _service.pauseAll),
              const SizedBox(width: 6),
              _actionChip(Icons.play_circle_outline_rounded, 'RESUME',
                  kNeonGreen, _service.resumeAll),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: active.length,
              itemBuilder: (context, i) =>
                  _buildTacticalDownloadCard(active[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalDownloadCard(DownloadTask task) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final percent = (task.progress * 100).toStringAsFixed(1);
    final platformColor = _platformColor(task.platform);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1222),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDownloading
              ? platformColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
          width: isDownloading ? 1.5 : 1,
        ),
        boxShadow: isDownloading
            ? [
                BoxShadow(
                    color: platformColor.withValues(alpha: 0.06),
                    blurRadius: 20),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Holographic progress ring
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: task.progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(platformColor),
                  ),
                ),
                Text('$percent%',
                    style: TextStyle(
                        color: platformColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _infoBadge(
                        MediaDownloaderService.getPlatformName(task.platform),
                        platformColor),
                    const SizedBox(width: 6),
                    _infoBadge(
                        '${task.quality} • ${task.format.toUpperCase()}',
                        Colors.white38),
                  ],
                ),
                const SizedBox(height: 8),
                // Multi-thread chunk lanes
                _buildChunkLanes(task.progress, platformColor),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _telemetryBadge(Icons.data_usage_rounded,
                        '${task.downloadedFormatted} / ${task.sizeFormatted}',
                        Colors.white54),
                    const Spacer(),
                    if (isDownloading)
                      _telemetryBadge(Icons.speed_rounded,
                          task.speedFormatted, kNeonGreen)
                    else if (isPaused)
                      _telemetryBadge(
                          Icons.pause_rounded, 'SUSPENDED', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Controls
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (isDownloading) {
                    _service.pauseTask(task);
                  } else if (isPaused) {
                    _service.resumeTask(task);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDownloading
                        ? Colors.orange.withValues(alpha: 0.12)
                        : kNeonGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDownloading
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: isDownloading ? Colors.orange : kNeonGreen,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _service.cancelTask(task),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.redAccent, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChunkLanes(double progress, Color color) {
    // Simulate 4 parallel chunk lanes
    final rng = math.Random(color.hashCode);
    return Row(
      children: List.generate(4, (i) {
        final laneProgress = (progress + rng.nextDouble() * 0.15 - 0.07).clamp(0.0, 1.0);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: laneProgress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: 0.4),
                    color,
                  ]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _telemetryBadge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: Archive (History)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    final allHistory = _service.historyTasks;
    final history = _historySearch.isEmpty
        ? allHistory
        : allHistory
            .where((t) =>
                t.title.toLowerCase().contains(_historySearch.toLowerCase()) ||
                MediaDownloaderService.getPlatformName(t.platform)
                    .toLowerCase()
                    .contains(_historySearch.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ARCHIVE (${allHistory.length})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1)),
                    Text('Intercepted media timeline',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10)),
                  ],
                ),
              ),
              if (allHistory.isNotEmpty)
                GestureDetector(
                  onTap: _confirmClearHistory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_sweep_rounded,
                            color: Colors.redAccent, size: 14),
                        SizedBox(width: 4),
                        Text('PURGE',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Search
          if (allHistory.isNotEmpty)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0C1222),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                onChanged: (v) => setState(() => _historySearch = v),
                decoration: InputDecoration(
                  hintText: 'Search archive...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.25), size: 16),
                  suffixIcon: _historySearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white30, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _historySearch = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          if (allHistory.isNotEmpty) const SizedBox(height: 12),

          // Empty states
          if (allHistory.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1222),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Icon(Icons.history_toggle_off_rounded,
                          color: Colors.white.withValues(alpha: 0.15),
                          size: 52),
                    ),
                    const SizedBox(height: 20),
                    const Text('ARCHIVE EMPTY',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text('Completed intercepts appear here',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12)),
                  ],
                ),
              ),
            )
          else if (history.isEmpty)
            Expanded(
              child: Center(
                child: Text('No results for "$_historySearch"',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, i) =>
                    _buildTimelineHistoryTile(history[i], i, history.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineHistoryTile(
      DownloadTask task, int index, int total) {
    final platformColor = _platformColor(task.platform);
    final isLast = index == total - 1;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 0),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 22),
      ),
      onDismissed: (_) => _service.deleteHistoryItem(task),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline connector
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: platformColor,
                      boxShadow: [
                        BoxShadow(
                          color: platformColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1222),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: platformColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          task.format == 'mp3'
                              ? Icons.music_note_rounded
                              : _platformIcon(task.platform),
                          color: platformColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _infoBadge(
                                  MediaDownloaderService.getPlatformName(
                                      task.platform),
                                  platformColor),
                              const SizedBox(width: 5),
                              _infoBadge(task.quality, Colors.white30),
                              const SizedBox(width: 5),
                              _infoBadge(task.sizeFormatted, Colors.white30),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(task.timeAgoFormatted,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 9)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showSnack('Opening ${task.title}',
                              icon: Icons.open_in_new_rounded, success: true),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: kNeonGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.open_in_new_rounded,
                                color: kNeonGreen, size: 14),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _service.deleteHistoryItem(task),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C1222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('PURGE ARCHIVE?',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        content: const Text(
          'This will permanently erase all download history. This operation is irreversible.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('ABORT', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              _service.clearHistory();
              Navigator.pop(context);
              _showSnack('Archive purged',
                  icon: Icons.delete_sweep_rounded);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('PURGE ALL',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════════════════
  Color _platformColor(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.youtube:
        return Colors.red;
      case MediaPlatform.tiktok:
        return Colors.cyanAccent;
      case MediaPlatform.instagram:
        return const Color(0xFFE1306C);
      case MediaPlatform.twitter:
        return Colors.lightBlue;
      case MediaPlatform.unknown:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _platformIcon(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.youtube:
        return Icons.play_circle_fill_rounded;
      case MediaPlatform.tiktok:
        return Icons.music_note_rounded;
      case MediaPlatform.instagram:
        return Icons.camera_alt_rounded;
      case MediaPlatform.twitter:
        return Icons.tag_rounded;
      case MediaPlatform.unknown:
        return Icons.movie_creation_rounded;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WARP TUNNEL PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _WarpTunnelPainter extends CustomPainter {
  _WarpTunnelPainter({required this.progress, required this.isActive});

  final double progress;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.sqrt(cx * cx + cy * cy);
    final paint = Paint()..style = PaintingStyle.stroke;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF050A14),
    );

    // Perspective tunnel rings
    const ringCount = 12;
    for (var i = 0; i < ringCount; i++) {
      final t = (i / ringCount + progress) % 1.0;
      final r = t * maxR * 0.6;
      final alpha = (1 - t) * (isActive ? 0.15 : 0.06);
      paint
        ..color = (isActive ? const Color(0xFFFF3366) : const Color(0xFF1A2744))
            .withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = 1 + (1 - t) * 2;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // Radial streaks
    if (isActive) {
      final streakPaint = Paint()..strokeWidth = 1;
      final rng = math.Random(42);
      for (var i = 0; i < 24; i++) {
        final angle = (i / 24) * math.pi * 2 + progress * math.pi * 2;
        final startR = maxR * 0.05;
        final endR = maxR * (0.3 + rng.nextDouble() * 0.3);
        streakPaint.color = const Color(0xFFFF3366)
            .withValues(alpha: 0.04 + rng.nextDouble() * 0.06);
        canvas.drawLine(
          Offset(cx + math.cos(angle) * startR, cy + math.sin(angle) * startR),
          Offset(cx + math.cos(angle) * endR, cy + math.sin(angle) * endR),
          streakPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WarpTunnelPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isActive != isActive;
}
