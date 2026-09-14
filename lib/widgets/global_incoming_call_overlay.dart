import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/call_screen.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../services/game_sound_service.dart';

class GlobalIncomingCallOverlay extends StatefulWidget {
  final Widget child;
  const GlobalIncomingCallOverlay({super.key, required this.child});

  @override
  State<GlobalIncomingCallOverlay> createState() => _GlobalIncomingCallOverlayState();
}

class _GlobalIncomingCallOverlayState extends State<GlobalIncomingCallOverlay> with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  final GameSoundService _soundService = GameSoundService();

  StreamSubscription<List<Map<String, dynamic>>>? _incomingCallsSub;
  Timer? _ringtoneTimer;
  Map<String, dynamic>? _activeIncomingCall;
  String? _callerResolvedName;
  String? _callerAvatarUrl;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _listenForIncomingCalls();
  }

  @override
  void dispose() {
    _incomingCallsSub?.cancel();
    _ringtoneTimer?.cancel();
    _soundService.stopCallAudio();
    _pulseController.dispose();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    _incomingCallsSub?.cancel();
    _incomingCallsSub = _callService.getIncomingCalls().listen((calls) async {
      if (!mounted) return;

      if (calls.isEmpty) {
        if (_activeIncomingCall != null) {
          _stopRingtone();
          setState(() {
            _activeIncomingCall = null;
            _callerResolvedName = null;
            _callerAvatarUrl = null;
          });
        }
        return;
      }

      final incoming = calls.first;
      final callId = incoming['id']?.toString() ?? incoming['callId']?.toString();

      if (_activeIncomingCall != null && _activeIncomingCall!['id'] == callId) {
        return; // Already ringing for this call
      }

      // New incoming call!
      final callerId = incoming['callerId']?.toString() ?? '';
      String callerName = incoming['callerName']?.toString() ?? 'Operative';

      if (callerId.isNotEmpty) {
        try {
          final prof = await FirebaseService.getUserProfile(callerId);
          if (prof != null) {
            final resolved = AuthService.resolveDisplayName(
              name: prof['displayName'] ?? prof['display_name'] ?? prof['name'],
              username: prof['username'],
              email: prof['email'],
            );
            if (resolved.isNotEmpty) callerName = resolved;
            _callerAvatarUrl = prof['photo_url'] ?? prof['photoUrl'] ?? prof['profilePicUrl'];
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _activeIncomingCall = incoming;
        _callerResolvedName = callerName;
      });

      _startRingtone();
    });
  }

  void _startRingtone() {
    _stopRingtone();
    _soundService.playRingtone();
    _ringtoneTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_activeIncomingCall != null) {
        _soundService.playRingtone();
      } else {
        _stopRingtone();
      }
    });
  }

  void _stopRingtone() {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
    _soundService.stopCallAudio();
  }

  Future<void> _acceptCall(BuildContext context) async {
    if (_activeIncomingCall == null) return;
    final callData = _activeIncomingCall!;
    final callId = callData['id']?.toString() ?? callData['callId']?.toString() ?? '';
    final callerName = _callerResolvedName ?? callData['callerName']?.toString() ?? 'Operative';
    final isVideo = callData['isVideo'] == true;

    _stopRingtone();
    _soundService.playCallConnect();

    setState(() {
      _activeIncomingCall = null;
    });

    if (context.mounted && callId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            receiverName: callerName,
            isVideo: isVideo,
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    if (_activeIncomingCall == null) return;
    final callData = _activeIncomingCall!;
    final callId = callData['id']?.toString() ?? callData['callId']?.toString() ?? '';

    _stopRingtone();
    _soundService.playCallDisconnect();

    setState(() {
      _activeIncomingCall = null;
    });

    if (callId.isNotEmpty) {
      await _callService.rejectCall(callId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_activeIncomingCall != null) _buildIncomingCallOverlay(context),
      ],
    );
  }

  Widget _buildIncomingCallOverlay(BuildContext context) {
    final callerName = _callerResolvedName ?? _activeIncomingCall!['callerName']?.toString() ?? 'Operative';
    final isVideo = _activeIncomingCall!['isVideo'] == true;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF140B28).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFB44FFF), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB44FFF).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Glowing Pulsing Avatar
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.3 + (_pulseController.value * 0.4)),
                              blurRadius: 10 + (_pulseController.value * 8),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF261247),
                          backgroundImage: _callerAvatarUrl != null && _callerAvatarUrl!.isNotEmpty
                              ? NetworkImage(_callerAvatarUrl!)
                              : null,
                          child: _callerAvatarUrl == null || _callerAvatarUrl!.isEmpty
                              ? Text(
                                  callerName.isNotEmpty ? callerName[0].toUpperCase() : 'O',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                              color: const Color(0xFF00E5FF),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isVideo ? 'Incoming Video Signal...' : 'Incoming Cyber Call...',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _declineCall();
                      },
                      icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'DECLINE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2A6D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Accept Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _acceptCall(context);
                      },
                      icon: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'ACCEPT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
