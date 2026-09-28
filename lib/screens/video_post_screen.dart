import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/ai_service.dart';
import '../services/reel_service.dart';

class VideoPostScreen extends StatefulWidget {
  static const routeName = '/video-post';
  const VideoPostScreen({super.key});

  @override
  State<VideoPostScreen> createState() => _VideoPostScreenState();
}

class _VideoPostScreenState extends State<VideoPostScreen> with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();

  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  bool _isAiWorking = false;
  String _captionSuggestion = '';
  String _hashtagSuggestion = '';
  String _selectedEffect = 'cinematic';
  String _videoDurationFormatted = '0:00';
  int _videoSizeBytes = 0;

  bool _allowComments = true;
  bool _allowDuets = true;
  bool _allowStitches = true;
  bool _isUploadingReel = false;
  double _uploadProgress = 0.0;
  String? _selectedVideoPath;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  final ReelService _reelService = ReelService();

  final Color _cyberCyan = const Color(0xFF00E5FF);
  final Color _cyberPurple = const Color(0xFFB026FF);
  final Color _cyberGreen = const Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearMaterialBanners();
      _loadCreatorIdentity();
    });
  }

  String _creatorName = '';
  String _creatorAvatar = '';
  bool _useCustomAvatar = false;

  Future<void> _loadCreatorIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final profile = await _reelService.getCreatorProfile(user.uid);
    if (!mounted) return;
    setState(() {
      _useCustomAvatar = profile['useCustomReelsAvatar'] == true;
      final customAvatar = profile['reelsAvatar']?.toString() ?? '';
      final customName = profile['reelsCreatorName']?.toString() ?? '';
      _creatorName = (_useCustomAvatar && customName.isNotEmpty)
          ? customName
          : (profile['username']?.toString() ?? user.displayName ?? user.email?.split('@').first ?? 'Operative');
      _creatorAvatar = (_useCustomAvatar && customAvatar.isNotEmpty)
          ? customAvatar
          : (profile['photo_url']?.toString() ?? user.photoURL ?? '');
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagsController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.pickFile(
      type: FileType.video,
    );

    if (result == null || result.path == null || result.path!.isEmpty) return;

    final filePath = result.path!;
    final file = File(filePath);
    final size = await file.length();

    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(file);

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.setLooping(true);
      await _videoPlayerController!.play();

      final dur = _videoPlayerController!.value.duration;
      final mins = dur.inMinutes;
      final secs = (dur.inSeconds % 60).toString().padLeft(2, '0');

      if (!mounted) return;
      setState(() {
        _selectedVideoPath = filePath;
        _videoSizeBytes = size;
        _videoDurationFormatted = '$mins:$secs';
        _isVideoInitialized = true;
        _isVideoPlaying = true;
      });
    } catch (e) {
      debugPrint('[VideoPostScreen] Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _selectedVideoPath = filePath;
          _videoSizeBytes = size;
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null || !_isVideoInitialized) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        _isVideoPlaying = false;
      } else {
        _videoPlayerController!.play();
        _isVideoPlaying = true;
      }
    });
  }

  Future<void> _generateCaption() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAiWorking = true;
      _captionSuggestion = '';
    });

    final prompt = _titleController.text.isNotEmpty
        ? _titleController.text
        : (_descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : 'Futuristic viral cyber reel');

    final caption = await AIService.instance.generateCaption(prompt);

    if (!mounted) return;
    setState(() {
      _captionSuggestion = caption;
      _isAiWorking = false;
    });
  }

  Future<void> _suggestHashtags() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAiWorking = true;
      _hashtagSuggestion = '';
    });

    final prompt = _titleController.text.isNotEmpty
        ? _titleController.text
        : 'Cyberpunk futuristic tech and gaming';
    final hashtags = await AIService.instance.suggestHashtags(prompt);

    if (!mounted) return;
    setState(() {
      _hashtagSuggestion = hashtags;
      _isAiWorking = false;
    });
  }

  Future<void> _publishReel() async {
    HapticFeedback.heavyImpact();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add a title for your reel.'),
          backgroundColor: const Color(0xFF1E0A24),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFB026FF), width: 1),
          ),
        ),
      );
      return;
    }

    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a video clip to broadcast.'),
          backgroundColor: const Color(0xFF1E0A24),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFB026FF), width: 1),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploadingReel = true;
      _uploadProgress = 0.05;
    });

    try {
      final file = File(_selectedVideoPath!);
      final fileName = file.uri.pathSegments.last;

      final mediaUrl = await _reelService.uploadReelVideo(
        _selectedVideoPath!,
        onProgress: (uploadedBytes, totalBytes) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = totalBytes > 0 ? (uploadedBytes / totalBytes) : 0.2;
          });
        },
      );

      final desc = _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : 'Broadcast from NEX Studio';
      final tags = _hashtagsController.text.trim().isNotEmpty
          ? _hashtagsController.text.trim()
          : '#NEXStudio #CyberReel';

      await _reelService.createReelRecord(
        title: title,
        description: desc,
        hashtags: tags,
        mediaUrl: mediaUrl,
        duration: _videoDurationFormatted,
        style: _selectedEffect,
        fileName: fileName,
        authorName: _creatorName.isNotEmpty ? _creatorName : null,
        authorPic: _creatorAvatar.isNotEmpty ? _creatorAvatar : null,
        publishingIdentity: _useCustomAvatar ? 'custom' : 'general',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88)),
              SizedBox(width: 8),
              Text('Reel broadcast live to NEXUS!'),
            ],
          ),
          backgroundColor: const Color(0xFF0A1E14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF00FF88), width: 1),
          ),
        ),
      );

      Navigator.pop(context, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'description': desc,
        'hashtags': tags,
        'duration': _videoDurationFormatted,
        'mediaUrl': mediaUrl,
        'style': _selectedEffect,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingReel = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04060E),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF04060E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00E5FF), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _cyberPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cyberPurple.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Color(0xFFB026FF), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'REEL STUDIO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickMedia,
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF00E5FF), size: 16),
            label: Text(
              _selectedVideoPath != null ? 'CHANGE' : 'IMPORT',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Cyber Live Video Player Preview ───────────────────────
              _buildVideoPreviewSection(),

              const SizedBox(height: 16),

              // ── 1B. Creator Identity Persona Banner ───────────────────────
              _buildCreatorIdentityBadge(),

              const SizedBox(height: 16),

              // ── 2. Meta Inputs (Title, Description, Hashtags) ────────────
              _buildSectionHeader('BROADCAST DETAILS', Icons.edit_note_rounded, _cyberCyan),
              const SizedBox(height: 10),

              _buildCyberInput(
                controller: _titleController,
                hintText: 'Enter an electrifying reel title...',
                label: 'REEL TITLE',
                icon: Icons.title_rounded,
                accentColor: _cyberCyan,
                maxLength: 80,
              ),

              const SizedBox(height: 12),

              _buildCyberInput(
                controller: _descriptionController,
                hintText: 'Describe your clip, storyline, or tech breakdown...',
                label: 'CAPTION / DESCRIPTION',
                icon: Icons.description_rounded,
                accentColor: _cyberGreen,
                maxLines: 3,
                maxLength: 400,
              ),

              const SizedBox(height: 12),

              _buildCyberInput(
                controller: _hashtagsController,
                hintText: '#NEXUS #Cyberpunk #Tech #Gaming',
                label: 'CYBER HASHTAGS',
                icon: Icons.tag_rounded,
                accentColor: _cyberPurple,
                maxLength: 100,
              ),

              const SizedBox(height: 18),

              // ── 3. AI Copilot Generation Hub ─────────────────────────────
              _buildAiAssistantHub(),

              const SizedBox(height: 20),

              // ── 4. Visual Shading Styles ─────────────────────────────────
              _buildSectionHeader('CYBER VISUAL FILTER', Icons.tune_rounded, const Color(0xFFFFD700)),
              const SizedBox(height: 10),
              _buildVisualEffectChips(),

              const SizedBox(height: 20),

              // ── 5. Operative Permissions & Privacy ───────────────────────
              _buildSectionHeader('NETWORK PROTOCOLS', Icons.security_rounded, _cyberCyan),
              const SizedBox(height: 10),
              _buildProtocolCard(),

              const SizedBox(height: 24),

              // ── 6. Publish Action Bar ─────────────────────────────────────
              _buildPublishButton(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Video Preview Section ──────────────────────────────────────────────────
  Widget _buildVideoPreviewSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF090D1C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _selectedVideoPath != null
              ? _cyberCyan.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          if (_selectedVideoPath != null)
            BoxShadow(
              color: _cyberCyan.withValues(alpha: 0.2),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: _isVideoInitialized && _videoPlayerController != null
            ? _buildLiveVideoPlayer()
            : _buildEmptyVideoPlaceholder(),
      ),
    );
  }

  Widget _buildLiveVideoPlayer() {
    return Column(
      children: [
        GestureDetector(
          onTap: _togglePlayPause,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio > 0
                    ? _videoPlayerController!.value.aspectRatio
                    : (16 / 9),
                child: VideoPlayer(_videoPlayerController!),
              ),

              // Overlay Play/Pause indicator when paused
              if (!_isVideoPlaying)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: _cyberCyan, width: 2),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                ),

            ],
          ),
        ),

        // Video Player Scrub Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF060914),
          child: Row(
            children: [
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isVideoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _cyberCyan,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VideoProgressIndicator(
                  _videoPlayerController!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: _cyberCyan,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _videoDurationFormatted,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),

        // Clean Unobstructed Telemetry & Stream Status Strip (Under Player)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF03050B),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              const Icon(Icons.fiber_manual_record, color: Color(0xFF00FF88), size: 10),
              const SizedBox(width: 6),
              const Text(
                'LOADED READY',
                style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              const Icon(Icons.videocam_rounded, color: Color(0xFF00E5FF), size: 13),
              const SizedBox(width: 4),
              Text(
                '$_videoDurationFormatted • ${_formatSize(_videoSizeBytes)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyVideoPlaceholder() {
    return InkWell(
      onTap: _pickMedia,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_cyberCyan.withValues(alpha: 0.25), _cyberPurple.withValues(alpha: 0.25)],
                ),
                border: Border.all(color: _cyberCyan.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF00E5FF), size: 34),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select Reel Video Clip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Supports MP4, MOV, WebM clips (Max 50MB)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('CHOOSE FROM DEVICE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyberCyan.withValues(alpha: 0.2),
                foregroundColor: _cyberCyan,
                side: BorderSide(color: _cyberCyan.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Creator Identity Persona Widget ───────────────────────────────────────
  Widget _buildCreatorIdentityBadge() {
    final displayName = _creatorName.isNotEmpty ? _creatorName : 'Operative';
    final hasAvatar = _creatorAvatar.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cyberPurple.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: _cyberPurple.withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_cyberCyan, _cyberPurple],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipOval(
              child: hasAvatar
                  ? Image.network(
                      _creatorAvatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'BROADCASTING IDENTITY',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 12),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@$displayName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _loadCreatorIdentity,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_rounded, color: Color(0xFF00E5FF), size: 13),
                  SizedBox(width: 4),
                  Text(
                    'SYNCED',
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cyber Input Widget ─────────────────────────────────────────────────────
  Widget _buildCyberInput({
    required TextEditingController controller,
    required String hintText,
    required String label,
    required IconData icon,
    required Color accentColor,
    int maxLines = 1,
    int maxLength = 100,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              border: InputBorder.none,
              counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Copilot Generation Hub ──────────────────────────────────────────────
  Widget _buildAiAssistantHub() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cyberPurple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFB026FF), size: 16),
              const SizedBox(width: 6),
              const Text(
                'AI STUDIO COPILOT',
                style: TextStyle(
                  color: Color(0xFFB026FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              if (_isAiWorking)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB026FF)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAiWorking ? null : _generateCaption,
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 14),
                  label: const Text('GENERATE CAPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cyberCyan,
                    side: BorderSide(color: _cyberCyan.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAiWorking ? null : _suggestHashtags,
                  icon: const Icon(Icons.tag_rounded, size: 14),
                  label: const Text('AUTO HASHTAGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cyberGreen,
                    side: BorderSide(color: _cyberGreen.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          if (_captionSuggestion.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildAiSuggestionPill(
              title: 'Suggested Caption',
              content: _captionSuggestion,
              onApply: () {
                setState(() => _descriptionController.text = _captionSuggestion);
                HapticFeedback.selectionClick();
              },
            ),
          ],

          if (_hashtagSuggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAiSuggestionPill(
              title: 'Suggested Hashtags',
              content: _hashtagSuggestion,
              onApply: () {
                setState(() => _hashtagsController.text = _hashtagSuggestion);
                HapticFeedback.selectionClick();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiSuggestionPill({
    required String title,
    required String content,
    required VoidCallback onApply,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onApply,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: _cyberCyan.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('APPLY', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ── Visual Effect Chips ────────────────────────────────────────────────────
  Widget _buildVisualEffectChips() {
    final styles = [
      {'id': 'cinematic', 'name': 'CINEMATIC'},
      {'id': 'vivid', 'name': 'NEO-TOKYO'},
      {'id': 'matrix', 'name': 'CYBER MATRIX'},
      {'id': 'night', 'name': 'NIGHT VISION'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: styles.map((style) {
          final isSelected = _selectedEffect == style['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(style['name']!),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedEffect = style['id']!);
              },
              selectedColor: _cyberPurple.withValues(alpha: 0.35),
              backgroundColor: const Color(0xFF0B1020),
              side: BorderSide(
                color: isSelected ? _cyberPurple : Colors.white12,
                width: 1.2,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Network Protocols (Privacy) ────────────────────────────────────────────
  Widget _buildProtocolCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildSwitchRow(
            label: 'Allow Operative Comments',
            subtitle: 'Users across the Nexus can post comments',
            value: _allowComments,
            onChanged: (v) => setState(() => _allowComments = v),
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow(
            label: 'Allow Duet Collaborations',
            subtitle: 'Let other operatives record side-by-side clips',
            value: _allowDuets,
            onChanged: (v) => setState(() => _allowDuets = v),
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow(
            label: 'Allow Stitch Remixes',
            subtitle: 'Allow video stitching into external reels',
            value: _allowStitches,
            onChanged: (v) => setState(() => _allowStitches = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          activeThumbColor: _cyberCyan,
          activeTrackColor: _cyberCyan.withValues(alpha: 0.3),
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white12,
        ),
      ],
    );
  }

  // ── Publish Action Bar ─────────────────────────────────────────────────────
  Widget _buildPublishButton() {
    if (_isUploadingReel) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1224),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cyberCyan.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'BROADCASTING REEL TO NEXUS...',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.white12,
                color: _cyberCyan,
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_cyberPurple, _cyberCyan],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _cyberPurple.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _publishReel,
        icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
        label: const Text(
          'BROADCAST REEL TO NEXUS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
