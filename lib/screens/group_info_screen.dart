import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/firebase_service.dart';
import 'call_screen.dart';
import 'contact_info_screen.dart';
import 'group_invite_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  static const String routeName = '/group-info';

  final String conversationId;
  final String groupName;
  final List<String> members;
  final List<String> admins;

  const GroupInfoScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
    this.members = const [],
    this.admins = const [],
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _participantList = [];
  List<Map<String, dynamic>> _realGroupMedia = [];
  bool _isNotificationsMuted = false;
  bool _isChatLocked = false;
  String _inviteLink = '';

  // Discord / NEX Cyber Color Palette
  static const Color _bgDiscord = Color(0xFF111214);
  static const Color _cardDiscord = Color(0xFF1E1F22);
  static const Color _cardElevated = Color(0xFF2B2D31);
  static const Color _accentCyber = Color(0xFF5865F2); // Discord Blurple
  static const Color _neonGreen = Color(0xFF23A55A);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _goldToken = Color(0xFFFFB800);
  static const Color _subText = Color(0xFF949BA4);
  static const Color _whiteText = Color(0xFFF2F3F5);

  @override
  void initState() {
    super.initState();
    _inviteLink = 'https://nexapp.io/join/${widget.conversationId}';
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final currentUid = _chatService.currentUserId ?? '';
    final membersData = <Map<String, dynamic>>[];

    // Add current user
    membersData.add({
      'id': currentUid,
      'name': 'You',
      'username': 'me',
      'role': widget.admins.contains(currentUid) ? 'Founder' : 'Member',
      'isAdmin': widget.admins.contains(currentUid),
      'avatarUrl': null,
    });

    // Load other members with real names
    for (final memberId in widget.members) {
      if (memberId == currentUid) continue;
      try {
        final profile = await FirebaseService.getUserProfile(memberId);
        final isAdmin = widget.admins.contains(memberId);
        membersData.add({
          'id': memberId,
          'name': profile?['name']?.toString() ?? profile?['username']?.toString() ?? 'Agent ${memberId.substring(0, 4.clamp(0, memberId.length))}',
          'username': profile?['username']?.toString() ?? '',
          'role': isAdmin ? 'Officer' : 'Member',
          'isAdmin': isAdmin,
          'avatarUrl': profile?['photo_url']?.toString(),
        });
      } catch (_) {
        membersData.add({
          'id': memberId,
          'name': 'Agent ${memberId.substring(0, 4.clamp(0, memberId.length))}',
          'username': '',
          'role': widget.admins.contains(memberId) ? 'Officer' : 'Member',
          'isAdmin': widget.admins.contains(memberId),
          'avatarUrl': null,
        });
      }
    }

    if (mounted) setState(() => _participantList = membersData);

    // Fetch real shared media
    try {
      final msgs = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: widget.conversationId)
          .limit(20)
          .get();

      final media = <Map<String, dynamic>>[];
      for (final doc in msgs.docs) {
        final d = doc.data();
        final type = d['type']?.toString() ?? 'text';
        if (type == 'image' || type == 'audio' || type == 'doc' || type == 'video') {
          media.add({
            'type': type,
            'text': d['text'] ?? 'File',
            'url': d['mediaUrl'] ?? d['audioUrl'] ?? '',
          });
        }
      }
      if (mounted) setState(() => _realGroupMedia = media);
    } catch (_) {}
  }

  void _startGroupVoice() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          receiverId: 'group_${widget.conversationId}',
          receiverName: widget.groupName,
          isVideo: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.groupName.isNotEmpty ? widget.groupName : 'NEX Clan';

    return Scaffold(
      backgroundColor: _bgDiscord,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _inviteLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clan invite link copied to clipboard!')),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── 1. Discord Server Banner & Clan Emblem ─────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF5865F2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: _bgDiscord, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: _accentCyber,
                      child: Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '#',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // ── 2. Clan Details & Quick Action Bar ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardDiscord,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_participantList.length} Members • Public Clan Server',
                                style: const TextStyle(color: _subText, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _neonCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                          ),
                          child: const Text('CLAN', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildClanActionButton(Icons.graphic_eq_rounded, 'Voice Hub', _neonGreen, _startGroupVoice),
                        _buildClanActionButton(Icons.person_add_rounded, 'Invite', _accentCyber, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupInviteScreen(
                                conversationId: widget.conversationId,
                                groupName: widget.groupName,
                              ),
                            ),
                          );
                        }),
                        _buildClanActionButton(Icons.search_rounded, 'Search', _neonCyan, () => Navigator.pop(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── 3. Clan Members Roster (Discord Roles) ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardDiscord,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMBERS ROSTER (${_participantList.length})',
                      style: const TextStyle(color: _subText, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 12),
                    ..._participantList.map((member) {
                      final isAdm = member['isAdmin'] == true;
                      final name = member['name'] as String;
                      final id = member['id'] as String;
                      final avatar = member['avatarUrl'] as String?;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: _cardElevated,
                          backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(name, style: const TextStyle(color: _whiteText, fontSize: 14.5, fontWeight: FontWeight.w600)),
                            if (isAdm) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(color: _goldToken.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                child: const Text('ADMIN', style: TextStyle(color: _goldToken, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: _subText, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactInfoScreen(name: name, bio: member['role']),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── 4. Shared Clan Media ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardDiscord,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLAN MEDIA & ATTACHMENTS',
                      style: TextStyle(color: _subText, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 12),
                    if (_realGroupMedia.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        child: const Text('No shared media in this clan yet.', style: TextStyle(color: _subText, fontSize: 13)),
                      )
                    else
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _realGroupMedia.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, idx) => Container(
                            width: 80,
                            decoration: BoxDecoration(color: _cardElevated, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.insert_drive_file_rounded, color: _accentCyber, size: 28),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── 5. Leave Group Action ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: _cardDiscord, borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  title: const Text('Leave Clan', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left clan.')));
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildClanActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

