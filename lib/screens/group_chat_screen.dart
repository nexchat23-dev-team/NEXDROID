import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/audio_service.dart';
import '../services/firebase_service.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/chat_input_bar.dart';
import 'group_info_screen.dart';
import 'group_invite_screen.dart';
import 'call_screen.dart';

class GroupChatScreen extends StatefulWidget {
  static const routeName = '/group-chat';
  final String? conversationId;

  const GroupChatScreen({super.key, this.conversationId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ChatService _chatService = ChatService();
  final AudioService _audioService = AudioService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _groupNameController = TextEditingController();

  String? _conversationId;
  String _groupName = 'Syndicate Squad';
  List<String> _members = [];
  List<String> _admins = [];
  bool _isLoading = true;
  bool _isCreating = false;

  // Member name cache for fast rendering
  final Map<String, String> _memberNamesCache = {};

  // Reply state
  Map<String, dynamic>? _replyToMessage;

  // Audio playback state
  String? _currentlyPlayingAudioUrl;
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  Timer? _audioProgressTimer;

  // Cyberpunk Palette
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
    _initializeGroup();
  }

  @override
  void dispose() {
    _audioProgressTimer?.cancel();
    _scrollController.dispose();
    _groupNameController.dispose();
    _audioService.disposePlayer();
    if (_conversationId != null) {
      _chatService.setTypingStatus(_conversationId!, false);
    }
    super.dispose();
  }

  Future<void> _initializeGroup() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      final routeConvId = routeArgs is Map<String, dynamic>
          ? routeArgs['conversationId'] as String?
          : (routeArgs is String ? routeArgs : null);

      final convId = widget.conversationId ?? routeConvId;

      if (convId != null) {
        _conversationId = convId;
        await _loadGroupDetails();
      } else {
        _showCreateGroupDialog();
      }

      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _loadGroupDetails() async {
    if (_conversationId == null) return;
    try {
      _chatService.markConversationAsRead(_conversationId!);
      final data = await _chatService.getConversation(_conversationId!);
      if (mounted) {
        setState(() {
          _groupName = data['groupName'] ?? 'Syndicate Squad';
          _members = List<String>.from(data['participants'] ?? []);
          _admins = List<String>.from(data['admins'] ?? []);
        });

        // Prefetch member names in background
        for (final uid in _members) {
          _fetchMemberName(uid);
        }
      }
    } catch (e) {
      debugPrint('[GroupChatScreen] loadGroupDetails note: $e');
    }
  }

  Future<void> _fetchMemberName(String uid) async {
    if (_memberNamesCache.containsKey(uid)) return;
    try {
      final prof = await FirebaseService.getUserProfile(uid);
      if (prof != null && mounted) {
        final rawName = prof['displayName'] ?? prof['display_name'] ?? prof['name'];
        final resolved = AuthService.resolveDisplayName(
          name: rawName?.toString(),
          username: prof['username']?.toString(),
          email: prof['email']?.toString(),
        );
        setState(() {
          _memberNamesCache[uid] = resolved.isNotEmpty ? resolved : 'Operative';
        });
      }
    } catch (_) {}
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF160B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: _neonPurple.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.group_add_rounded, color: _neonCyan, size: 26),
            SizedBox(width: 10),
            Text('Create Syndicate', style: TextStyle(color: _whiteText, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a squad or clan name for your group channel:',
              style: TextStyle(color: _subText, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _groupNameController,
              autofocus: true,
              style: const TextStyle(color: _whiteText),
              decoration: InputDecoration(
                hintText: 'e.g. Cyber Squad Omega',
                hintStyle: TextStyle(color: _subText.withValues(alpha: 0.6)),
                filled: true,
                fillColor: const Color(0xFF201330),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _neonPurple, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.maybePop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: _subText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              await _createGroup(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    setState(() => _isCreating = true);
    try {
      final currentUid = _chatService.currentUserId;
      if (currentUid == null) throw Exception('No user logged in.');

      final convId = await _chatService.createConversation(
        participantIds: [currentUid],
        groupName: name,
        isGroup: true,
      );

      setState(() {
        _conversationId = convId;
        _groupName = name;
        _members = [currentUid];
        _admins = [currentUid];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send voice note: $e')));
      }
    }
  }

  void _showAddMemberDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Squad Operative', style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _whiteText),
          decoration: InputDecoration(
            hintText: 'Enter Operative UID',
            hintStyle: TextStyle(color: _subText.withValues(alpha: 0.6)),
            filled: true,
            fillColor: const Color(0xFF201330),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _subText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = controller.text.trim();
              if (uid.isNotEmpty && _conversationId != null) {
                Navigator.pop(ctx);
                await _chatService.addMember(_conversationId!, uid);
                setState(() => _members.add(uid));
                _fetchMemberName(uid);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonPurple),
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openGroupInfo() {
    if (_conversationId == null) return;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          conversationId: _conversationId!,
          groupName: _groupName,
          members: _members,
          admins: _admins,
        ),
      ),
    );
  }

  void _openGroupInvite() {
    if (_conversationId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInviteScreen(
          conversationId: _conversationId!,
          groupName: _groupName,
        ),
      ),
    );
  }

  Future<void> _startGroupCall(bool isVideo) async {
    final currentUid = _chatService.currentUserId;
    final other = _members.firstWhere((m) => m != currentUid, orElse: () => '');
    if (other.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one other member is required for calls.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          receiverId: other,
          receiverName: _groupName,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onTap: _openGroupInfo,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1656),
                    shape: BoxShape.circle,
                    border: Border.all(color: _neonPurple.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.groups_rounded, color: _neonCyan, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _groupName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _whiteText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _neonGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_members.length} operatives',
                            style: const TextStyle(
                              color: _subText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
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
        ),
        actions: [
          IconButton(
            onPressed: () => _startGroupCall(false),
            icon: const Icon(Icons.call_rounded, color: _whiteText, size: 21),
            tooltip: 'Squad Call',
          ),
          IconButton(
            onPressed: () => _startGroupCall(true),
            icon: const Icon(Icons.videocam_rounded, color: _whiteText, size: 22),
            tooltip: 'Video Stream',
          ),
          IconButton(
            onPressed: _showAddMemberDialog,
            icon: const Icon(Icons.person_add_rounded, color: _whiteText, size: 22),
            tooltip: 'Add Operative',
          ),
          IconButton(
            onPressed: _openGroupInvite,
            icon: const Icon(Icons.link_rounded, color: _whiteText, size: 22),
            tooltip: 'Invite Link',
          ),
          IconButton(
            onPressed: _openGroupInfo,
            icon: const Icon(Icons.info_outline_rounded, color: _whiteText, size: 22),
            tooltip: 'Squad Info',
          ),
        ],
      ),
      body: _isLoading || _isCreating
          ? const Center(child: CircularProgressIndicator(color: _neonPurple))
          : Column(
              children: [
                Expanded(child: _buildMessagesStream()),
                if (_conversationId != null)
                  ChatInputBar(
                    conversationId: _conversationId!,
                    replyTo: _replyToMessage,
                    hintText: 'Broadcast to squad...',
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
        child: Text('Initialize syndicate to start comms.', style: TextStyle(color: _subText)),
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
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _neonPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _neonPurple.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.shield_rounded, color: _neonCyan, size: 36),
                ),
                const SizedBox(height: 14),
                Text(
                  _groupName,
                  style: const TextStyle(color: _whiteText, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No transmissions recorded yet.',
                  style: TextStyle(color: _subText, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final messageId = msg['id']?.toString() ?? 'msg_$index';
            final senderUid = msg['senderId']?.toString() ?? '';
            final isMine = senderUid == currentUid;
            final isAudioPlaying = _isPlayingAudio && _currentlyPlayingAudioUrl == msg['audioUrl'];

            // Resolved cached name or fallback
            final senderName = isMine
                ? 'You'
                : (_memberNamesCache[senderUid] ?? msg['senderName']?.toString() ?? 'Operative');
            final isAdmin = _admins.contains(senderUid);

            return MessageBubble(
              data: msg,
              isMine: isMine,
              isGroup: true,
              isAdmin: isAdmin,
              senderName: senderName,
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
