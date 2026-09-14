import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/audio_service.dart';
import '../token_purchase_sheet.dart';

class ChatInputBar extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onCancelReply;
  final ValueChanged<String>? onSendMessage;
  final ValueChanged<String>? onSendImage;
  final void Function(String filePath, String originalName)? onSendFile;
  final ValueChanged<String>? onSendAudio;
  final ValueChanged<bool>? onTypingChanged;
  final String? hintText;

  const ChatInputBar({
    super.key,
    required this.conversationId,
    this.replyTo,
    this.onCancelReply,
    this.onSendMessage,
    this.onSendImage,
    this.onSendFile,
    this.onSendAudio,
    this.onTypingChanged,
    this.hintText,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  final AudioService _audioService = AudioService();
  bool _isComposing = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _typingDebounce;
  String? _currentAudioPath;
  bool _showEmojiDrawer = false;

  static const Color _barBg = Color(0xFF140B28);
  static const Color _inputPillBg = Color(0xFF201330);
  static const Color _neonPurple = Color(0xFFB44FFF);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _goldToken = Color(0xFFFFB800);
  static const Color _subText = Color(0xFF9E8DBE);
  static const Color _whiteText = Color(0xFFF5EFFF);

  static const List<String> _quickEmojis = [
    '😀', '😂', '😍', '🔥', '👍', '🚀', '❤️', '🎉',
    '💯', '🎮', '👾', '⚡', '🌙', '⭐', '💎', '🛡️',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _typingDebounce?.cancel();
    _textController.dispose();
    _audioService.disposeRecorder();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _textController.text.trim();
    final composing = text.isNotEmpty;
    if (composing != _isComposing) {
      setState(() => _isComposing = composing);
    }

    if (composing) {
      widget.onTypingChanged?.call(true);
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        widget.onTypingChanged?.call(false);
      });
    } else {
      widget.onTypingChanged?.call(false);
    }
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSendMessage?.call(text);
    _textController.clear();
    widget.onTypingChanged?.call(false);
    _typingDebounce?.cancel();
  }

  Future<void> _startRecording() async {
    try {
      HapticFeedback.mediumImpact();
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      _currentAudioPath = path;
      await _audioService.startRecording(path);

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    try {
      HapticFeedback.lightImpact();
      await _audioService.stopRecording();
      setState(() => _isRecording = false);
      if (_currentAudioPath != null && _recordSeconds >= 1) {
        widget.onSendAudio?.call(_currentAudioPath!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      HapticFeedback.selectionClick();
      await _audioService.stopRecording();
      if (_currentAudioPath != null) {
        final f = File(_currentAudioPath!);
        if (await f.exists()) await f.delete();
      }
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  String _formatRecordTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showAttachmentSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140B28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'SHARE CONTENT',
                style: TextStyle(
                  color: _subText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOption(
                    icon: Icons.image_rounded,
                    label: 'Photo',
                    color: _neonCyan,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await FilePicker.pickFile(type: FileType.image);
                      if (result != null && result.path != null) {
                        widget.onSendImage?.call(result.path!);
                      }
                    },
                  ),
                  _buildOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: _neonPurple,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await FilePicker.pickFile();
                      if (result != null && result.path != null) {
                        widget.onSendFile?.call(
                          result.path!,
                          result.name,
                        );
                      }
                    },
                  ),
                  _buildOption(
                    icon: Icons.monetization_on_rounded,
                    label: 'Tokens',
                    color: _goldToken,
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const TokenPurchaseSheet(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: _whiteText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _barBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quoted reply banner
          if (widget.replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF24143D),
                border: Border(
                  left: BorderSide(color: _neonPurple, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${widget.replyTo!['senderName'] ?? 'User'}',
                          style: const TextStyle(
                            color: _neonCyan,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyTo!['text'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _subText, size: 18),
                    onPressed: widget.onCancelReply,
                  ),
                ],
              ),
            ),

          // Main input row or Audio Recording HUD
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: _isRecording ? _buildRecordingHUD() : _buildTextInputRow(),
          ),

          // Quick emoji drawer
          if (_showEmojiDrawer) _buildQuickEmojiDrawer(),
        ],
      ),
    );
  }

  Widget _buildRecordingHUD() {
    return Row(
      children: [
        // Pulsing red recording dot
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatRecordTime(_recordSeconds),
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Recording voice note...',
            style: TextStyle(color: _subText, fontSize: 13),
          ),
        ),
        // Cancel button
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        // Send recording button
        GestureDetector(
          onTap: _stopAndSendRecording,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _neonPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputRow() {
    return Row(
      children: [
        // Attachment Button
        GestureDetector(
          onTap: _showAttachmentSheet,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _inputPillBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(Icons.add_rounded, color: _subText, size: 22),
          ),
        ),
        const SizedBox(width: 8),

        // Input pill container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _inputPillBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: _whiteText, fontSize: 15),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _submitText(),
                    decoration: InputDecoration(
                      hintText: widget.hintText ?? 'Message...',
                      hintStyle: const TextStyle(color: _subText, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                // Emoji toggle button
                IconButton(
                  icon: Icon(
                    _showEmojiDrawer ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                    color: _showEmojiDrawer ? _neonCyan : _subText,
                    size: 21,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showEmojiDrawer = !_showEmojiDrawer);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Send or Record Button
        GestureDetector(
          onTap: _isComposing ? _submitText : _startRecording,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isComposing ? _neonPurple : _inputPillBg,
              shape: BoxShape.circle,
              boxShadow: _isComposing
                  ? [
                      BoxShadow(
                        color: _neonPurple.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              _isComposing ? Icons.send_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickEmojiDrawer() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF100822),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickEmojis.length,
        itemBuilder: (context, index) {
          final emoji = _quickEmojis[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _textController.text += emoji;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        },
      ),
    );
  }
}
