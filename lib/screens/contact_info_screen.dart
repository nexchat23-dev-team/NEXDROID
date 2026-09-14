import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/firebase_service.dart';
import '../widgets/token_purchase_sheet.dart';
import 'call_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  static const String routeName = '/contact-info';

  final String name;
  final String? participantId;
  final String? conversationId;
  final String? phoneNumber;
  final String? bio;
  final String? avatarUrl;

  const ContactInfoScreen({
    super.key,
    required this.name,
    this.participantId,
    this.conversationId,
    this.phoneNumber,
    this.bio,
    this.avatarUrl,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _resolvedUserId;
  String _displayName = '';
  String _username = '';
  String _bio = '';
  String? _avatarUrl;
  final String _userStatus = 'Online';
  String _memberSince = '2026';
  bool _isChatLocked = false;
  bool _isMuted = false;
  bool _isBlocked = false;
  List<Map<String, dynamic>> _realSharedMedia = [];

  static const Color _bgDiscord = Color(0xFF111214);
  static const Color _cardDiscord = Color(0xFF1E1F22);
  static const Color _cardElevated = Color(0xFF2B2D31);
  static const Color _accentCyber = Color(0xFF5865F2);
  static const Color _neonGreen = Color(0xFF23A55A);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _goldToken = Color(0xFFFFB800);
  static const Color _subText = Color(0xFF949BA4);

  @override
  void initState() {
    super.initState();
    _displayName = widget.name;
    _bio = widget.bio ?? '';
    _avatarUrl = widget.avatarUrl;
    _resolveAndLoadProfile();
  }

  Future<void> _resolveAndLoadProfile() async {
    String? targetUid = widget.participantId;

    if (targetUid == null && widget.conversationId != null) {
      final currentUid = _chatService.currentUserId;
      if (widget.conversationId!.startsWith('direct_')) {
        final parts = widget.conversationId!.replaceFirst('direct_', '').split('_');
        for (final p in parts) {
          if (p.isNotEmpty && p != currentUid) {
            targetUid = p;
            break;
          }
        }
      }
    }

    _resolvedUserId = targetUid;

    if (targetUid != null && targetUid.isNotEmpty) {
      try {
        final profile = await FirebaseService.getUserProfile(targetUid);
        if (profile != null && mounted) {
          setState(() {
            _displayName = profile['name']?.toString() ?? profile['username']?.toString() ?? widget.name;
            _username = profile['username']?.toString() ?? '';
            if (profile['bio'] != null && profile['bio'].toString().trim().isNotEmpty) {
              _bio = profile['bio'].toString();
            }
            if (profile['photo_url'] != null) {
              _avatarUrl = profile['photo_url'].toString();
            }
            if (profile['createdAt'] != null) {
              try {
                final dt = DateTime.parse(profile['createdAt'].toString());
                _memberSince = '${_getMonthName(dt.month)} ${dt.year}';
              } catch (_) {}
            }
          });
        }

        final isBlocked = await _chatService.isUserBlocked(targetUid);
        if (mounted) setState(() => _isBlocked = isBlocked);
      } catch (e) {
        debugPrint('Error loading contact profile: $e');
      }
    }

    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      try {
        final msgs = await _firestore
            .collection('messages')
            .where('conversationId', isEqualTo: widget.conversationId)
            .limit(20)
            .get();

        final mediaList = <Map<String, dynamic>>[];
        for (final doc in msgs.docs) {
          final data = doc.data();
          final type = data['type']?.toString() ?? 'text';
          if (type == 'image' || type == 'audio' || type == 'doc' || type == 'video' || data['audioUrl'] != null) {
            mediaList.add({
              'id': doc.id,
              'type': type,
              'url': data['audioUrl'] ?? data['mediaUrl'] ?? data['fileUrl'] ?? '',
              'text': data['text'] ?? 'File',
              'timestamp': data['createdAt'] ?? data['timestamp'],
            });
          }
        }
        if (mounted) setState(() => _realSharedMedia = mediaList);
      } catch (e) {
        debugPrint('Error loading real media: $e');
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  void _triggerCall(bool isVideo) {
    HapticFeedback.lightImpact();
    final uid = _resolvedUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot initiate call: User ID unavailable.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          receiverId: _resolvedUserId ?? 'target_${_displayName.hashCode}',
          receiverName: _displayName,
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _showTokenTransferModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _cardDiscord,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.monetization_on_rounded, color: _goldToken, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Send Tokens to $_displayName',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Transfer NEX Tokens directly to this user instantly via secure decentralized ledger.',
              style: TextStyle(color: _subText, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const TokenPurchaseSheet(),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Transfer 100 NEX Tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _goldToken,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUsername = _username.isNotEmpty ? '@$_username' : '@${_displayName.toLowerCase().replaceAll(' ', '_')}';

    return Scaffold(
      backgroundColor: _bgDiscord,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
              color: _cardDiscord,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'block') {
                  setState(() => _isBlocked = !_isBlocked);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isBlocked ? '$_displayName blocked' : '$_displayName unblocked')),
                  );
                } else if (val == 'mute') {
                  setState(() => _isMuted = !_isMuted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isMuted ? 'Notifications muted' : 'Notifications unmuted')),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(_isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 10),
                      Text(_isMuted ? 'Unmute' : 'Mute', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(_isBlocked ? 'Unblock' : 'Block User', style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5865F2), Color(0xFF00E5FF), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -46,
                  left: 20,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _bgDiscord,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF2B2D31),
                          backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                          child: _avatarUrl == null || _avatarUrl!.isEmpty
                              ? Text(
                                  _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _neonGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bgDiscord, width: 3.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 54),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                effectiveUsername,
                                style: const TextStyle(color: _subText, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _neonGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _neonGreen.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: _neonGreen, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _userStatus,
                                style: const TextStyle(color: _neonGreen, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadgeChip(Icons.flash_on_rounded, 'NEX Core', _neonCyan),
                        _buildBadgeChip(Icons.military_tech_rounded, 'Veteran', _goldToken),
                        _buildBadgeChip(Icons.shield_rounded, 'Encrypted', const Color(0xFF8B5CF6)),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDiscordActionButton(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Message',
                          color: _accentCyber,
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildDiscordActionButton(
                          icon: Icons.call_rounded,
                          label: 'Voice',
                          color: _neonGreen,
                          onTap: () => _triggerCall(false),
                        ),
                        _buildDiscordActionButton(
                          icon: Icons.videocam_rounded,
                          label: 'Video',
                          color: _neonCyan,
                          onTap: () => _triggerCall(true),
                        ),
                        _buildDiscordActionButton(
                          icon: Icons.monetization_on_rounded,
                          label: 'Tokens',
                          color: _goldToken,
                          onTap: _showTokenTransferModal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                      'ABOUT ME',
                      style: TextStyle(color: _subText, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _bio.isNotEmpty ? _bio : 'No bio written yet.',
                      style: TextStyle(
                        color: _bio.isNotEmpty ? Colors.white : Colors.white54,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: _subText),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEX MEMBER SINCE', style: TextStyle(color: _subText, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(_memberSince, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                        const Text(
                          'SHARED FILES & MEDIA',
                          style: TextStyle(color: _subText, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                        if (_realSharedMedia.isNotEmpty)
                          Text('${_realSharedMedia.length} items', style: const TextStyle(color: _subText, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_realSharedMedia.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.folder_open_rounded, size: 36, color: _subText.withValues(alpha: 0.6)),
                            const SizedBox(height: 8),
                            const Text(
                              'No shared media in this conversation yet.',
                              style: TextStyle(color: _subText, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _realSharedMedia.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, idx) {
                            final item = _realSharedMedia[idx];
                            final type = item['type'] ?? 'file';
                            final isAudio = type == 'audio';
                            final isImg = type == 'image';

                            return Container(
                              width: 86,
                              decoration: BoxDecoration(
                                color: _cardElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isImg ? Icons.image_rounded : (isAudio ? Icons.graphic_eq_rounded : Icons.insert_drive_file_rounded),
                                    color: isImg ? _neonCyan : (isAudio ? _neonGreen : _accentCyber),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      item['text']?.toString() ?? 'File',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardDiscord,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: _accentCyber,
                      title: const Text('Lock with Biometrics', style: TextStyle(color: Colors.white, fontSize: 15)),
                      subtitle: const Text('Require fingerprint to view chat', style: TextStyle(color: _subText, fontSize: 12.5)),
                      value: _isChatLocked,
                      onChanged: (val) {
                        setState(() => _isChatLocked = val);
                        if (widget.conversationId != null) {
                          _chatService.setChatLock(widget.conversationId!, val);
                        }
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: _neonCyan, size: 22),
                      title: const Text('End-to-End Encryption', style: TextStyle(color: Colors.white, fontSize: 15)),
                      subtitle: const Text('Signals & messages are quantum verified', style: TextStyle(color: _subText, fontSize: 12.5)),
                      trailing: const Icon(Icons.verified_rounded, color: _neonGreen, size: 20),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Encryption keys verified for this contact.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscordActionButton({
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
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
