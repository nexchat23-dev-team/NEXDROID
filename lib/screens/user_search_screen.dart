import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/contact_request_service.dart';
import '../utils/constants.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  static const routeName = '/user-search';
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ContactRequestService _contactService = ContactRequestService();

  String _searchText = '';
  String? _errorMessage;
  bool _isRefreshing = false;
  bool _showOnlineOnly = false;
  bool _hideCurrentUser = false;
  bool _hideWithoutPublicEmail = false;
  _UserSearchScope _searchScope = _UserSearchScope.all;
  _UserSearchSort _searchSort = _UserSearchSort.usernameAsc;

  late final StreamController<List<Map<String, dynamic>>> _usersStreamController;
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;
  StreamSubscription<User?>? _authSubscription;

  final Map<String, Map<String, dynamic>> _firestoreUsers = {};
  final Map<String, Map<String, dynamic>> _realtimeUsers = {};
  Map<String, dynamic>? _currentUserLocalProfile;

  Stream<List<Map<String, dynamic>>> get _usersStream => _usersStreamController.stream;

  @override
  void initState() {
    super.initState();
    _usersStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

    // Cache current user profile immediately so user is NEVER missing
    _cacheCurrentUserLocal();

    // Bind streams immediately with currently cached user if available
    final initialUser = FirebaseService.auth.currentUser;
    if (initialUser != null) {
      _bindDatabaseStreams(initialUser);
    }

    // Listen to auth state and initialize database subscriptions
    _authSubscription = FirebaseService.auth.authStateChanges().listen((user) {
      if (!mounted) return;
      _cacheCurrentUserLocal(user);
      _bindDatabaseStreams(user);
    });

    // Run initial self-healing check in background
    _selfHealCurrentUser();
  }

  void _cacheCurrentUserLocal([User? user]) {
    final current = user ?? FirebaseService.auth.currentUser;
    if (current == null) return;

    final resolvedUsername = current.displayName?.trim().isNotEmpty == true
        ? current.displayName!.trim()
        : (current.email?.split('@').first ?? 'NEX User');

    _currentUserLocalProfile = {
      'id': current.uid,
      'uid': current.uid,
      'email': current.email ?? '',
      'username': resolvedUsername,
      'name': current.displayName ?? resolvedUsername,
      'photo_url': current.photoURL ?? '',
      'isOnline': true,
      ..._currentUserLocalProfile ?? {},
    };
    _emitMergedUsers();
  }

  Future<void> _selfHealCurrentUser() async {
    try {
      final profile = await FirebaseService.ensureCurrentUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _currentUserLocalProfile = {
            ..._currentUserLocalProfile ?? {},
            ...profile,
            'isOnline': true,
          };
        });
        _emitMergedUsers();
      }
    } catch (e) {
      debugPrint('[UserSearchScreen] Self-heal check note: $e');
    }
  }

  void _bindDatabaseStreams(User? user) {
    // Cancel old subscriptions if any
    _firestoreSubscription?.cancel();
    _realtimeSubscription?.cancel();

    // 1. One-time direct fetch from Firestore for immediate data loading
    FirebaseFirestore.instance.collection('users').get().then((snapshot) {
      if (!mounted) return;
      _onFirestoreSnapshot(snapshot);
    }).catchError((error) {
      debugPrint('[UserSearchScreen] Direct Firestore fetch note: $error');
    });

    // 2. Real-time Firestore stream
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
      _onFirestoreSnapshot,
      onError: (error) {
        debugPrint('[UserSearchScreen] Firestore stream error: $error');
        _emitMergedUsers();
      },
    );

    // 3. Real-time Realtime Database stream
    if (user != null) {
      try {
        _realtimeSubscription = FirebaseService.realtime.ref('users').onValue.listen(
          _onRealtimeSnapshot,
          onError: (error) {
            debugPrint('[UserSearchScreen] RTDB stream error: $error');
            _emitMergedUsers();
          },
        );
      } catch (e) {
        debugPrint('[UserSearchScreen] RTDB listener error: $e');
      }
    } else {
      _realtimeUsers.clear();
      _emitMergedUsers();
    }
  }

  Future<void> _refreshUsers() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      _cacheCurrentUserLocal();
      await _selfHealCurrentUser();

      // Direct Firestore refresh
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      _onFirestoreSnapshot(snapshot);

      // Direct RTDB refresh if available
      try {
        final rtdbSnapshot = await FirebaseService.realtime.ref('users').get();
        if (rtdbSnapshot.exists) {
          _processRealtimeValue(rtdbSnapshot.value);
        }
      } catch (e) {
        debugPrint('[UserSearchScreen] RTDB refresh note: $e');
      }

      setState(() => _errorMessage = null);
    } catch (e) {
      debugPrint('[UserSearchScreen] Refresh error: $e');
      setState(() => _errorMessage = 'Failed to refresh users: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _onFirestoreSnapshot(QuerySnapshot snapshot) {
    _firestoreUsers.clear();
    for (final doc in snapshot.docs) {
      final docData = doc.data() as Map<String, dynamic>? ?? {};
      final id = doc.id.isNotEmpty ? doc.id : (docData['uid']?.toString() ?? docData['id']?.toString() ?? '');
      if (id.isNotEmpty) {
        _firestoreUsers[id] = {'id': id, 'uid': id, ...docData};
      }
    }
    _emitMergedUsers();
  }

  void _onRealtimeSnapshot(DatabaseEvent event) {
    _processRealtimeValue(event.snapshot.value);
  }

  void _processRealtimeValue(dynamic value) {
    _realtimeUsers.clear();
    if (value == null) {
      _emitMergedUsers();
      return;
    }

    if (value is Map) {
      final realtimeMap = Map<String, dynamic>.from(value);
      realtimeMap.forEach((key, element) {
        if (element is Map) {
          final userData = Map<String, dynamic>.from(element);
          final id = userData['uid']?.toString().isNotEmpty == true
              ? userData['uid'].toString()
              : (userData['id']?.toString().isNotEmpty == true ? userData['id'].toString() : key.toString());
          if (id.isNotEmpty) {
            _realtimeUsers[id] = {
              'id': id,
              'uid': id,
              'email': userData['email']?.toString() ?? '',
              'username': userData['username']?.toString() ?? '',
              'name': userData['name']?.toString() ?? '',
              'photo_url': userData['photo_url']?.toString() ?? userData['profilePicUrl']?.toString() ?? '',
              'isOnline': userData['isOnline'] == true || userData['online'] == true,
              ...userData,
            };
          }
        }
      });
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final element = value[i];
        if (element is Map) {
          final userData = Map<String, dynamic>.from(element);
          final id = userData['uid']?.toString().isNotEmpty == true
              ? userData['uid'].toString()
              : (userData['id']?.toString().isNotEmpty == true ? userData['id'].toString() : i.toString());
          if (id.isNotEmpty) {
            _realtimeUsers[id] = {
              'id': id,
              'uid': id,
              'email': userData['email']?.toString() ?? '',
              'username': userData['username']?.toString() ?? '',
              'name': userData['name']?.toString() ?? '',
              'photo_url': userData['photo_url']?.toString() ?? '',
              'isOnline': userData['isOnline'] == true || userData['online'] == true,
              ...userData,
            };
          }
        }
      }
    }
    _emitMergedUsers();
  }

  void _emitMergedUsers() {
    if (!mounted) return;
    final mergedUsers = <String, Map<String, dynamic>>{};

    // 1. Add Realtime Database entries
    mergedUsers.addAll(_realtimeUsers);

    // 2. Add/Merge Firestore entries (authoritative)
    _firestoreUsers.forEach((key, data) {
      mergedUsers[key] = {...mergedUsers[key] ?? {}, ...data};
    });

    // 3. Guarantee currently authenticated user is ALWAYS included
    final currentUid = FirebaseService.auth.currentUser?.uid;
    if (currentUid != null && currentUid.isNotEmpty) {
      final existing = mergedUsers[currentUid] ?? {};
      final local = _currentUserLocalProfile ?? {};
      mergedUsers[currentUid] = {
        ...local,
        ...existing,
        'id': currentUid,
        'uid': currentUid,
        'isOnline': true,
      };
    }

    if (!_usersStreamController.isClosed) {
      _usersStreamController.add(mergedUsers.values.toList());
    }
  }

  List<_UserSearchResult> _filterUsers(
    List<Map<String, dynamic>> rows,
    String currentUserId,
  ) {
    final rawQuery = _searchText.trim().toLowerCase();
    final query = rawQuery.startsWith('@') ? rawQuery.substring(1) : rawQuery;
    final results = <_UserSearchResult>[];

    final currentUid = currentUserId.isNotEmpty
        ? currentUserId
        : (FirebaseService.auth.currentUser?.uid ?? _currentUserLocalProfile?['uid'] ?? '');

    // Current user matching with merged freshest data from rows
    Map<String, dynamic>? currentUserFromRows;
    if (currentUid.isNotEmpty) {
      for (final r in rows) {
        final rId = (r['id'] ?? r['uid'] ?? r['userId'])?.toString() ?? '';
        if (rId.isNotEmpty && rId == currentUid) {
          currentUserFromRows = r;
          break;
        }
      }
    }

    final myProfile = {
      ...?currentUserFromRows,
      ...?_currentUserLocalProfile,
    };
    final myId = currentUid;

    if (myId.isNotEmpty && !_hideCurrentUser) {
      final rawName = (myProfile['name'] ?? myProfile['displayName'] ?? myProfile['display_name'])?.toString().trim() ?? '';
      final rawUsername = (myProfile['username'])?.toString().trim() ?? '';
      final rawEmail = (myProfile['email'] ?? FirebaseService.auth.currentUser?.email ?? '').toString().trim();
      final myPhoto = (myProfile['photo_url'] ?? myProfile['photoUrl'] ?? myProfile['profilePicUrl'] ?? '').toString().trim();

      final resolved = AuthService.resolveDisplayName(
        name: rawName,
        username: rawUsername,
        email: rawEmail,
      );

      final myName = resolved.isNotEmpty ? resolved : (FirebaseService.auth.currentUser?.displayName ?? 'You');
      final myUsername = rawUsername.isNotEmpty ? rawUsername : (FirebaseService.auth.currentUser?.email?.split('@').first ?? myName);

      final myNameLower = myName.toLowerCase();
      final myUsernameLower = myUsername.toLowerCase();
      final myEmailLower = rawEmail.toLowerCase();
      final myIdLower = myId.toLowerCase();

      final myMatchesQuery = query.isEmpty ||
          myNameLower.contains(query) ||
          myUsernameLower.contains(query) ||
          myEmailLower.contains(query) ||
          myIdLower.contains(query);

      if (myMatchesQuery) {
        results.add(_UserSearchResult(
          uid: myId,
          username: myName,
          rawUsername: myUsername,
          email: rawEmail.isNotEmpty ? rawEmail : 'Your Account',
          photoUrl: myPhoto,
          isOnline: true,
          isCurrentUser: true,
        ));
      }
    }

    for (final data in rows) {
      final uid = (data['id'] ?? data['uid'] ?? data['userId'])?.toString() ?? '';
      if (uid.isEmpty || uid == myId) continue;

      final rawName = (data['name'] ?? data['displayName'] ?? data['display_name'])?.toString().trim() ?? '';
      final rawUsername = data['username']?.toString().trim() ?? '';
      final rawEmail = data['email']?.toString().trim() ?? '';
      final photoUrl = (data['photo_url'] ?? data['photoUrl'] ?? data['profilePicUrl'])?.toString().trim() ?? '';

      final displayName = AuthService.resolveDisplayName(
        name: rawName,
        username: rawUsername,
        email: rawEmail,
      );

      final email = rawEmail.isNotEmpty ? rawEmail : 'No public email';
      final displayNameLower = displayName.toLowerCase();
      final usernameLower = rawUsername.toLowerCase();
      final rawNameLower = rawName.toLowerCase();
      final emailLower = email.toLowerCase();
      final uidLower = uid.toLowerCase();
      final isOnline = data['isOnline'] == true || data['online'] == true;
      final isCurrentUser = uid == currentUserId;

      if (_showOnlineOnly && !isOnline) continue;
      if (_hideCurrentUser && isCurrentUser) continue;
      if (_hideWithoutPublicEmail && rawEmail.isEmpty) continue;

      final matchesQuery = query.isEmpty ||
          (_searchScope == _UserSearchScope.all &&
              (displayNameLower.contains(query) ||
                  usernameLower.contains(query) ||
                  rawNameLower.contains(query) ||
                  emailLower.contains(query) ||
                  uidLower.contains(query))) ||
          (_searchScope == _UserSearchScope.usernameOnly &&
              usernameLower.contains(query)) ||
          (_searchScope == _UserSearchScope.emailOnly &&
              emailLower.contains(query)) ||
          (_searchScope == _UserSearchScope.nameOnly &&
              (rawNameLower.contains(query) || displayNameLower.contains(query)));

      if (matchesQuery) {
        results.add(_UserSearchResult(
          uid: uid,
          username: displayName,
          rawUsername: rawUsername.isNotEmpty ? rawUsername : displayName,
          email: email,
          photoUrl: photoUrl,
          isOnline: isOnline,
          isCurrentUser: isCurrentUser,
        ));
      }
    }

    if (_searchSort == _UserSearchSort.usernameAsc) {
      results.sort((a, b) {
        if (a.isCurrentUser) return -1;
        if (b.isCurrentUser) return 1;
        return a.username.compareTo(b.username);
      });
    } else if (_searchSort == _UserSearchSort.usernameDesc) {
      results.sort((a, b) {
        if (a.isCurrentUser) return -1;
        if (b.isCurrentUser) return 1;
        return b.username.compareTo(a.username);
      });
    } else {
      results.sort((a, b) {
        if (a.isCurrentUser) return -1;
        if (b.isCurrentUser) return 1;
        final onlineA = a.isOnline ? 0 : 1;
        final onlineB = b.isOnline ? 0 : 1;
        if (onlineA != onlineB) return onlineA.compareTo(onlineB);
        return a.username.compareTo(b.username);
      });
    }
    return results;
  }

  Future<void> _openChat(_UserSearchResult user) async {
    if (!mounted) return;

    try {
      final currentUserId = _chatService.currentUserId ?? FirebaseService.auth.currentUser?.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('Please sign in first to chat.');
      }

      if (user.isCurrentUser || user.uid == currentUserId) {
        Navigator.pushNamed(context, ProfileScreen.routeName);
        return;
      }

      // 1. Safe block check
      bool isBlocked = false;
      try {
        isBlocked = await _contactService.isBlocked(user.uid);
      } catch (e) {
        debugPrint('[UserSearchScreen] Block check note: $e');
      }

      if (isBlocked) {
        throw Exception('Messaging is unavailable because one of you blocked the other.');
      }

      // 2. Safe privacy & request check
      bool canMsg = true;
      try {
        canMsg = await _contactService.canMessage(user.uid);
      } catch (e) {
        debugPrint('[UserSearchScreen] canMessage note: $e');
      }

      if (!canMsg) {
        String? status;
        try {
          status = await _contactService.getRequestStatus(user.uid);
        } catch (_) {}

        if (status == 'pending') {
          throw Exception('Message request already sent. Waiting for approval.');
        }
        final message = await _showRequestDialog(user);
        if (message == null) return;
        await _contactService.sendMessageRequest(toUserId: user.uid, message: message);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message request sent.')),
        );
        return;
      }

      final conversationId = await _chatService.createOrGetDirectConversation(user.uid);
      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        ChatScreen.routeName,
        arguments: {
          'conversationId': conversationId,
          'participantName': user.username,
          'participantId': user.uid,
        },
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;

      final currentUserId = _chatService.currentUserId ?? FirebaseService.auth.currentUser?.uid;
      if (currentUserId != null && currentUserId.isNotEmpty && currentUserId != user.uid) {
        final fallbackConvId = ChatService.getDirectConversationId(currentUserId, user.uid);
        Navigator.pushNamed(
          context,
          ChatScreen.routeName,
          arguments: {
            'conversationId': fallbackConvId,
            'participantName': user.username,
            'participantId': user.uid,
          },
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open chat: ${e.toString()}')),
      );
    }
  }

  Future<String?> _showRequestDialog(_UserSearchResult user) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF10182D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Request to message ${user.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Optional introduction...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0A1124),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL', style: TextStyle(color: Colors.white60))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kNeonGreen, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('SEND REQUEST', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    controller.dispose();
    return message;
  }

  Future<void> _showSearchSettings() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF10182D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Search settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  activeThumbColor: kNeonGreen,
                  title: const Text('Show online users only', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Hide users who are not currently online.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _showOnlineOnly,
                  onChanged: (value) => setDialogState(() => _showOnlineOnly = value),
                ),
                SwitchListTile(
                  activeThumbColor: kNeonGreen,
                  title: const Text('Hide my profile', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Remove your own account from search results.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _hideCurrentUser,
                  onChanged: (value) => setDialogState(() => _hideCurrentUser = value),
                ),
                SwitchListTile(
                  activeThumbColor: kNeonGreen,
                  title: const Text('Only show users with public email', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Exclude accounts without a public email address.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _hideWithoutPublicEmail,
                  onChanged: (value) => setDialogState(() => _hideWithoutPublicEmail = value),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Search scope', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<_UserSearchScope>(
                  dropdownColor: const Color(0xFF10182D),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0E172E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  initialValue: _searchScope,
                  items: const [
                    DropdownMenuItem(
                      value: _UserSearchScope.all,
                      child: Text('All fields', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: _UserSearchScope.usernameOnly,
                      child: Text('Username only', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: _UserSearchScope.emailOnly,
                      child: Text('Email only', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: _UserSearchScope.nameOnly,
                      child: Text('Name only', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => _searchScope = value);
                  },
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sort results', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<_UserSearchSort>(
                  dropdownColor: const Color(0xFF10182D),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0E172E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  initialValue: _searchSort,
                  items: const [
                    DropdownMenuItem(
                      value: _UserSearchSort.usernameAsc,
                      child: Text('Username A → Z', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: _UserSearchSort.usernameDesc,
                      child: Text('Username Z → A', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: _UserSearchSort.onlineFirst,
                      child: Text('Online users first', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => _searchSort = value);
                  },
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(() {
                _showOnlineOnly = false;
                _hideCurrentUser = false;
                _hideWithoutPublicEmail = false;
                _searchScope = _UserSearchScope.all;
                _searchSort = _UserSearchSort.usernameAsc;
              }),
              child: const Text('RESET', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL', style: TextStyle(color: Colors.white60))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kNeonGreen, foregroundColor: Colors.black),
              onPressed: () {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              },
              child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPrivacySettings() async {
    final uid = _chatService.currentUserId;
    if (uid == null) return;
    final privacy = await _contactService.getPrivacy(uid);
    if (!mounted) return;
    var allowMessages = privacy['allowIncomingMessages'] == true;
    var allowAnyone = privacy['allowAnyUserMessage'] == true;
    var allowCalls = privacy['allowIncomingCalls'] == true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF10182D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Contact privacy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                activeThumbColor: kNeonGreen,
                title: const Text('Allow incoming messages', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Turn off to block all new chats.', style: TextStyle(color: Colors.white54)),
                value: allowMessages,
                onChanged: (value) => setDialogState(() => allowMessages = value),
              ),
              SwitchListTile(
                activeThumbColor: kNeonGreen,
                title: const Text('Allow anyone to message me', style: TextStyle(color: Colors.white)),
                subtitle: const Text('When off, users must send a request first.', style: TextStyle(color: Colors.white54)),
                value: allowAnyone,
                onChanged: allowMessages ? (value) => setDialogState(() => allowAnyone = value) : null,
              ),
              SwitchListTile(
                activeThumbColor: kNeonGreen,
                title: const Text('Allow incoming calls', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Turn off to block new voice and video calls.', style: TextStyle(color: Colors.white54)),
                value: allowCalls,
                onChanged: (value) => setDialogState(() => allowCalls = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL', style: TextStyle(color: Colors.white60))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kNeonGreen, foregroundColor: Colors.black),
              onPressed: () async {
                await _contactService.updatePrivacy(
                  allowIncomingMessages: allowMessages,
                  allowAnyUserMessage: allowAnyone,
                  allowIncomingCalls: allowCalls,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageRequests() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10182D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: _contactService.incomingRequests(),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const [];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Message requests', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No pending requests.', style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                  ...requests.map((request) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: kNeonPurple.withValues(alpha: 0.2),
                      child: const Icon(Icons.person_outline, color: Colors.white),
                    ),
                    title: Text('User ${request['fromId']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      request['message']?.toString().isNotEmpty == true ? request['message'].toString() : 'wants to message you',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () => _contactService.respondToRequest(requestId: request['id'].toString(), accept: false),
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                        ),
                        IconButton(
                          tooltip: 'Accept',
                          onPressed: () => _contactService.respondToRequest(requestId: request['id'].toString(), accept: true),
                          icon: const Icon(Icons.check, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firestoreSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _authSubscription?.cancel();
    _usersStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _chatService.currentUserId ?? FirebaseService.auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A111F),
        elevation: 0,
        title: const Text(
          'USER SEARCH',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh directory',
            onPressed: _refreshUsers,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kNeonBlue),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Message requests',
            onPressed: _showMessageRequests,
            icon: const Icon(Icons.mark_email_unread_rounded),
          ),
          IconButton(
            tooltip: 'Search settings',
            onPressed: _showSearchSettings,
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'Contact privacy',
            onPressed: _showPrivacySettings,
            icon: const Icon(Icons.privacy_tip_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input field
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _searchText = value),
                decoration: InputDecoration(
                  hintText: 'Search by username, name, or email...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: kNeonBlue),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0D162F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),

              // Scope & filter chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildScopeChip('All', _UserSearchScope.all),
                    const SizedBox(width: 8),
                    _buildScopeChip('Username', _UserSearchScope.usernameOnly),
                    const SizedBox(width: 8),
                    _buildScopeChip('Email', _UserSearchScope.emailOnly),
                    const SizedBox(width: 8),
                    _buildScopeChip('Name', _UserSearchScope.nameOnly),
                    if (_showOnlineOnly) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Online only', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: kNeonGreen.withValues(alpha: 0.2),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                        onDeleted: () => setState(() => _showOnlineOnly = false),
                      ),
                    ],
                    if (_hideCurrentUser) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Hide me', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.white12,
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                        onDeleted: () => setState(() => _hideCurrentUser = false),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 18),
                        onPressed: _refreshUsers,
                      ),
                    ],
                  ),
                ),

              // Current User Identity Banner (Users can always see themselves)
              _buildMyIdentityCard(currentUserId),

              Expanded(
                child: RefreshIndicator(
                  color: kNeonGreen,
                  backgroundColor: const Color(0xFF10182D),
                  onRefresh: _refreshUsers,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _usersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: kNeonPurple),
                        );
                      }

                      final results = _filterUsers(snapshot.data ?? [], currentUserId);
                      if (results.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: kNeonBlue.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person_search_rounded, size: 44, color: kNeonBlue),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchText.trim().isEmpty
                                        ? 'No other users found.'
                                        : 'No matches found for "$_searchText".',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Swipe down to refresh or check search settings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                  if (_searchText.isNotEmpty || _showOnlineOnly || _hideCurrentUser) ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kNeonBlue.withValues(alpha: 0.2),
                                        foregroundColor: kNeonBlue,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchText = '';
                                          _showOnlineOnly = false;
                                          _hideCurrentUser = false;
                                          _searchScope = _UserSearchScope.all;
                                        });
                                      },
                                      child: const Text('Reset search & filters'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 20),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = results[index];
                          return _buildUserCard(user);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChip(String label, _UserSearchScope scope) {
    final isSelected = _searchScope == scope;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.white70,
        ),
      ),
      selected: isSelected,
      selectedColor: kNeonBlue,
      backgroundColor: const Color(0xFF0D162F),
      onSelected: (selected) {
        if (selected) {
          setState(() => _searchScope = scope);
        }
      },
    );
  }

  Widget _buildMyIdentityCard(String currentUserId) {
    final myProfile = _currentUserLocalProfile ?? {};
    final myId = (myProfile['id'] ?? myProfile['uid'] ?? currentUserId)?.toString() ?? currentUserId;
    if (myId.isEmpty) return const SizedBox.shrink();

    final rawName = (myProfile['name'] ?? myProfile['displayName'] ?? myProfile['display_name'])?.toString().trim() ?? '';
    final rawUsername = (myProfile['username'])?.toString().trim() ?? '';
    final rawEmail = (myProfile['email'] ?? FirebaseService.auth.currentUser?.email ?? '').toString().trim();
    final photoUrl = (myProfile['photo_url'] ?? myProfile['photoUrl'] ?? myProfile['profilePicUrl'] ?? '').toString();

    final resolved = AuthService.resolveDisplayName(
      name: rawName,
      username: rawUsername,
      email: rawEmail,
    );
    final displayName = resolved.isNotEmpty ? resolved : (FirebaseService.auth.currentUser?.displayName ?? 'You');
    final username = rawUsername.isNotEmpty ? rawUsername : (FirebaseService.auth.currentUser?.email?.split('@').first ?? displayName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeonBlue.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kNeonBlue.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kNeonBlue.withValues(alpha: 0.25),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: kNeonBlue, fontWeight: FontWeight.w900, fontSize: 16),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: kNeonGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF060B14), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: kNeonBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kNeonBlue.withValues(alpha: 0.5)),
                      ),
                      child: const Text('YOU', style: TextStyle(color: kNeonBlue, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username • ${rawEmail.isNotEmpty ? rawEmail : 'Your Account'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Copy your UID',
            icon: const Icon(Icons.copy_rounded, color: kNeonBlue, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: myId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Your User ID copied to clipboard!')),
              );
            },
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: kNeonBlue,
              side: BorderSide(color: kNeonBlue.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: () => Navigator.pushNamed(context, ProfileScreen.routeName),
            child: const Text('PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(_UserSearchResult user) {
    return Container(
      decoration: BoxDecoration(
        color: user.isCurrentUser ? const Color(0xFF131D38) : const Color(0xFF0D162F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: user.isCurrentUser ? kNeonBlue.withValues(alpha: 0.45) : Colors.white10,
          width: user.isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: user.isCurrentUser
                  ? kNeonBlue.withValues(alpha: 0.25)
                  : kNeonPurple.withValues(alpha: 0.25),
              backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
              child: user.photoUrl.isEmpty
                  ? Text(
                      user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: user.isCurrentUser ? kNeonBlue : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            if (user.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kNeonGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF060B14), width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isCurrentUser) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kNeonBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kNeonBlue.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(color: kNeonBlue, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.email,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (user.isCurrentUser)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Your account is indexed & searchable',
                    style: TextStyle(color: kNeonGreen, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        trailing: user.isCurrentUser
            ? OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNeonBlue,
                  side: BorderSide(color: kNeonBlue.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => Navigator.pushNamed(context, ProfileScreen.routeName),
                child: const Text('PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _openChat(user),
                child: const Text(
                  'CHAT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}

enum _UserSearchScope {
  all,
  usernameOnly,
  emailOnly,
  nameOnly,
}

enum _UserSearchSort {
  usernameAsc,
  usernameDesc,
  onlineFirst,
}

class _UserSearchResult {
  final String uid;
  final String username;
  final String rawUsername;
  final String email;
  final String photoUrl;
  final bool isOnline;
  final bool isCurrentUser;

  _UserSearchResult({
    required this.uid,
    required this.username,
    required this.rawUsername,
    required this.email,
    this.photoUrl = '',
    this.isOnline = false,
    this.isCurrentUser = false,
  });
}
