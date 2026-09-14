import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/audio_service.dart';
import '../services/firebase_service.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/chat_input_bar.dart';
import 'call_screen.dart';
import 'contact_info_screen.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat';
  final String? conversationId;
  final String? participantName;
  final String? participantId;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.participantName,
    this.participantId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final AudioService _audioService = AudioService();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  String? _resolvedParticipantId;
  String? _resolvedParticipantName;
  String? _participantAvatarUrl;
  bool _isOnline = false;
  bool _isLoading = true;

  // Replying state
  Map<String, dynamic>? _replyToMessage;

  // Audio playback state
  String? _currentlyPlayingAudioUrl;
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  Timer? _audioProgressTimer;

  // Colors
  static const Color _bgVoid = Color(0xFF0C071E);
  static const Color _appBarBg = Color(0xFF140B28);
  static const Color _neonPurple = Color(0xFFB44FFF);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _subText = Color(0xFF9E8DBE);
  static const Color _whiteText = Color(0xFFF5EFFF);

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _audioProgressTimer?.cancel();
    _scrollController.dispose();
    _audioService.disposePlayer();
    if (_conversationId != null) {
      _chatService.setTypingStatus(_conversationId!, false);
    }
    super.dispose();
  }

  Future<void> _initializeChat() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      String? convId = widget.conversationId;
      String? targetUid = widget.participantId;
      String? targetName = widget.participantName;

      if (routeArgs is Map<String, dynamic>) {
        convId ??= routeArgs['conversationId'] as String?;
        targetUid ??= routeArgs['participantId'] as String?;
        targetName ??= routeArgs['participantName'] as String?;
      }

      final currentUid = _chatService.currentUserId;

      // Deterministic direct conversation ID resolution if targetUid is provided
      if (convId == null && targetUid != null && currentUid != null) {
        convId = ChatService.getDirectConversationId(currentUid, targetUid);
      } else if (targetUid == null && convId != null && convId.startsWith('direct_')) {
        final parts = convId.replaceFirst('direct_', '').split('_');
        for (final p in parts) {
          if (p.isNotEmpty && p != currentUid) {
            targetUid = p;
            break;
          }
        }
      }

      _conversationId = convId;
      _resolvedParticipantId = targetUid;
      _resolvedParticipantName = targetName;

      if (targetUid != null) {
        try {
          final profile = await FirebaseService.getUserProfile(targetUid);
          if (profile != null && mounted) {
            final rawName = profile['displayName'] ?? profile['display_name'] ?? profile['name'];
            final rawUsername = profile['username'];
            final rawEmail = profile['email'];
            final resolved = AuthService.resolveDisplayName(
              name: rawName?.toString(),
              username: rawUsername?.toString(),
              email: rawEmail?.toString(),
            );
            final isOnline = profile['isOnline'] == true || profile['online'] == true;
            final photoUrl = profile['photo_url']?.toString() ??
                profile['photoUrl']?.toString() ??
                profile['profilePicUrl']?.toString() ??
                '';

            setState(() {
              if (resolved.isNotEmpty) _resolvedParticipantName = resolved;
              _participantAvatarUrl = photoUrl;
              _isOnline = isOnline;
            });
          }
        } catch (_) {}
      }

      if (convId != null) {
        _chatService.markConversationAsRead(convId);
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _handleAudioToggle(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) return;

    if (_isPlayingAudio && _currentlyPlayingAudioUrl == audioUrl) {
      await _audioService.stopPlayer();
      _audioProgressTimer?.cancel();
      setState(() {
        _isPlayingAudio = false;
        _currentlyPlayingAudioUrl = null;
        _audioProgress = 0.0;
      });
    } else {
      await _audioService.stopPlayer();
      _audioProgressTimer?.cancel();

      setState(() {
        _currentlyPlayingAudioUrl = audioUrl;
        _isPlayingAudio = true;
        _audioProgress = 0.0;
      });

      await _audioService.play(audioUrl);

      // Simulate smooth progress visualization
      _audioProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!mounted || !_isPlayingAudio) {
          timer.cancel();
          return;
        }
        setState(() {
          _audioProgress = (_audioProgress + 0.04).clamp(0.0, 1.0);
          if (_audioProgress >= 1.0) {
            _isPlayingAudio = false;
            _currentlyPlayingAudioUrl = null;
            _audioProgress = 0.0;
            timer.cancel();
          }
        });
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (_conversationId == null) return;
    try {
      await _chatService.sendMessage(
        conversationId: _conversationId!,
        text: text,
        type: 'text',
        replyTo: _replyToMessage?['id'],
        replyText: _replyToMessage?['text'],
        replySender: _replyToMessage?['senderName'],
      );
      setState(() => _replyToMessage = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _sendImage(String filePath) async {
    if (_conversationId == null) return;
    try {
      final imageUrl = await _chatService.uploadImageMessage(_conversationId!, filePath);
      await _chatService.sendMessage(
        conversationId: _conversationId!,
        text: '',
        type: 'image',
        imageUrl: imageUrl,
        replyTo: _replyToMessage?['id'],
        replyText: _replyToMessage?['text'],
        replySender: _replyToMessage?['senderName'],
      );
      setState(() => _replyToMessage = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  Future<void> _sendFile(String filePath, String fileName) async {
    if (_conversationId == null) return;
    try {
      final fileUrl = await _chatService.uploadFileMessage(_conversationId!, filePath, fileName);
      await _chatService.sendMessage(
        conversationId: _conversationId!,
        text: '',
        type: 'file',
        fileUrl: fileUrl,
        fileName: fileName,
        replyTo: _replyToMessage?['id'],
        replyText: _replyToMessage?['text'],
        replySender: _replyToMessage?['senderName'],
      );
      setState(() => _replyToMessage = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send document: $e')),
        );
      }
    }
  }

  Future<void> _sendAudio(String audioFilePath) async {
    if (_conversationId == null) return;
    try {
      final audioUrl = await _chatService.uploadAudioMessage(_conversationId!, audioFilePath);
      await _chatService.sendMessage(
        conversationId: _conversationId!,
        text: '[Voice note]',
        type: 'audio',
        audioUrl: audioUrl,
        replyTo: _replyToMessage?['id'],
        replyText: _replyToMessage?['text'],
        replySender: _replyToMessage?['senderName'],
      );
      setState(() => _replyToMessage = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send audio message: $e')),
        );
      }
    }
  }

  Future<void> _startCall(bool isVideo) async {
    final receiverId = _resolvedParticipantId;
    if (receiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call recipient not available.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          receiverId: receiverId,
          receiverName: _resolvedParticipantName ?? widget.participantName ?? 'Operative',
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _openContactInfo() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: _resolvedParticipantName ?? widget.participantName ?? 'Operative',
          participantId: _resolvedParticipantId,
          conversationId: _conversationId,
          avatarUrl: _participantAvatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatName = _resolvedParticipantName?.isNotEmpty == true
        ? _resolvedParticipantName!
        : (widget.participantName?.isNotEmpty == true ? widget.participantName! : 'Operative');
    final initial = chatName.isNotEmpty ? chatName[0].toUpperCase() : 'O';

    return Scaffold(
      backgroundColor: _bgVoid,
      appBar: AppBar(
        backgroundColor: _appBarBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _whiteText, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: InkWell(
          onTap: _openContactInfo,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFF261247),
                      backgroundImage: _participantAvatarUrl != null && _participantAvatarUrl!.isNotEmpty
                          ? NetworkImage(_participantAvatarUrl!)
                          : null,
                      child: _participantAvatarUrl == null || _participantAvatarUrl!.isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: _neonCyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: _isOnline ? _neonGreen : const Color(0xFF747F8D),
                          shape: BoxShape.circle,
                          border: Border.all(color: _appBarBg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chatName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _whiteText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _neonPurple.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: _neonPurple,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Realtime typing or presence indicator
                      if (_conversationId != null)
                        StreamBuilder<List<String>>(
                          stream: _chatService.getTypingUsersStream(_conversationId!),
                          builder: (context, snapshot) {
                            final typers = snapshot.data ?? [];
                            if (typers.isNotEmpty) {
                              return const Text(
                                'typing...',
                                style: TextStyle(
                                  color: _neonCyan,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                            return Text(
                              _isOnline ? 'Online • Direct Comms' : 'Offline',
                              style: TextStyle(
                                color: _isOnline ? _neonGreen : _subText,
                                fontSize: 11.5,
                              ),
                            );
                          },
                        )
                      else
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _isOnline ? _neonGreen : _subText,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _startCall(false),
            icon: const Icon(Icons.call_rounded, color: _whiteText, size: 21),
            tooltip: 'Voice Call',
          ),
          IconButton(
            onPressed: () => _startCall(true),
            icon: const Icon(Icons.videocam_rounded, color: _whiteText, size: 22),
            tooltip: 'Video Call',
          ),
          IconButton(
            onPressed: _openContactInfo,
            icon: const Icon(Icons.info_outline_rounded, color: _whiteText, size: 22),
            tooltip: 'Info',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonPurple))
          : Column(
              children: [
                Expanded(child: _buildMessagesStream()),
                if (_conversationId != null)
                  ChatInputBar(
                    conversationId: _conversationId!,
                    replyTo: _replyToMessage,
                    hintText: 'Message @$chatName',
                    onCancelReply: () => setState(() => _replyToMessage = null),
                    onSendMessage: _sendMessage,
                    onSendImage: _sendImage,
                    onSendFile: _sendFile,
                    onSendAudio: _sendAudio,
                    onTypingChanged: (isTyping) {
                      if (_conversationId != null) {
                        _chatService.setTypingStatus(_conversationId!, isTyping);
                      }
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildMessagesStream() {
    if (_conversationId == null) {
      return const Center(
        child: Text('Invalid conversation channel.', style: TextStyle(color: _subText)),
      );
    }

    final currentUid = _chatService.currentUserId;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getMessages(_conversationId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _neonPurple));
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _neonPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _neonPurple.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.forum_rounded, color: _neonCyan, size: 34),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Encrypted channel opened',
                  style: TextStyle(color: _whiteText, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Send a message to initiate comms.',
                  style: TextStyle(color: _subText, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // index 0 is newest message at the bottom
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final messageId = msg['id']?.toString() ?? 'msg_$index';
            final isMine = msg['senderId'] == currentUid;
            final isAudioPlaying = _isPlayingAudio && _currentlyPlayingAudioUrl == msg['audioUrl'];

            return MessageBubble(
              data: msg,
              isMine: isMine,
              senderName: isMine ? 'You' : (_resolvedParticipantName ?? 'Operative'),
              isPlayingAudio: isAudioPlaying,
              audioProgress: isAudioPlaying ? _audioProgress : 0.0,
              onPlayAudio: () => _handleAudioToggle(msg['audioUrl']),
              onReply: (replyData) => setState(() => _replyToMessage = replyData),
              onDelete: (delId) => _chatService.deleteMessage(_conversationId!, delId),
              onToggleReaction: (emoji) => _chatService.toggleReaction(_conversationId!, messageId, emoji),
            );
          },
        );
      },
    );
  }
}
