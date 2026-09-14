import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/reel_service.dart';
import '../utils/constants.dart';

class VideoPostScreen extends StatefulWidget {
  static const routeName = '/video-post';
  const VideoPostScreen({super.key});

  @override
  State<VideoPostScreen> createState() => _VideoPostScreenState();
}

class _VideoPostScreenState extends State<VideoPostScreen>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();
  bool _isAiWorking = false;
  String _captionSuggestion = '';
  String _hashtagSuggestion = '';
  String _selectedEffect = 'cinematic';
  String _mediaLabel = 'Tap to choose a clip';
  bool _allowComments = true;
  bool _allowDuets = true;
  bool _allowStitches = true;
  bool _isUploadingReel = false;
  double _uploadProgress = 0.0;
  String? _selectedVideoPath;
  late AnimationController _animController;
  final ReelService _reelService = ReelService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateCaption() async {
    setState(() {
      _isAiWorking = true;
      _captionSuggestion = '';
    });

    final prompt = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : 'Create a short NEX-Reels caption that goes viral.';

    final caption = await AIService.instance.generateCaption(prompt);

    if (!mounted) return;
    setState(() {
      _captionSuggestion = caption;
      _isAiWorking = false;
    });
    _animController.forward(from: 0);
  }

  Future<void> _suggestHashtags() async {
    setState(() {
      _isAiWorking = true;
      _hashtagSuggestion = '';
    });

    final prompt = _titleController.text.isNotEmpty
        ? _titleController.text
        : 'Generate trending hashtags for NEX-Reels.';
    final hashtags = await AIService.instance.suggestHashtags(prompt);

    if (!mounted) return;
    setState(() {
      _hashtagSuggestion = hashtags;
      _isAiWorking = false;
    });
    _animController.forward(from: 0);
  }

  void _pickMedia(String source) async {
    final result = await FilePicker.pickFile(type: FileType.video);

    if (result == null || result.path == null || result.path!.isEmpty) return;

    _selectedVideoPath = result.path;
    if (!mounted) return;
    setState(() {
      _mediaLabel = _selectedVideoPath != null ? 'Reel clip selected' : 'Tap to choose a clip';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selectedVideoPath != null ? 'Reel clip ready.' : 'No video selected.')),
      );
    }
  }

  Future<void> _publishReel() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a title to publish your reel.')));
      return;
    }
    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a video clip before publishing.')));
      return;
    }

    setState(() {
      _isUploadingReel = true;
      _uploadProgress = 0.0;
    });

    try {
      final file = File(_selectedVideoPath!);
      final fileName = file.uri.pathSegments.last;
      final mediaUrl = await _reelService.uploadReelVideo(
        _selectedVideoPath!,
        onProgress: (uploadedBytes, totalBytes) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = totalBytes > 0 ? uploadedBytes / totalBytes : 0.0;
          });
        },
      );

      await _reelService.createReelRecord(
        title: title,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : 'Fresh from NEX-Reels',
        hashtags: _hashtagsController.text.trim().isNotEmpty ? _hashtagsController.text.trim() : '#NEXReels #FreshClip',
        mediaUrl: mediaUrl,
        duration: '0:18',
        style: _selectedEffect,
        fileName: fileName,
      );

      if (!mounted) return;
      Navigator.pop(context, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'username': 'you',
        'avatar': 'Y',
        'title': title,
        'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : 'Fresh from NEX-Reels',
        'hashtags': _hashtagsController.text.trim().isNotEmpty ? _hashtagsController.text.trim() : '#NEXReels #FreshClip',
        'duration': '0:18',
        'mediaLabel': _mediaLabel,
        'accent': kNeonPurple,
        'effect': _selectedEffect,
        'allowComments': _allowComments,
        'allowDuets': _allowDuets,
        'allowStitches': _allowStitches,
        'mediaUrl': mediaUrl,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingReel = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kNeonPurple, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reel Studio', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kNeonPurple.withValues(alpha: 0.2), kNeonBlue.withValues(alpha: 0.15)]),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.surface, kDarkBackground],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Reel preview', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [kNeonPurple, kNeonPurple.withValues(alpha: 0.7)]),
                                  ),
                                  child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _mediaLabel,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (_isUploadingReel)
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24, width: 2),
                                    ),
                                    child: Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 42,
                                            height: 42,
                                            child: CircularProgressIndicator(
                                              value: _uploadProgress,
                                              color: kNeonGreen,
                                              strokeWidth: 3.5,
                                            ),
                                          ),
                                          const Icon(Icons.cloud_upload, color: Colors.white70, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, size: 64, color: kNeonPurple),
                            const SizedBox(height: 14),
                            const Text('Ready to publish', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(_selectedVideoPath != null ? 'Selected clip loaded' : 'No clip selected yet', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Row(
                          children: [
                            Expanded(child: _buildMediaButton(Icons.videocam_rounded, 'Select clip', kNeonBlue, () => _pickMedia('camera'))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMediaButton(Icons.collections_rounded, 'Library', kNeonGreen, () => _pickMedia('gallery'))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildInputHeader('Title'),
              _buildStudioTextField(controller: _titleController, hint: 'What is this reel about?', icon: Icons.title_rounded, color: kNeonPurple),
              const SizedBox(height: 16),
              _buildInputHeader('Description'),
              _buildStudioTextField(controller: _descriptionController, hint: 'Tell people why they should watch', icon: Icons.description_outlined, color: kNeonGreen, maxLines: 4, maxLength: 500),
              const SizedBox(height: 16),
              _buildInputHeader('Hashtags'),
              _buildStudioTextField(controller: _hashtagsController, hint: '#NEXReels #FreshClip', icon: Icons.tag_rounded, color: kNeonBlue, maxLength: 30),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: kNeonBlue, size: 18),
                        SizedBox(width: 8),
                        Text('AI Magic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildAIActionButton(onPressed: _isAiWorking ? null : _generateCaption, icon: Icons.lightbulb_outline, label: 'Caption', color: kNeonBlue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildAIActionButton(onPressed: _isAiWorking ? null : _suggestHashtags, icon: Icons.tag_faces_outlined, label: 'Tags', color: kNeonGreen, darkText: true)),
                      ],
                    ),
                    if (_isAiWorking) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(color: kNeonBlue),
                    ],
                    if (_captionSuggestion.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSuggestionNode('Caption suggestion', _captionSuggestion, () => _descriptionController.text = _captionSuggestion),
                    ],
                    if (_hashtagSuggestion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSuggestionNode('Hashtag suggestion', _hashtagSuggestion, () => _hashtagsController.text = _hashtagSuggestion),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildInputHeader('Visual style'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['cinematic', 'vivid', 'clean', 'night'].map((effect) {
                    final selected = _selectedEffect == effect;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(effect.toUpperCase()),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedEffect = effect),
                        selectedColor: kNeonPurple,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _buildPrivacyToggle('Allow comments', _allowComments, (value) => setState(() => _allowComments = value)),
              _buildPrivacyToggle('Allow duets', _allowDuets, (value) => setState(() => _allowDuets = value)),
              _buildPrivacyToggle('Allow stitches', _allowStitches, (value) => setState(() => _allowStitches = value)),
              const SizedBox(height: 20),
              _buildPrimaryActionButton(label: 'Publish reel', icon: Icons.rocket_launch_rounded, color: kNeonPurple, onPressed: _publishReel),
              const SizedBox(height: 12),
              _buildSecondaryActionButton(label: 'Save draft', icon: Icons.save_alt_rounded, color: kNeonGreen, onPressed: _saveDraft),
            ],
          ),
        ),
      ),
    );
  }

  // --- Pro Studio UI Helpers ---

  Widget _buildInputHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(
        label,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2),
      ),
    );
  }

  Widget _buildPrivacyToggle(
      String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: kNeonPurple,
              activeTrackColor: kNeonPurple.withValues(alpha: 0.2),
              inactiveThumbColor: Colors.white24,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.black),
        label: Text(label,
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 13)),
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _buildSecondaryActionButton(
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSuggestionNode(
      String title, String content, VoidCallback onUse) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kNeonBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kNeonBlue.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: kNeonBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(content,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUse,
              child: const Text('APPLY_DATA',
                  style: TextStyle(
                      color: kNeonBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MISSING HELPERS TO ENSURE COMPILATION ---

extension _VideoPostHelpers on _VideoPostScreenState {
  Widget _buildMediaButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon,
            size: 18, color: color == kNeonGreen ? Colors.black : Colors.white),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
            color: color == kNeonGreen ? Colors.black : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildStudioTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color color,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E36).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white12),
          prefixIcon: Icon(icon, color: color, size: 20),
          counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildAIActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool darkText = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
          color: darkText ? Colors.black : Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: darkText ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.3),
      ),
    );
  }
}
