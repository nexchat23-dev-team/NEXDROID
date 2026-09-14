import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/media_downloader_service.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';

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

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnim;

  static const List<Map<String, String>> _qualityOptions = [
    {'label': '4K Ultra HD (MP4)', 'quality': '2160p', 'format': 'mp4', 'badge': '4K'},
    {'label': '1080p Full HD (MP4)', 'quality': '1080p', 'format': 'mp4', 'badge': 'HD'},
    {'label': '720p HD (MP4)', 'quality': '720p', 'format': 'mp4', 'badge': '720'},
    {'label': '480p SD (MP4)', 'quality': '480p', 'format': 'mp4', 'badge': 'SD'},
    {'label': 'Audio Only 320kbps (MP3)', 'quality': '320kbps', 'format': 'mp3', 'badge': '🎵'},
    {'label': 'Audio Only 128kbps (MP3)', 'quality': '128kbps', 'format': 'mp3', 'badge': '🎶'},
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

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _tabController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    _urlFocus.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
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
        // Auto switch to audio-only for audio links
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
      _onUrlChanged();
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _extractMedia() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnack('Paste a video or media link first', icon: Icons.link_off);
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showSnack('Please enter a valid web URL (https://...)',
          icon: Icons.warning_amber_rounded);
      return;
    }

    setState(() => _isExtracting = true);
    HapticFeedback.selectionClick();

    final meta = await _service.inspectUrl(url);
    if (!mounted) return;

    setState(() {
      _extractedMeta = meta;
      _isExtracting = false;
    });

    HapticFeedback.mediumImpact();
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final title = _extractedMeta?['title'] as String? ??
        '${MediaDownloaderService.getPlatformName(_detectedPlatform)} Media';
    final downloadUrl = (_extractedMeta?['downloadUrl'] as String?)?.isNotEmpty == true
        ? (_extractedMeta!['downloadUrl'] as String)
        : url;
    final thumbUrl = _extractedMeta?['thumbnailUrl'] as String?;

    final quality = _isAudioOnly ? '320kbps' : _selectedQuality;
    final format = _isAudioOnly ? 'mp3' : _selectedFormat;

    await _service.startDownload(
      url: url,
      title: title,
      platform: _detectedPlatform,
      quality: quality,
      format: format,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbUrl,
    );

    _urlController.clear();
    setState(() {
      _extractedMeta = null;
      _detectedPlatform = MediaPlatform.unknown;
      _isAudioOnly = false;
    });

    _tabController.animateTo(1);
    HapticFeedback.heavyImpact();
    _showSnack('Download started!', icon: Icons.download_rounded, success: true);
  }

  void _showSnack(String msg,
      {IconData icon = Icons.info_outline, bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon,
                color: success ? const Color(0xFF00E676) : Colors.white70,
                size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF141C38),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeCount = _service.activeTasks.length;
    final historyCount = _service.historyTasks.length;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1020).withValues(alpha: 0.92),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3366).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.download_for_offline_rounded,
                      color: Color(0xFFFF3366), size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'NEX Downloader',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: const Color(0xFFFF3366).withValues(alpha: 0.2)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF3366),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12),
              tabs: [
                const Tab(
                  icon: Icon(Icons.link_rounded, size: 18),
                  text: 'Downloader',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: activeCount > 0,
                    label: Text('$activeCount',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: const Color(0xFFFF3366),
                    child: const Icon(Icons.downloading_rounded, size: 18),
                  ),
                  text: 'Active',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: historyCount > 0,
                    label: Text('$historyCount',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: kNeonBlue,
                    child: const Icon(Icons.history_rounded, size: 18),
                  ),
                  text: 'History',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackground(
              backgroundColors: [
                Color(0xFF04060E),
                Color(0xFF080D1D),
                Color(0xFF0D152D),
              ],
              leftAuroraColors: [
                Color(0xFFFF3366),
                Color(0xFF8B5CF6),
                Color(0x00000000),
              ],
            ),
          ),
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLinkDownloaderTab(),
                _buildActiveDownloadsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _pasteFromClipboard,
      backgroundColor: const Color(0xFFFF3366),
      icon: const Icon(Icons.content_paste_rounded, color: Colors.white, size: 18),
      label: const Text('Quick Paste',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      elevation: 6,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: Downloader
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLinkDownloaderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupportedPlatformsBar(),
          const SizedBox(height: 16),
          _buildUrlInputCard(),
          const SizedBox(height: 12),
          _buildExtractButton(),
          const SizedBox(height: 20),
          if (_isExtracting) _buildExtractingLoader(),
          if (_extractedMeta != null && !_isExtracting) _buildExtractedCard(),
        ],
      ),
    );
  }

  Widget _buildSupportedPlatformsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3366).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: Color(0xFF00E676), size: 14),
              const SizedBox(width: 6),
              Text(
                'Supports 4 platforms • No watermarks',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPlatformChip(
                  'YouTube', Icons.play_circle_fill, Colors.red, MediaPlatform.youtube),
              _buildPlatformChip(
                  'TikTok', Icons.music_note_rounded, Colors.cyan, MediaPlatform.tiktok),
              _buildPlatformChip(
                  'Instagram', Icons.camera_alt_rounded, Colors.pink, MediaPlatform.instagram),
              _buildPlatformChip(
                  'X / Twitter', Icons.tag_rounded, Colors.lightBlue, MediaPlatform.twitter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(
      String name, IconData icon, Color color, MediaPlatform platform) {
    final active = _detectedPlatform == platform;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? color : Colors.white.withValues(alpha: 0.08),
                width: active ? 2 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 0)
                    ]
                  : [],
            ),
            child:
                Icon(icon, color: active ? color : Colors.white38, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              color: active ? Colors.white : Colors.white38,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInputCard() {
    final hasUrl = _urlController.text.isNotEmpty;
    final detected = _detectedPlatform != MediaPlatform.unknown;
    final borderColor = detected
        ? _platformColor(_detectedPlatform)
        : hasUrl
            ? Colors.orange
            : Colors.white.withValues(alpha: 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF111828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: detected ? 1.8 : 1.2),
        boxShadow: detected
            ? [
                BoxShadow(
                    color: _platformColor(_detectedPlatform)
                        .withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 0)
              ]
            : [],
      ),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            focusNode: _urlFocus,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Paste YouTube, TikTok, Instagram or X link...',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              prefixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  detected
                      ? _platformIcon(_detectedPlatform)
                      : Icons.link_rounded,
                  key: ValueKey(_detectedPlatform),
                  color: detected
                      ? _platformColor(_detectedPlatform)
                      : Colors.white38,
                  size: 22,
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUrl)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        _urlController.clear();
                        setState(() => _extractedMeta = null);
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            ),
            onSubmitted: (_) => _extractMedia(),
          ),
          if (detected)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _platformColor(_detectedPlatform).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(_platformIcon(_detectedPlatform),
                      color: _platformColor(_detectedPlatform), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${MediaDownloaderService.getPlatformName(_detectedPlatform)} detected ✓',
                    style: TextStyle(
                      color: _platformColor(_detectedPlatform),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Ready to extract',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExtractButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExtracting ? null : _extractMedia,
        icon: _isExtracting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.search_rounded, color: Colors.white, size: 20),
        label: Text(
          _isExtracting ? 'Analyzing link...' : 'Extract & Inspect',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3366),
          disabledBackgroundColor:
              const Color(0xFFFF3366).withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          shadowColor: const Color(0xFFFF3366).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildExtractingLoader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFF3366).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (_, __) {
              return ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [
                    Color(0xFFFF3366),
                    Color(0xFF8B5CF6),
                    Color(0xFF00D4FF),
                    Color(0xFFFF3366),
                  ],
                  stops: [
                    (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                    _shimmerController.value.clamp(0.0, 1.0),
                    (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                    (_shimmerController.value + 0.6).clamp(0.0, 1.0),
                  ],
                ).createShader(rect),
                child: const Icon(Icons.radar_rounded,
                    color: Colors.white, size: 48),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Scanning media source...',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Connecting to ${MediaDownloaderService.getPlatformName(_detectedPlatform)} servers',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              backgroundColor: Color(0xFF1E2A4A),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3366)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedCard() {
    final meta = _extractedMeta!;
    final title = meta['title'] as String? ?? 'Media Content';
    final platform = _detectedPlatform;
    final apiSource = meta['apiSource'] as String? ?? 'unknown';
    final apiSuccess = apiSource == 'cobalt' || apiSource == 'cobalt-picker';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1526),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _platformColor(platform).withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: _platformColor(platform).withValues(alpha: 0.1),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _platformColor(platform).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_platformIcon(platform),
                        color: _platformColor(platform), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: apiSuccess
                                    ? const Color(0xFF00E676)
                                        .withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                apiSuccess ? '✓ Live API' : '⚡ Fast Mode',
                                style: TextStyle(
                                  color: apiSuccess
                                      ? const Color(0xFF00E676)
                                      : Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              MediaDownloaderService.getPlatformName(platform),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Audio-only toggle
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isAudioOnly
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isAudioOnly
                        ? const Color(0xFF8B5CF6)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      color: _isAudioOnly
                          ? const Color(0xFF8B5CF6)
                          : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Audio only (MP3)',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: _isAudioOnly,
                      onChanged: (v) => setState(() => _isAudioOnly = v),
                      activeThumbColor: const Color(0xFF8B5CF6),
                      inactiveThumbColor: Colors.white38,
                      inactiveTrackColor:
                          Colors.white.withValues(alpha: 0.12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quality selector
        if (!_isAudioOnly) ...[
          const Text(
            'Select Quality',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ..._qualityOptions
              .where((opt) => opt['format'] == 'mp4')
              .map((opt) => _buildQualityTile(opt)),
          const SizedBox(height: 12),
        ],

        // Download button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.file_download_rounded,
                color: Colors.white, size: 20),
            label: Text(
              _isAudioOnly
                  ? 'Download Audio (MP3)'
                  : 'Download $_selectedQuality (${_selectedFormat.toUpperCase()})',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              shadowColor: kNeonGreen.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityTile(Map<String, String> opt) {
    final isSelected = _selectedQuality == opt['quality'] &&
        _selectedFormat == opt['format'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedQuality = opt['quality']!;
        _selectedFormat = opt['format']!;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF3366).withValues(alpha: 0.12)
              : const Color(0xFF111828),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF3366)
                : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF3366).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                opt['badge']!,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFF3366)
                      : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFFFF3366), size: 18),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: Active Downloads (Alexander-style)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveDownloadsTab() {
    final active = _service.activeTasks;

    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1526),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Icon(Icons.cloud_done_outlined,
                  color: Colors.white.withValues(alpha: 0.2), size: 52),
            ),
            const SizedBox(height: 20),
            const Text(
              'No active downloads',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a link in the Downloader tab to start',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.add_link_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Add Download',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
                    Text(
                      'Downloading (${active.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    Text(
                      '${active.where((t) => t.status == DownloadStatus.downloading).length} active • ${active.where((t) => t.status == DownloadStatus.paused).length} paused',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              _buildActionChip(
                Icons.pause_circle_outline_rounded,
                'Pause All',
                Colors.orange,
                _service.pauseAll,
              ),
              const SizedBox(width: 6),
              _buildActionChip(
                Icons.play_circle_outline_rounded,
                'Resume All',
                kNeonGreen,
                _service.resumeAll,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: active.length,
              itemBuilder: (context, i) =>
                  _buildActiveDownloadTile(active[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDownloadTile(DownloadTask task) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final percent = (task.progress * 100).toStringAsFixed(1);
    final platformColor = _platformColor(task.platform);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDownloading
              ? platformColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.07),
          width: isDownloading ? 1.5 : 1,
        ),
        boxShadow: isDownloading
            ? [
                BoxShadow(
                    color: platformColor.withValues(alpha: 0.08),
                    blurRadius: 16)
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Platform icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: platformColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  task.format == 'mp3'
                      ? Icons.audiotrack_rounded
                      : _platformIcon(task.platform),
                  color: platformColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${MediaDownloaderService.getPlatformName(task.platform)} • ${task.quality} • ${task.format.toUpperCase()}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Controls
              _buildDownloadControl(task, isDownloading, isPaused),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white30, size: 20),
                onPressed: () => _service.cancelTask(task),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Animated progress bar
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.06),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(platformColor),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _statChip(Icons.data_usage_rounded,
                  '${task.downloadedFormatted} / ${task.sizeFormatted}',
                  Colors.white54),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  color: platformColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              if (isDownloading)
                _statChip(Icons.speed_rounded, task.speedFormatted, kNeonGreen)
              else if (isPaused)
                _statChip(Icons.pause_rounded, 'Paused', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadControl(
      DownloadTask task, bool isDownloading, bool isPaused) {
    return GestureDetector(
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
              ? Colors.orange.withValues(alpha: 0.14)
              : kNeonGreen.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isDownloading
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: isDownloading ? Colors.orange : kNeonGreen,
          size: 22,
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: Download History
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    final allHistory = _service.historyTasks;
    final history = _historySearch.isEmpty
        ? allHistory
        : allHistory
            .where((t) =>
                t.title
                    .toLowerCase()
                    .contains(_historySearch.toLowerCase()) ||
                MediaDownloaderService.getPlatformName(t.platform)
                    .toLowerCase()
                    .contains(_historySearch.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Header + clear
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'History (${allHistory.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    Text(
                      'All downloaded media',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (allHistory.isNotEmpty)
                GestureDetector(
                  onTap: () => _confirmClearHistory(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
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
                            color: Colors.redAccent, size: 15),
                        SizedBox(width: 4),
                        Text('Clear All',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          if (allHistory.isNotEmpty)
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF111828),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) => setState(() => _historySearch = v),
                decoration: InputDecoration(
                  hintText: 'Search downloads...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.3), size: 18),
                  suffixIcon: _historySearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 16),
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

          // Empty state
          if (allHistory.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1526),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Icon(Icons.history_toggle_off_rounded,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 52),
                    ),
                    const SizedBox(height: 20),
                    const Text('No download history',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Completed downloads will appear here',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (history.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No results for "$_historySearch"',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, i) => _buildHistoryTile(history[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(DownloadTask task) {
    final platformColor = _platformColor(task.platform);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 24),
      ),
      onDismissed: (_) => _service.deleteHistoryItem(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1526),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            // Platform avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: platformColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  task.format == 'mp3'
                      ? Icons.music_note_rounded
                      : _platformIcon(task.platform),
                  color: platformColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _historyBadge(
                          MediaDownloaderService.getPlatformName(
                              task.platform),
                          platformColor),
                      const SizedBox(width: 6),
                      _historyBadge(task.quality, Colors.white38),
                      const SizedBox(width: 6),
                      _historyBadge(task.sizeFormatted, Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.timeAgoFormatted,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Actions
            Column(
              children: [
                GestureDetector(
                  onTap: () => _showSnack('Opening ${task.title}',
                      icon: Icons.open_in_new_rounded, success: true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kNeonGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.open_in_new_rounded, color: kNeonGreen, size: 16),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _service.deleteHistoryItem(task),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will remove all download history. This action cannot be undone.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              _service.clearHistory();
              Navigator.pop(context);
              _showSnack('History cleared', icon: Icons.delete_sweep_rounded);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
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


