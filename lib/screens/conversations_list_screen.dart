import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/animation_provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'group_info_screen.dart';
import 'contact_info_screen.dart';
import 'my_statuses_screen.dart';
import 'user_search_screen.dart';
import 'ai_chat_screen.dart';
import 'call_screen.dart';
import 'animation_store_screen.dart';
import 'settings_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  static const routeName = '/conversations';
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  late TabController _tabController;
  int _currentNavIndex = 0;
  String _activeFilter = 'All'; // 'All', 'Direct', 'Groups', 'Unread', 'Favourites'

  // Live interactive search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchActive = false;

  // Static in-memory profile and presence cache for 60-120fps smooth scrolling
  static final Map<String, Map<String, dynamic>> _participantCache = {};
  static final Set<String> _pendingUids = {};

  // Discord / NEX Cyber Neon Purple & WhatsApp Palette
  static const Color _bgDark = Color(0xFF0C071E); // Deep cyber-purple void
  static const Color _appBarDark = Color(0xFF140B28); // Header dark purple
  static const Color _searchPill = Color(0xFF1D0E38); // Search bar background
  static const Color _chipActiveBg = Color(0xFF2E1656); // Active filter background
  static const Color _chipActiveBorder = Color(0xFFB44FFF); // Neon purple border
  static const Color _chipInactiveBg = Color(0xFF170C2E); // Inactive filter pill
  static const Color _accentPurple = Color(0xFFB44FFF); // Vibrant Neon Purple
  static const Color _accentCyan = Color(0xFF00E5FF); // Neon Cyan
  static const Color _neonGreen = Color(0xFF00FF88); // Online Green
  static const Color _goldBadge = Color(0xFFFFB800); // Pinned/Starred Gold
  static const Color _subTextGrey = Color(0xFF9E8DBE); // Subtext violet-grey
  static const Color _whiteText = Color(0xFFF5EFFF); // Pure white-violet
  static const Color _metaBlueTicks = Color(0xFF00E5FF); // Read checkmarks

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _currentNavIndex = _tabController.index);
      }
    });

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text != _searchQuery && mounted) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> get _conversationsStream {
    return _chatService.getConversations();
  }

  // Fast synchronous cached participant info lookup with background batch prefetch
  Map<String, dynamic> _getCachedParticipantInfo(String otherUserId, {String? fallbackName}) {
    if (otherUserId.isEmpty) {
      return {'name': fallbackName ?? 'Operative', 'photo_url': '', 'isOnline': false};
    }

    if (_participantCache.containsKey(otherUserId)) {
      return _participantCache[otherUserId]!;
    }

    // Prefetch in background if not already requested
    if (!_pendingUids.contains(otherUserId)) {
      _pendingUids.add(otherUserId);
      _fetchAndCacheProfile(otherUserId);
    }

    return {
      'name': fallbackName?.isNotEmpty == true ? fallbackName! : 'Operative',
      'photo_url': '',
      'isOnline': false,
      'id': otherUserId,
    };
  }

  Future<void> _fetchAndCacheProfile(String uid) async {
    try {
      final profile = await FirebaseService.getUserProfile(uid);
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

        _participantCache[uid] = {
          'name': resolved.isNotEmpty ? resolved : 'Operative',
          'photo_url': photoUrl,
          'isOnline': isOnline,
          'email': profile['email']?.toString() ?? '',
          'id': uid,
        };

        if (mounted) setState(() {});
      }
    } catch (_) {} finally {
      _pendingUids.remove(uid);
    }
  }

  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return '';
    DateTime dateTime;
    if (createdAt is Timestamp) {
      dateTime = createdAt.toDate();
    } else if (createdAt is DateTime) {
      dateTime = createdAt;
    } else if (createdAt is String) {
      try {
        dateTime = DateTime.parse(createdAt).toLocal();
      } catch (_) {
        return createdAt;
      }
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && dateTime.day == now.day) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays <= 1 && (now.day - dateTime.day == 1 || difference.inDays == 1)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year.toString().substring(2)}';
    }
  }

  void _openConversation(String conversationId, String participantName, String participantId) {
    _chatService.markConversationAsRead(conversationId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          participantName: participantName,
          participantId: participantId,
        ),
      ),
    );
  }

  void _openGroupChat(String conversationId, String groupName) {
    _chatService.markConversationAsRead(conversationId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(conversationId: conversationId),
      ),
    );
  }

  void _showNewGroupModal() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF160B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _accentPurple.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.groups_rounded, color: _accentCyan, size: 26),
            SizedBox(width: 10),
            Text('Create New Syndicate', style: TextStyle(color: _whiteText, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a name for your squad or tactical group channel:',
              style: TextStyle(color: _subTextGrey, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: _whiteText),
              decoration: InputDecoration(
                hintText: 'e.g. Cyber Squad Alpha',
                hintStyle: TextStyle(color: _subTextGrey.withValues(alpha: 0.6)),
                filled: true,
                fillColor: _searchPill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _accentPurple, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: _subTextGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                final currentUid = _chatService.currentUserId;
                if (currentUid != null) {
                  final convId = await _chatService.createConversation(
                    participantIds: [currentUid],
                    groupName: name,
                    isGroup: true,
                  );
                  if (mounted) {
                    _openGroupChat(convId, name);
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChatActionBottomSheet(Map<String, dynamic> conversation) {
    HapticFeedback.mediumImpact();
    final conversationId = conversation['id']?.toString() ?? '';
    final isGroup = conversation['isGroup'] as bool? ?? false;
    final groupName = conversation['groupName'] as String? ?? 'Group';
    final isPinned = conversation['pinned'] == true;
    final isArchived = conversation['archived'] == true;
    final isMuted = conversation['muted'] == true;
    final unreadCount = conversation['unreadCount'] as int? ?? 0;
    final isFavourite = conversation['favourite'] == true;

    final participants = conversation['participants'] as List? ?? [];
    final currentUid = _chatService.currentUserId ?? '';
    final otherUserId = participants.firstWhere((id) => id != currentUid, orElse: () => '');
    final participantInfo = _getCachedParticipantInfo(otherUserId);
    final chatTitle = isGroup ? groupName : participantInfo['name'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140B28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isGroup ? const Color(0xFF381564) : const Color(0xFF1B0F33),
                    child: Icon(isGroup ? Icons.groups_rounded : Icons.person_rounded, color: _accentCyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chatTitle,
                          style: const TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isGroup ? 'Clan Syndicate' : 'Direct Comms',
                          style: const TextStyle(color: _subTextGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              // Pin / Unpin
              _buildModalTile(
                icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                iconColor: _goldBadge,
                label: isPinned ? 'Unpin from Top' : 'Pin to Top',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (isPinned) {
                    await _chatService.unpinConversation(conversationId);
                  } else {
                    await _chatService.pinConversation(conversationId);
                  }
                },
              ),
              // Mute / Unmute
              _buildModalTile(
                icon: isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                iconColor: _accentPurple,
                label: isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (isMuted) {
                    await _chatService.unmuteConversation(conversationId);
                  } else {
                    _showMuteDurationPicker(conversationId);
                  }
                },
              ),
              // Mark as Read / Unread
              _buildModalTile(
                icon: unreadCount > 0 ? Icons.mark_chat_read_rounded : Icons.mark_chat_unread_rounded,
                iconColor: _neonGreen,
                label: unreadCount > 0 ? 'Mark as Read' : 'Mark as Unread',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (unreadCount > 0) {
                    await _chatService.markConversationAsRead(conversationId);
                  } else {
                    await _chatService.markConversationAsUnread(conversationId);
                  }
                },
              ),
              // Archive / Unarchive
              _buildModalTile(
                icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                iconColor: _accentCyan,
                label: isArchived ? 'Unarchive Chat' : 'Archive Chat',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (isArchived) {
                    await _chatService.unarchiveConversation(conversationId);
                  } else {
                    await _chatService.archiveConversation(conversationId);
                  }
                },
              ),
              // Toggle Favourite
              _buildModalTile(
                icon: isFavourite ? Icons.star_border_rounded : Icons.star_rounded,
                iconColor: Colors.amberAccent,
                label: isFavourite ? 'Remove from Favourites' : 'Add to Favourites',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _chatService.toggleFavourite(conversationId, !isFavourite);
                },
              ),
              // View Info
              _buildModalTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.white70,
                label: isGroup ? 'Group Information' : 'Contact Profile',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (isGroup) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupInfoScreen(
                          conversationId: conversationId,
                          groupName: groupName,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactInfoScreen(
                          name: participantInfo['name'] as String,
                          participantId: otherUserId,
                          conversationId: conversationId,
                          avatarUrl: participantInfo['photo_url'] as String?,
                        ),
                      ),
                    );
                  }
                },
              ),
              // Delete / Leave
              _buildModalTile(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.redAccent,
                label: isGroup ? 'Exit & Delete Group' : 'Delete Conversation',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmDeleteConversation(conversationId, isGroup);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMuteDurationPicker(String conversationId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140B28),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mute Notifications For', style: TextStyle(color: _whiteText, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.timer_outlined, color: _accentCyan),
              title: const Text('8 Hours', style: TextStyle(color: _whiteText)),
              onTap: () {
                Navigator.pop(ctx);
                _chatService.muteChatForDuration(conversationId, const Duration(hours: 8));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_rounded, color: _accentPurple),
              title: const Text('1 Week', style: TextStyle(color: _whiteText)),
              onTap: () {
                Navigator.pop(ctx);
                _chatService.muteChatForDuration(conversationId, const Duration(days: 7));
              },
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive_rounded, color: _goldBadge),
              title: const Text('Always', style: TextStyle(color: _whiteText)),
              onTap: () {
                Navigator.pop(ctx);
                _chatService.muteConversation(conversationId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteConversation(String conversationId, bool isGroup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF180D30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isGroup ? 'Exit Group?' : 'Delete Chat?', style: const TextStyle(color: _whiteText, fontWeight: FontWeight.bold)),
        content: Text(
          isGroup
              ? 'Are you sure you want to exit and remove this group from your list?'
              : 'This will remove the conversation from your active messages.',
          style: const TextStyle(color: _subTextGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _subTextGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.deleteConversation(conversationId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : _whiteText,
          fontSize: 14.5,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  void _showWallpaperPickerSheet(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final animProvider = Provider.of<AnimationProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140B28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            const SizedBox(height: 16),
            const Text(
              'CHAT LIST WALLPAPER',
              style: TextStyle(color: _accentCyan, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose your preferred background style for this chat list:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _wallpaperChip(ctx, 'Cyber Void', 'cyber_void', const Color(0xFFB44FFF), themeProvider, animProvider),
                _wallpaperChip(ctx, 'AMOLED Black', 'amoled_black', const Color(0xFF00E5FF), themeProvider, animProvider),
                _wallpaperChip(ctx, 'Midnight Slate', 'midnight_slate', const Color(0xFF38BDF8), themeProvider, animProvider),
                _wallpaperChip(ctx, 'Matrix Glyphs', 'matrix_glyph', const Color(0xFF00FF41), themeProvider, animProvider),
                _wallpaperChip(ctx, 'Neon Grid', 'neon_cyber_grid', const Color(0xFFFF2A85), themeProvider, animProvider),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AnimationStoreScreen.routeName);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFB44FFF), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('EQUIP PURCHASED LIVE ANIMATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wallpaperChip(
    BuildContext ctx,
    String label,
    String key,
    Color color,
    ThemeProvider tp,
    AnimationProvider ap,
  ) {
    final isSelected = tp.chatListWallpaper == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: const Color(0xFF1F1238),
      side: BorderSide(color: isSelected ? color : Colors.white24),
      onSelected: (_) {
        tp.setChatListWallpaper(key);
        ap.setChatListBackground(null);
        Navigator.pop(ctx);
      },
    );
  }

  Color _getChatListBgColor(String wallpaperKey) {
    switch (wallpaperKey) {
      case 'amoled_black':
        return Colors.black;
      case 'midnight_slate':
        return const Color(0xFF0B1120);
      case 'matrix_glyph':
        return const Color(0xFF030D06);
      case 'neon_cyber_grid':
        return const Color(0xFF130724);
      case 'cyber_void':
      default:
        return _bgDark;
    }
  }

  List<Map<String, dynamic>> _sortConversations(List<Map<String, dynamic>> conversations) {
    final list = List<Map<String, dynamic>>.from(conversations);
    list.sort((a, b) {
      // 1. Pinned conversations always stay at top
      final aPinned = a['pinned'] == true;
      final bPinned = b['pinned'] == true;
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // 2. Sort by latest message time
      final aTime = a['lastMessageTime'] ?? a['createdAt'];
      final bTime = b['lastMessageTime'] ?? b['createdAt'];

      DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);

      if (aTime is Timestamp) {
        aDate = aTime.toDate();
      } else if (aTime is DateTime) {
        aDate = aTime;
      } else if (aTime is String) {
        aDate = DateTime.tryParse(aTime) ?? aDate;
      }

      if (bTime is Timestamp) {
        bDate = bTime.toDate();
      } else if (bTime is DateTime) {
        bDate = bTime;
      } else if (bTime is String) {
        bDate = DateTime.tryParse(bTime) ?? bDate;
      }

      return bDate.compareTo(aDate);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bgColor = _getChatListBgColor(themeProvider.chatListWallpaper);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: _appBarDark,
        title: Text(
          _currentNavIndex == 0
              ? 'NEX Chat'
              : (_currentNavIndex == 1
                  ? 'Updates'
                  : (_currentNavIndex == 2 ? 'Clans & Groups' : 'Calls')),
          style: const TextStyle(
            color: _whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 23,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          if (_currentNavIndex == 0 || _currentNavIndex == 1)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, color: _whiteText, size: 23),
              tooltip: 'Camera / Status',
              onPressed: () => Navigator.pushNamed(context, MyStatusesScreen.routeName),
            ),
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close_rounded : Icons.search_rounded, color: _whiteText, size: 23),
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.wallpaper_rounded, color: _accentCyan, size: 22),
            tooltip: 'Chat Wallpaper',
            onPressed: () => _showWallpaperPickerSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _whiteText, size: 23),
            color: const Color(0xFF1B0E36),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'new_group', child: Row(children: [Icon(Icons.groups_rounded, color: _accentCyan, size: 18), SizedBox(width: 10), Text('New group', style: TextStyle(color: _whiteText))])),
              const PopupMenuItem(value: 'new_chat', child: Row(children: [Icon(Icons.person_add_rounded, color: _accentPurple, size: 18), SizedBox(width: 10), Text('New chat', style: TextStyle(color: _whiteText))])),
              const PopupMenuItem(value: 'starred', child: Row(children: [Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18), SizedBox(width: 10), Text('Starred messages', style: TextStyle(color: _whiteText))])),
              const PopupMenuItem(value: 'wallpaper', child: Row(children: [Icon(Icons.palette_rounded, color: _accentCyan, size: 18), SizedBox(width: 10), Text('Chat wallpaper', style: TextStyle(color: _whiteText))])),
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_rounded, color: _whiteText, size: 18), SizedBox(width: 10), Text('Settings', style: TextStyle(color: _whiteText))])),
            ],
            onSelected: (value) {
              if (value == 'new_group') {
                _showNewGroupModal();
              } else if (value == 'new_chat') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen()));
              } else if (value == 'starred') {
                setState(() => _activeFilter = 'Favourites');
              } else if (value == 'wallpaper') {
                _showWallpaperPickerSheet(context);
              } else if (value == 'settings') {
                Navigator.pushNamed(context, SettingsScreen.routeName);
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsSubSection(),
          _buildUpdatesSubSection(),
          _buildCommunitiesSubSection(),
          _buildCallsSubSection(),
        ],
      ),
      floatingActionButton: _buildWhatsAppFAB(),
      bottomNavigationBar: _buildWhatsAppBottomBar(),
    );
  }

  // ── 1. MAIN CHATS SUBSECTION (WHATSAPP GRADE) ──────────────────────────────
  Widget _buildChatsSubSection() {
    return Column(
      children: [
        // Interactive live search bar
        if (_isSearchActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: _searchPill,
                border: Border.all(color: _accentPurple.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _accentPurple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: _whiteText, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search chats, groups, messages...',
                        hintStyle: TextStyle(color: _subTextGrey.withValues(alpha: 0.8), fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(Icons.close_rounded, color: _subTextGrey, size: 18),
                    ),
                ],
              ),
            ),
          ),

        // WhatsApp Filter Chips: All, Direct, Groups, Unread, Favourites
        _buildWhatsAppFilterChips(),

        // Conversations List with Synchronous Cached Rendering
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _conversationsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: _accentPurple));
              }

              final rawConversations = snapshot.data ?? [];
              final sortedConversations = _sortConversations(rawConversations);

              // Apply active filter and search filter
              final filtered = sortedConversations.where((c) {
                final isGroup = c['isGroup'] as bool? ?? false;
                final unread = c['unreadCount'] as int? ?? 0;
                final isFav = c['favourite'] == true;
                final isArchived = c['archived'] == true;

                // Do not show archived chats in regular view unless searching
                if (isArchived && _activeFilter != 'Archived' && _searchQuery.isEmpty) {
                  return false;
                }

                // Filter chips logic
                if (_activeFilter == 'Direct' && isGroup) return false;
                if (_activeFilter == 'Groups' && !isGroup) return false;
                if (_activeFilter == 'Unread' && unread <= 0) return false;
                if (_activeFilter == 'Favourites' && !isFav) return false;

                // Search query matching
                if (_searchQuery.isNotEmpty) {
                  final groupName = (c['groupName'] as String? ?? '').toLowerCase();
                  final lastMessage = (c['lastMessage'] as String? ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();

                  if (groupName.contains(query) || lastMessage.contains(query)) {
                    return true;
                  }

                  final participants = c['participants'] as List? ?? [];
                  final currentUid = _chatService.currentUserId ?? '';
                  final otherUserId = participants.firstWhere((id) => id != currentUid, orElse: () => '');
                  final pInfo = _getCachedParticipantInfo(otherUserId);
                  final pName = (pInfo['name'] as String? ?? '').toLowerCase();
                  if (pName.contains(query)) return true;

                  return false;
                }

                return true;
              }).toList();

              final archivedCount = rawConversations.where((c) => c['archived'] == true).length;

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _activeFilter == 'Groups' ? Icons.groups_rounded : Icons.chat_bubble_outline_rounded,
                        size: 56,
                        color: _subTextGrey.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No chats matching "$_searchQuery"'
                            : (_activeFilter == 'Groups'
                                ? 'No group syndicate chats'
                                : (_activeFilter == 'Unread'
                                    ? 'No unread messages'
                                    : (_activeFilter == 'Favourites'
                                        ? 'No favourite chats'
                                        : 'No conversations yet'))),
                        style: const TextStyle(color: _whiteText, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeFilter == 'Groups'
                            ? 'Tap the + button to create a new squad'
                            : 'Tap the chat button below to start a message',
                        style: const TextStyle(color: _subTextGrey, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length + (archivedCount > 0 && _activeFilter != 'Archived' ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show Archived banner as first item if there are archived chats
                  if (archivedCount > 0 && _activeFilter != 'Archived' && index == 0) {
                    return _buildArchivedBanner(archivedCount);
                  }

                  final itemIndex = (archivedCount > 0 && _activeFilter != 'Archived') ? index - 1 : index;
                  final conversation = filtered[itemIndex];
                  return _buildWhatsAppChatRow(conversation);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 2. WHATSAPP FILTER CHIPS ───────────────────────────────────────────────
  Widget _buildWhatsAppFilterChips() {
    final filters = ['All', 'Direct', 'Groups', 'Unread', 'Favourites'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ...filters.map((filter) {
              final isSelected = _activeFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeFilter = filter);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? _chipActiveBg : _chipInactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _chipActiveBorder : Colors.white.withValues(alpha: 0.06),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _chipActiveBorder.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? _whiteText : _subTextGrey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: _showNewGroupModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _chipInactiveBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentPurple.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.group_add_rounded, color: _accentCyan, size: 16),
                    SizedBox(width: 6),
                    Text('New Group', style: TextStyle(color: _whiteText, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. ARCHIVED CHATS BANNER ───────────────────────────────────────────────
  Widget _buildArchivedBanner(int count) {
    return InkWell(
      onTap: () => setState(() => _activeFilter = 'Archived'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _searchPill.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_rounded, color: _accentCyan, size: 20),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Archived',
                style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Text(
              count.toString(),
              style: const TextStyle(color: _accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. WHATSAPP CHAT ROW TILE (SYNCHRONOUS O(1) RENDERING) ─────────────────
  Widget _buildWhatsAppChatRow(Map<String, dynamic> conversation) {
    final conversationId = conversation['id']?.toString() ?? '';
    final participants = conversation['participants'] as List? ?? [];
    final isGroup = conversation['isGroup'] as bool? ?? false;
    final groupName = conversation['groupName'] as String?;
    final lastMessageText = conversation['lastMessage'] as String?;
    final lastMessageTime = conversation['lastMessageTime'] ?? conversation['createdAt'];
    final unreadCount = conversation['unreadCount'] as int? ?? 0;
    final isPinned = conversation['pinned'] == true;
    final isMuted = conversation['muted'] == true;
    final isFavourite = conversation['favourite'] == true;
    final lastSender = conversation['lastSenderName'] as String?;

    final currentUserId = _chatService.currentUserId ?? '';
    final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');

    // Synchronous cached profile lookup
    final directCachedName = (conversation['participantNames'] is Map)
        ? conversation['participantNames'][otherUserId]?.toString()
        : (conversation['participantName']?.toString());
    final participantInfo = _getCachedParticipantInfo(otherUserId, fallbackName: directCachedName);

    final participantName = isGroup
        ? (groupName ?? 'Clan Syndicate')
        : (participantInfo['name'] as String? ?? (directCachedName?.isNotEmpty == true ? directCachedName! : 'Operative'));
    final participantId = participantInfo['id'] as String? ?? otherUserId;
    final photoUrl = participantInfo['photo_url'] as String?;
    final isOnline = participantInfo['isOnline'] == true;

    final timestamp = _formatTimestamp(lastMessageTime);

    // WhatsApp style preview text: for group -> "Sender: text", for direct -> "text"
    String previewText = 'Tap to start conversation';
    if (lastMessageText != null && lastMessageText.isNotEmpty) {
      if (isGroup && lastSender != null && lastSender.isNotEmpty) {
        previewText = '$lastSender: $lastMessageText';
      } else {
        previewText = lastMessageText;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isGroup) {
            _openGroupChat(conversationId, participantName);
          } else {
            _openConversation(conversationId, participantName, participantId);
          }
        },
        onLongPress: () => _showChatActionBottomSheet(conversation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 0.8)),
          ),
          child: Row(
            children: [
              // Avatar Stack with Online Presence or Group Emblem
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isGroup ? _accentPurple.withValues(alpha: 0.8) : (isOnline ? _neonGreen : Colors.white12),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isGroup ? _accentPurple : (isOnline ? _neonGreen : Colors.transparent)).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: isGroup ? const Color(0xFF261247) : const Color(0xFF1B0F33),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? (isGroup
                              ? const Icon(Icons.groups_rounded, color: _whiteText, size: 26)
                              : Text(
                                  participantName.isNotEmpty ? participantName[0].toUpperCase() : 'O',
                                  style: const TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 18),
                                ))
                          : null,
                    ),
                  ),
                  // Online indicator dot for direct chats
                  if (!isGroup && isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _neonGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: _bgDark, width: 2.5),
                        ),
                      ),
                    ),
                  // Group member count badge for group chats
                  if (isGroup)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentPurple,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _bgDark, width: 1.5),
                        ),
                        child: Text(
                          '${participants.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, Delivery checkmarks, and Timestamps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Chat Name + Icons (Pin/Mute) + Timestamp
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  participantName,
                                  style: const TextStyle(
                                    color: _whiteText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isGroup) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _accentPurple.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('GROUP', style: TextStyle(color: _accentPurple, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                              if (isFavourite) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 14),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isPinned)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin_rounded, color: _goldBadge, size: 14),
                          ),
                        if (isMuted)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.volume_off_rounded, color: _subTextGrey, size: 14),
                          ),
                        Text(
                          timestamp,
                          style: TextStyle(
                            color: unreadCount > 0 ? _accentCyan : _subTextGrey,
                            fontSize: 12,
                            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Bottom Row: Status Checkmark + Preview + Unread Count Badge
                    Row(
                      children: [
                        if (!isGroup)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Icon(
                              Icons.done_all_rounded,
                              size: 15,
                              color: _metaBlueTicks,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            previewText,
                            style: TextStyle(
                              color: unreadCount > 0 ? _whiteText : _subTextGrey,
                              fontSize: 13.5,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: _accentPurple,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: _accentPurple.withValues(alpha: 0.5), blurRadius: 6),
                              ],
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
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
    );
  }

  // ── 5. UPDATES / STATUSES SUBSECTION ───────────────────────────────────────
  Widget _buildUpdatesSubSection() {
    final currentUid = _chatService.currentUserId ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Updates', style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 14),

          SizedBox(
            height: 150,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('statuses').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                final statusDocs = snapshot.data?.docs ?? [];
                final recentStatuses = statusDocs.where((d) => d['userId'] != currentUid).toList();

                return ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // My Status Add Tile
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, MyStatusesScreen.routeName),
                      child: Container(
                        width: 114,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: _searchPill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [const Color(0xFF5865F2).withValues(alpha: 0.25), _searchPill],
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _accentPurple, width: 2.2),
                                    boxShadow: [
                                      BoxShadow(color: _accentPurple.withValues(alpha: 0.4), blurRadius: 8),
                                    ],
                                  ),
                                  child: const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Color(0xFF1E1038),
                                    child: Icon(Icons.person_rounded, color: _whiteText, size: 22),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: _accentPurple, shape: BoxShape.circle),
                                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'My status',
                              style: TextStyle(color: _whiteText, fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Recent Statuses
                    ...recentStatuses.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['userName']?.toString() ?? 'Contact';

                      return GestureDetector(
                        onTap: () => Navigator.pushNamed(context, MyStatusesScreen.routeName),
                        child: Container(
                          width: 114,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: _searchPill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [const Color(0xFF00E5FF).withValues(alpha: 0.2), _searchPill],
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF00E5FF), width: 2.2),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF1E293B),
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: _whiteText, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Text(
                                name,
                                style: const TextStyle(color: _whiteText, fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Channels & Broadcasts', style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _searchPill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentPurple.withValues(alpha: 0.4)),
                ),
                child: const Text('Explore', style: TextStyle(color: _accentPurple, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: _searchPill.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentPurple.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: _accentPurple.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.campaign_rounded, color: _accentPurple, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Official NEX Channel', style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Stay updated with releases and squad tournaments.', style: TextStyle(color: _subTextGrey, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. COMMUNITIES & CLANS SUBSECTION ──────────────────────────────────────
  Widget _buildCommunitiesSubSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversationsStream,
      builder: (context, snapshot) {
        final conversations = _sortConversations(snapshot.data ?? []);
        final groups = conversations.where((c) => (c['isGroup'] as bool? ?? false)).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _searchPill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _accentPurple.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded, color: _accentPurple, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clans & Tactical Squads', style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 17)),
                        SizedBox(height: 4),
                        Text('Manage syndicate channels and squad communication.', style: TextStyle(color: _subTextGrey, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showNewGroupModal,
                    icon: const Icon(Icons.add_circle_rounded, color: _accentCyan, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _searchPill,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text('No syndicate groups yet. Tap + to create one.', style: TextStyle(color: _subTextGrey, fontSize: 14)),
                ),
              )
            else
              ...groups.map((group) {
                final gName = (group['groupName'] as String?) ?? 'Clan Squadron';
                final members = group['participants'] as List? ?? [];
                final lastMsg = (group['lastMessage'] as String?)?.isNotEmpty == true ? group['lastMessage'] : 'No messages yet';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _searchPill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _accentPurple.withValues(alpha: 0.5), width: 2),
                        color: const Color(0xFF1A0F32),
                      ),
                      child: const Icon(Icons.shield_moon_rounded, color: _accentPurple, size: 24),
                    ),
                    title: Text(
                      gName,
                      style: const TextStyle(color: _whiteText, fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    subtitle: Text(
                      '${members.length} members • $lastMsg',
                      style: const TextStyle(color: _subTextGrey, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: _subTextGrey),
                    onTap: () => _openGroupChat(group['id'] as String, gName),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── 7. CALLS SUBSECTION ───────────────────────────────────────────────────
  Widget _buildCallsSubSection() {
    final quickActions = [
      {'label': 'Voice Call', 'icon': Icons.call_outlined},
      {'label': 'Video Feed', 'icon': Icons.videocam_outlined},
      {'label': 'Keypad', 'icon': Icons.dialpad_rounded},
      {'label': 'Squad Comms', 'icon': Icons.headset_mic_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: quickActions.map((act) {
              return Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _searchPill,
                      border: Border.all(color: _accentPurple.withValues(alpha: 0.3)),
                    ),
                    child: Icon(act['icon'] as IconData, color: _whiteText, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    act['label'] as String,
                    style: const TextStyle(color: _subTextGrey, fontSize: 12.5),
                  ),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Text('Recent Transmissions', style: TextStyle(color: _whiteText, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: CallService().getCallHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _accentPurple)));
              }

              final calls = snapshot.data ?? [];
              if (calls.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.phone_missed_rounded, color: _subTextGrey.withValues(alpha: 0.5), size: 48),
                      const SizedBox(height: 12),
                      const Text('No recent call records', style: TextStyle(color: _whiteText, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Encrypted audio and video transmissions will log here.', style: TextStyle(color: _subTextGrey, fontSize: 13)),
                    ],
                  ),
                );
              }

              return Column(
                children: calls.map((call) {
                  final status = call['status']?.toString() ?? 'ended';
                  final isMissed = status == 'missed' || status == 'rejected';
                  final name = call['receiverName']?.toString() ?? call['callerName']?.toString() ?? 'Operative';
                  final isVideo = call['isVideo'] == true;
                  final time = call['timestamp']?.toString() ?? 'Recent';
                  final receiverId = call['receiverId']?.toString() ?? call['callerId']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF1E1038),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: const TextStyle(color: _whiteText, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: isMissed ? Colors.redAccent : _whiteText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    isMissed ? Icons.call_received_rounded : Icons.call_made_rounded,
                                    color: isMissed ? Colors.redAccent : _accentPurple,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(time, style: const TextStyle(color: _subTextGrey, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(isVideo ? Icons.videocam_outlined : Icons.call_outlined, color: _accentPurple, size: 22),
                          onPressed: () {
                            if (receiverId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(
                                    receiverId: receiverId,
                                    receiverName: name,
                                    isVideo: isVideo,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 8. WHATSAPP FLOATING ACTION BUTTONS ────────────────────────────────────
  Widget _buildWhatsAppFAB() {
    if (_currentNavIndex == 1) {
      // Updates tab FABs (Pencil + Camera)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _searchPill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentPurple.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: _whiteText, size: 20),
              onPressed: () => Navigator.pushNamed(context, MyStatusesScreen.routeName),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            backgroundColor: _accentPurple,
            onPressed: () => Navigator.pushNamed(context, MyStatusesScreen.routeName),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
          ),
        ],
      );
    }

    if (_currentNavIndex == 2) {
      // Communities tab FAB (Group +)
      return FloatingActionButton(
        backgroundColor: _accentPurple,
        onPressed: _showNewGroupModal,
        child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 24),
      );
    }

    if (_currentNavIndex == 3) {
      // Calls tab FAB (Phone +)
      return FloatingActionButton(
        backgroundColor: _accentPurple,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
        child: const Icon(Icons.add_call, color: Colors.white, size: 24),
      );
    }

    // Default Chats FAB (AI Assistant + New Direct Chat)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AIChatScreen.routeName),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _searchPill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentCyan.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: _accentCyan.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, color: _accentCyan, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          backgroundColor: _accentPurple,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  // ── 9. WHATSAPP BOTTOM NAVIGATION BAR ──────────────────────────────────────
  Widget _buildWhatsAppBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: _appBarDark,
        border: Border(top: BorderSide(color: _accentPurple.withValues(alpha: 0.25), width: 1.0)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          _tabController.animateTo(index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _appBarDark,
        selectedItemColor: _whiteText,
        unselectedItemColor: _subTextGrey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _currentNavIndex == 0 ? _chipActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: _currentNavIndex == 0 ? Border.all(color: _accentPurple.withValues(alpha: 0.4)) : null,
              ),
              child: const Icon(Icons.chat_bubble_rounded, size: 22),
            ),
            label: 'Comms',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentNavIndex == 1 ? _chipActiveBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: _currentNavIndex == 1 ? Border.all(color: _accentPurple.withValues(alpha: 0.4)) : null,
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded, size: 22),
                ),
                Positioned(
                  top: 2,
                  right: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _accentPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            label: 'Signals',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _currentNavIndex == 2 ? _chipActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: _currentNavIndex == 2 ? Border.all(color: _accentPurple.withValues(alpha: 0.4)) : null,
              ),
              child: const Icon(Icons.shield_moon_rounded, size: 22),
            ),
            label: 'Clans',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _currentNavIndex == 3 ? _chipActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: _currentNavIndex == 3 ? Border.all(color: _accentPurple.withValues(alpha: 0.4)) : null,
              ),
              child: const Icon(Icons.phone_in_talk_rounded, size: 22),
            ),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
}
