import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../services/game_sound_service.dart';
import '../services/permissions_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.receiverName,
    required this.isVideo,
    this.receiverId,
    this.callId,
  }) : assert(receiverId != null || callId != null,
            'Either receiverId or callId must be provided');

  final String? receiverId;
  final String receiverName;
  final bool isVideo;
  final String? callId;

  bool get isIncoming => callId != null;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final CallService _callService = CallService();
  final PermissionsService _permissionsService = PermissionsService();
  final GameSoundService _soundService = GameSoundService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  late AnimationController _holoController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _callId;
  String? _remoteAvatarUrl;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = true;
  bool _isEnding = false;
  bool _isConnected = false;
  bool _showLensSheet = false;
  String _selectedLens = 'none';
  final List<_FloatingStickerData> _floatingStickers = [];
  final List<RTCIceCandidate> _earlyIceCandidates = [];
  StreamSubscription<DatabaseEvent>? _reactionsSub;

  Duration _callDuration = Duration.zero;
  Timer? _callTimer;
  Timer? _dialToneTimer;
  StreamSubscription<Map<String, dynamic>>? _callSubscription;
  String _statusText = 'Establishing secure quantum link...';

  @override
  void initState() {
    super.initState();
    _holoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _fetchRemoteAvatar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCall());
  }

  Future<void> _fetchRemoteAvatar() async {
    final targetId = widget.receiverId;
    if (targetId != null && targetId.isNotEmpty) {
      try {
        final prof = await FirebaseService.getUserProfile(targetId);
        if (prof != null && mounted) {
          setState(() {
            _remoteAvatarUrl = prof['photo_url'] ?? prof['photoUrl'] ?? prof['profilePicUrl'];
          });
        }
      } catch (_) {}
    }
  }

  void _listenForLiveReactions() {
    if (_callId == null || _reactionsSub != null) return;
    try {
      _reactionsSub = FirebaseService.realtime
          .ref('calls/$_callId/reactions')
          .limitToLast(1)
          .onChildAdded
          .listen((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          final from = val['from']?.toString();
          final emoji = val['emoji']?.toString() ?? '⚡';
          if (from != _callService.currentUserId) {
            _spawnFloatingSticker(emoji, isRemote: true);
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _sendReaction(String emoji, String soundType) {
    HapticFeedback.mediumImpact();
    _spawnFloatingSticker(emoji, isRemote: false);

    switch (soundType) {
      case 'laser':
        _soundService.playLaser();
        break;
      case 'alien':
        _soundService.playAlienBeam();
        break;
      case 'magic':
        _soundService.playMagic();
        break;
      case 'hyperspace':
        _soundService.playHyperspace();
        break;
      case 'star':
        _soundService.playShootingStar();
        break;
      default:
        _soundService.playCoin();
    }

    if (_callId != null) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      try {
        FirebaseService.realtime.ref('calls/$_callId/reactions').push().set({
          'from': _callService.currentUserId ?? '',
          'emoji': emoji,
          'timestamp': nowIso,
        });
      } catch (_) {}
    }
  }

  void _spawnFloatingSticker(String emoji, {bool isRemote = false}) {
    if (!mounted) return;
    final randomX = 0.2 + (Random().nextDouble() * 0.6);
    final sticker = _FloatingStickerData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      emoji: emoji,
      startX: randomX,
    );

    setState(() {
      _floatingStickers.add(sticker);
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _floatingStickers.removeWhere((s) => s.id == sticker.id);
        });
      }
    });
  }

  @override
  void dispose() {
    _holoController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _reactionsSub?.cancel();
    _callSubscription?.cancel();
    _callTimer?.cancel();
    _dialToneTimer?.cancel();
    _soundService.stopCallAudio();
    _stopMedia();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final micGranted =
          await _permissionsService.requestMicrophonePermission();
      final cameraGranted = widget.isVideo
          ? await _permissionsService.requestCameraPermission()
          : true;

      if (!mounted) return;

      if (!micGranted || (widget.isVideo && !cameraGranted)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Microphone and camera permissions are required for calls.')));
        if (mounted) Navigator.pop(context);
        return;
      }

      await _startLocalMedia();
      if (widget.isIncoming) {
        _callId = widget.callId;
        _listenForRemoteSignals();
        _listenForCallUpdates();
        await _acceptIncomingCall();
      } else {
        await _createActiveCall();
        // Play outgoing dial tone loop
        _startDialToneLoop();
      }

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to start call: $e')));
      Navigator.pop(context);
    }
  }

  void _startDialToneLoop() {
    _soundService.playDialTone();
    _dialToneTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isConnected && !_isEnding) {
        _soundService.playDialTone();
      } else {
        _dialToneTimer?.cancel();
      }
    });
  }

  void _stopCallSounds() {
    _dialToneTimer?.cancel();
    _soundService.stopCallAudio();
  }

  Future<void> _startLocalMedia() async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': widget.isVideo ? {'facingMode': 'user'} : false,
    };

    _localStream = await Helper.openCamera(constraints);
    _localRenderer.srcObject = _localStream;

    _peerConnection = await _createPeerConnection();

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    if (mounted) setState(() {});
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config, {});

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        if (mounted) setState(() {});
      }
    };

    pc.onIceCandidate = (candidate) async {
      if (_callId != null) {
        await _callService.addIceCandidate(_callId!, candidate.toMap());
      } else {
        _earlyIceCandidates.add(candidate);
      }
    };

    pc.onConnectionState = (state) {
      if (!mounted) return;
      setState(() => _statusText = _connectionLabel(state));
    };

    return pc;
  }

  Future<void> _createActiveCall() async {
    _callId = await _callService.initiateCall(
        receiverId: widget.receiverId!, isVideo: widget.isVideo);

    // Flush any early ICE candidates that fired before initiateCall returned
    for (final candidate in _earlyIceCandidates) {
      await _callService.addIceCandidate(_callId!, candidate.toMap());
    }
    _earlyIceCandidates.clear();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _callService.setSDP(_callId!, 'offer', offer.sdp ?? '');
    _listenForRemoteSignals();
    _listenForCallUpdates();

    if (!mounted) return;

    setState(() => _statusText = 'Calling ${widget.receiverName}...');
  }

  Future<void> _acceptIncomingCall() async {
    if (_callId == null) {
      throw Exception('Missing call ID for incoming call');
    }

    setState(() {
      _statusText = 'Answering ${widget.isVideo ? 'video' : 'voice'} call...';
    });

    _listenForRemoteSignals();
    _listenForCallUpdates();

    await _waitForOfferAndAnswer();
    await _callService.acceptCall(_callId!);

    if (!mounted) return;

    setState(() {
      _statusText = 'Connected with ${widget.receiverName}';
      _isConnected = true;
    });

    _startCallTimer();
  }

  void _listenForCallUpdates() {
    if (_callId == null) return;
    _listenForLiveReactions();

    _callSubscription ??=
        _callService.watchCall(_callId!).listen((callData) async {
      if (!mounted) return;

      final status =
          (callData['status'] as String?)?.toLowerCase() ?? 'pending';
      if (status == 'rejected') {
        _stopCallSounds();
        _soundService.playCallDisconnect();
        setState(() {
          _statusText = 'Call rejected';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
        return;
      }

      if (status == 'ended') {
        _stopCallSounds();
        _soundService.playCallDisconnect();
        setState(() {
          _statusText = 'Call ended';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
        return;
      }

      if (status == 'active') {
        if (!_isConnected) {
          _stopCallSounds();
          _soundService.playCallConnect();
          setState(() {
            _statusText = 'Connected with ${widget.receiverName}';
            _isConnected = true;
          });
          _startCallTimer();
        }
      }
    });
  }

  Future<void> _waitForOfferAndAnswer() async {
    if (_callId == null) return;
    final currentUserId = _callService.currentUserId;

    final offerRows = await _callService.getSDP(_callId!).firstWhere((rows) {
      return rows.any((row) {
        final type = row['type']?.toString();
        final from = row['from']?.toString();
        return type == 'offer' && from != currentUserId;
      });
    }).timeout(const Duration(seconds: 10), onTimeout: () => []);

    if (offerRows.isEmpty) {
      debugPrint('[CallScreen] Offer wait timed out or empty');
      return;
    }

    final offerRow = offerRows.firstWhere((row) {
      final type = row['type']?.toString();
      final from = row['from']?.toString();
      return type == 'offer' && from != currentUserId;
    });
    final remoteSdp = offerRow['sdp']?.toString() ?? '';
    if (remoteSdp.isNotEmpty && _peerConnection != null) {
      await _peerConnection!
          .setRemoteDescription(RTCSessionDescription(remoteSdp, 'offer'));

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      await _callService.setSDP(_callId!, 'answer', answer.sdp ?? '');
      await _callService.updateCallStatus(_callId!, 'active');
    }

    if (!mounted) return;
    setState(
        () => _statusText = 'Accepting call from ${widget.receiverName}...');
  }

  void _listenForRemoteSignals() {
    if (_callId == null) return;

    _callService.getSDP(_callId!).listen((rows) async {
      if (!mounted || _peerConnection == null) return;

      final answerRows = rows.where((row) {
        final type = row['type']?.toString();
        return type == 'answer';
      }).toList();

      if (answerRows.isEmpty) return;

      final remoteSdp = answerRows.first['sdp']?.toString();
      if (remoteSdp == null || remoteSdp.isEmpty) return;

      if (_peerConnection?.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        await _peerConnection!
            .setRemoteDescription(RTCSessionDescription(remoteSdp, 'answer'));
      }
      if (!mounted) return;
      _stopCallSounds();
      _soundService.playCallConnect();
      setState(() {
        _statusText = 'Connected with ${widget.receiverName}';
        _isConnected = true;
      });
      _startCallTimer();
    });

    _callService.getIceCandidates(_callId!).listen((rows) async {
      if (_peerConnection == null) return;

      final currentUserId = _callService.currentUserId;
      for (final row in rows) {
        final candidate = row['candidate'] as Map<String, dynamic>?;
        final from = row['from']?.toString();
        if (candidate == null || from == null || from == currentUserId) {
          continue;
        }

        final sdpMid = candidate['sdpMid']?.toString();
        final sdpMLineIndex = candidate['sdpMLineIndex'];
        final candidateString = candidate['candidate']?.toString();
        if (candidateString == null || candidateString.isEmpty) continue;

        await _peerConnection!.addCandidate(
          RTCIceCandidate(
              candidateString,
              sdpMid ?? '',
              sdpMLineIndex is int
                  ? sdpMLineIndex
                  : int.tryParse(sdpMLineIndex?.toString() ?? '0') ?? 0),
        );
      }
    });
  }

  Future<void> _toggleMic() async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return;

    final track = audioTracks.first;
    _isMuted = !_isMuted;
    track.enabled = !_isMuted;

    if (mounted) setState(() {});
  }

  Future<void> _toggleVideo() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    final track = videoTracks.first;
    _isVideoEnabled = !_isVideoEnabled;
    track.enabled = _isVideoEnabled;

    if (mounted) setState(() {});
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = Duration.zero;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(
          () => _callDuration = _callDuration + const Duration(seconds: 1));
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours.toString().padLeft(2, '0')}:' : ''}$minutes:$seconds';
  }

  Future<void> _endCall() async {
    if (_isEnding) return;

    _isEnding = true;
    _stopCallSounds();
    _soundService.playCallDisconnect();

    try {
      if (_callId != null) {
        await _callService.endCall(_callId!);
      }
    } finally {
      _stopMedia();
      _stopCallTimer();
      if (mounted) Navigator.pop(context);
    }
  }

  void _stopMedia() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    _peerConnection?.close();
    _peerConnection = null;
  }

  String _connectionLabel(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'Connecting...';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return 'Connected';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'Connection failed';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'Call ended';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'Disconnected';
      default:
        return 'Connecting...';
    }
  }

  Future<void> _toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (e) {
      debugPrint('Speaker toggle error: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasRemoteVideo = widget.isVideo && _remoteRenderer.srcObject != null;

    return Scaffold(
      backgroundColor: const Color(0xFF070415),
      body: Stack(
        children: [
          // 1. Background (Live Video or Sci-Fi Quantum Hologram Canvas)
          if (hasRemoteVideo)
            Positioned.fill(
              child: _buildMorphedContainer(
                child: RTCVideoView(
                  _remoteRenderer,
                  mirror: false,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            )
          else
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_holoController, _pulseController, _waveController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SciFiCallRadarPainter(
                      holoProgress: _holoController.value,
                      pulseProgress: _pulseController.value,
                      waveProgress: _waveController.value,
                      isConnected: _isConnected,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [
                            const Color(0xFF1E0B3D).withValues(alpha: 0.85),
                            const Color(0xFF0D061E),
                            const Color(0xFF06030E),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 2. Center Hero Identity Hologram (When no video or voice call)
          if (!hasRemoteVideo)
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      // Animated Hologram Avatar with AR Lenses & Morphing Shapes
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulseController, _holoController]),
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Glowing Aura
                              Container(
                                width: 176,
                                height: 176,
                                decoration: BoxDecoration(
                                  shape: _selectedLens == 'hexagon' || _selectedLens == 'octagon' || _selectedLens == 'diamond'
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3 + (_pulseController.value * 0.35)),
                                      blurRadius: 32 + (_pulseController.value * 18),
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFB44FFF).withValues(alpha: 0.35),
                                      blurRadius: 50,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              // Morphed Shape Container
                              _buildMorphedContainer(
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  color: const Color(0xFF1B0C38),
                                  child: _remoteAvatarUrl != null && _remoteAvatarUrl!.isNotEmpty
                                      ? Image.network(_remoteAvatarUrl!, fit: BoxFit.cover)
                                      : Center(
                                          child: Text(
                                            widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'O',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 58,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              // AR Lens Overlay Layer
                              _buildARLensOverlay(170, 170),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      // Receiver Name with Neon Glow
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(color: Color(0xFF00E5FF), blurRadius: 18),
                            Shadow(color: Color(0xFFB44FFF), blurRadius: 30),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      // Live Status Pill with Security Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isConnected
                                ? [const Color(0xFF0F2D20), const Color(0xFF0A1B16)]
                                : [const Color(0xFF111B3A), const Color(0xFF0F1127)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isConnected ? const Color(0xFF00FF88).withValues(alpha: 0.7) : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected ? const Color(0xFF00FF88) : const Color(0xFF00E5FF)).withValues(alpha: 0.22),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isConnected ? Icons.lock_outline_rounded : Icons.sensors_rounded,
                              color: _isConnected ? const Color(0xFF00FF88) : const Color(0xFF00E5FF),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isConnected ? 'QUANTUM 256-BIT E2EE • LIVE' : _statusText.toUpperCase(),
                              style: TextStyle(
                                color: _isConnected ? const Color(0xFF00FF88) : const Color(0xFF00E5FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Live Audio Equalizer Waves
                      if (_isConnected)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) => _AudioEqualizerBars(pulse: _pulseController.value),
                        ),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Local Camera Floating Picture-in-Picture
          if (widget.isVideo && _localRenderer.srcObject != null)
            Positioned(
              right: 18,
              top: MediaQuery.of(context).padding.top + 70,
              width: 125,
              height: 185,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),

          // 4. Floating Reactions Layer
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: _floatingStickers.map((sticker) {
                  return _FloatingStickerWidget(
                    key: ValueKey(sticker.id),
                    data: sticker,
                  );
                }).toList(),
              ),
            ),
          ),

          // 5. Top Telemetry Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF110A23).withValues(alpha: 0.85),
                        const Color(0xFF1A1230).withValues(alpha: 0.92),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB44FFF).withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _endCall,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (_isConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E1145), Color(0xFF170A2B)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF2A6D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_callDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            widget.isVideo ? 'VIDEO SIGNAL' : 'VOICE SIGNAL',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.auto_awesome_rounded,
                          color: _showLensSheet ? const Color(0xFF00FF88) : const Color(0xFFB44FFF),
                          size: 24,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _showLensSheet = !_showLensSheet);
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: _showLensSheet ? const Color(0xFFB44FFF).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 6. Quick Reaction Toolbar (Floats above bottom dock)
          Positioned(
            left: 20,
            right: 20,
            bottom: _showLensSheet ? 195 : 105,
            child: SafeArea(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF14082B).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.3)),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _reactionPill(Icons.local_fire_department_rounded, 'fire', 'laser', const Color(0xFFFF5722)),
                    _reactionPill(Icons.bolt_rounded, 'bolt', 'magic', const Color(0xFFFFEB3B)),
                    _reactionPill(Icons.flight_takeoff_rounded, 'ufo', 'alien', const Color(0xFF00E5FF)),
                    _reactionPill(Icons.diamond_rounded, 'gem', 'star', const Color(0xFF00FF88)),
                    _reactionPill(Icons.gps_fixed_rounded, 'target', 'laser', const Color(0xFFFF2A6D)),
                    _reactionPill(Icons.rocket_launch_rounded, 'rocket', 'hyperspace', const Color(0xFFB44FFF)),
                    _reactionPill(Icons.favorite_rounded, 'heart', 'magic', const Color(0xFFFF4081)),
                    _reactionPill(Icons.smart_toy_rounded, 'robot', 'alien', const Color(0xFF64FFDA)),
                  ],
                ),
              ),
            ),
          ),

          // 7. AR Lens & Morphing Shapes Deck (When toggled open)
          if (_showLensSheet)
            Positioned(
              left: 16,
              right: 16,
              bottom: 105,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF160930).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'CYBER LENSES & MORPH SHAPES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => setState(() => _showLensSheet = false),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 72,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _lensOptionCard('none', 'Standard', Icons.visibility_rounded),
                            _lensOptionCard('google_lens', 'Google Lens', Icons.search_rounded),
                            _lensOptionCard('cyber_visor', 'Cyber Visor', Icons.remove_red_eye_rounded),
                            _lensOptionCard('terminator', 'T-800 Scan', Icons.smart_toy_rounded),
                            _lensOptionCard('matrix', 'Matrix Rain', Icons.terminal_rounded),
                            _lensOptionCard('neon_crown', 'Neon Crown', Icons.shield_rounded),
                            _lensOptionCard('hexagon', 'Hex Shield', Icons.hexagon_outlined),
                            _lensOptionCard('octagon', 'Warship Oct', Icons.stop_rounded),
                            _lensOptionCard('diamond', 'Crystal Diamond', Icons.diamond_rounded),
                            _lensOptionCard('cosmic', 'Cosmic Warp', Icons.blur_circular_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 8. Bottom Glassmorphic Cyber Control Dock
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF180A2D), Color(0xFF0E1831)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFB44FFF).withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB44FFF).withValues(alpha: 0.25),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 10)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute
                    _cyberDockButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: !_isMuted,
                      activeColor: const Color(0xFF00E5FF),
                      inactiveColor: const Color(0xFFFF2A6D),
                      onTap: _toggleMic,
                    ),
                    // Speakerphone Toggle
                    _cyberDockButton(
                      icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      isActive: _isSpeakerOn,
                      activeColor: const Color(0xFFB44FFF),
                      inactiveColor: Colors.white38,
                      onTap: _toggleSpeaker,
                    ),
                    // Video Toggle
                    if (widget.isVideo)
                      _cyberDockButton(
                        icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        isActive: _isVideoEnabled,
                        activeColor: const Color(0xFF00E5FF),
                        inactiveColor: const Color(0xFFFF2A6D),
                        onTap: _toggleVideo,
                      ),
                    // End Call (Crimson Red with Glow)
                    InkWell(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        _endCall();
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2A6D),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2A6D).withValues(alpha: 0.6),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionPill(IconData icon, String key, String sound, Color color) {
    return InkWell(
      onTap: () => _sendReaction(key, sound),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _lensOptionCard(String id, String label, IconData icon) {
    final isSelected = _selectedLens == id;
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _selectedLens = id);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: isSelected ? const Color(0xFF00E5FF) : Colors.white70),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorphedContainer({required Widget child}) {
    switch (_selectedLens) {
      case 'hexagon':
        return ClipPath(clipper: HexagonClipper(), child: child);
      case 'octagon':
        return ClipPath(clipper: OctagonClipper(), child: child);
      case 'diamond':
        return ClipPath(clipper: DiamondClipper(), child: child);
      default:
        return ClipOval(child: child);
    }
  }

  Widget _buildARLensOverlay(double width, double height) {
    switch (_selectedLens) {
      case 'google_lens':
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _GoogleLensOverlayPainter(
              pulse: _pulseController.value,
              holo: _holoController.value,
            ),
          ),
        );
      case 'cyber_visor':
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _CyberVisorPainter(pulse: _pulseController.value),
          ),
        );
      case 'terminator':
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _TerminatorHUDPainter(
              pulse: _pulseController.value,
              holo: _holoController.value,
            ),
          ),
        );
      case 'matrix':
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _MatrixStreamPainter(progress: _holoController.value),
          ),
        );
      case 'neon_crown':
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _NeonCrownPainter(pulse: _pulseController.value),
          ),
        );
      case 'cosmic':
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _CosmicWarpPainter(
              holo: _holoController.value,
              pulse: _pulseController.value,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _cyberDockButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? activeColor.withValues(alpha: 0.6) : Colors.white24,
            width: 1.4,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : inactiveColor,
          size: 24,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Custom Morphing Shape Clippers
// ---------------------------------------------------------
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    const c = 0.28;
    path.moveTo(w * c, 0);
    path.lineTo(w * (1 - c), 0);
    path.lineTo(w, h * c);
    path.lineTo(w, h * (1 - c));
    path.lineTo(w * (1 - c), h);
    path.lineTo(w * c, h);
    path.lineTo(0, h * (1 - c));
    path.lineTo(0, h * c);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.5);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------
// AR Overlays Custom Painters
// ---------------------------------------------------------
class _GoogleLensOverlayPainter extends CustomPainter {
  final double pulse;
  final double holo;
  _GoogleLensOverlayPainter({required this.pulse, required this.holo});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const cornerLen = 22.0;
    // Top-Left bracket
    canvas.drawLine(const Offset(8, 8), const Offset(8 + cornerLen, 8), paint);
    canvas.drawLine(const Offset(8, 8), const Offset(8, 8 + cornerLen), paint);
    // Top-Right bracket
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8 - cornerLen, 8), paint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8, 8 + cornerLen), paint);
    // Bottom-Left bracket
    canvas.drawLine(Offset(8, size.height - 8), Offset(8 + cornerLen, size.height - 8), paint);
    canvas.drawLine(Offset(8, size.height - 8), Offset(8, size.height - 8 - cornerLen), paint);
    // Bottom-Right bracket
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8 - cornerLen, size.height - 8), paint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8, size.height - 8 - cornerLen), paint);

    // Center Crosshair Reticle
    final center = Offset(size.width / 2, size.height / 2);
    final reticlePaint = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 24 + (pulse * 8), reticlePaint);
    canvas.drawLine(Offset(center.dx - 12, center.dy), Offset(center.dx + 12, center.dy), reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy - 12), Offset(center.dx, center.dy + 12), reticlePaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleLensOverlayPainter oldDelegate) => true;
}

class _CyberVisorPainter extends CustomPainter {
  final double pulse;
  _CyberVisorPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final visorPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.42),
        width: size.width * 0.72,
        height: 28,
      ),
      const Radius.circular(14),
    );

    canvas.drawRRect(visorRect, glowPaint);
    canvas.drawRRect(visorRect, visorPaint);

    // Light reflection streak
    final streakPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0;

    final startX = size.width * (0.25 + (pulse * 0.4));
    canvas.drawLine(Offset(startX, size.height * 0.4), Offset(startX + 20, size.height * 0.4), streakPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberVisorPainter oldDelegate) => true;
}

class _TerminatorHUDPainter extends CustomPainter {
  final double pulse;
  final double holo;
  _TerminatorHUDPainter({required this.pulse, required this.holo});

  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()
      ..color = const Color(0xFFFF2A6D).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final rightEyeCenter = Offset(size.width * 0.65, size.height * 0.42);
    canvas.drawCircle(rightEyeCenter, 16 + (pulse * 6), redPaint);

    final glowEye = Paint()
      ..color = const Color(0xFFFF2A6D).withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(rightEyeCenter, 6, glowEye);

    // Scan line
    final scanY = size.height * (holo % 1.0);
    final linePaint = Paint()
      ..color = const Color(0xFFFF2A6D).withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), linePaint);
  }

  @override
  bool shouldRepaint(covariant _TerminatorHUDPainter oldDelegate) => true;
}

class _MatrixStreamPainter extends CustomPainter {
  final double progress;
  _MatrixStreamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const glyphs = ['1', '0', 'X', '7', 'N', 'E', 'X', '9'];

    for (int col = 0; col < 6; col++) {
      final x = (size.width / 6) * col + 12;
      for (int row = 0; row < 5; row++) {
        final y = ((row * 30.0) + (progress * size.height)) % size.height;
        final glyph = glyphs[(col + row) % glyphs.length];

        textPainter.text = TextSpan(
          text: glyph,
          style: TextStyle(
            color: const Color(0xFF00FF88).withValues(alpha: (1.0 - (row * 0.18)).clamp(0.2, 0.9)),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixStreamPainter oldDelegate) => true;
}

class _NeonCrownPainter extends CustomPainter {
  final double pulse;
  _NeonCrownPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final crownPath = Path();
    final cx = size.width * 0.5;
    final cy = size.height * 0.08 - (pulse * 6);

    crownPath.moveTo(cx - 36, cy + 12);
    crownPath.lineTo(cx - 42, cy - 14);
    crownPath.lineTo(cx - 16, cy);
    crownPath.lineTo(cx, cy - 22);
    crownPath.lineTo(cx + 16, cy);
    crownPath.lineTo(cx + 42, cy - 14);
    crownPath.lineTo(cx + 36, cy + 12);
    crownPath.close();

    final crownGlow = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(crownPath, crownGlow);

    final crownPaint = Paint()
      ..color = const Color(0xFFFFE043)
      ..style = PaintingStyle.fill;
    canvas.drawPath(crownPath, crownPaint);
  }

  @override
  bool shouldRepaint(covariant _NeonCrownPainter oldDelegate) => true;
}

class _CosmicWarpPainter extends CustomPainter {
  final double holo;
  final double pulse;
  _CosmicWarpPainter({required this.holo, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final ringPaint = Paint()
      ..color = const Color(0xFFB44FFF).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(holo * 2 * 3.14159);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size.width * 1.15, height: size.height * 0.4), ringPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CosmicWarpPainter oldDelegate) => true;
}

// ---------------------------------------------------------
// Floating Live Burst Sticker Widget & Model
// ---------------------------------------------------------
class _FloatingStickerData {
  final String id;
  final String emoji;
  final double startX;

  _FloatingStickerData({
    required this.id,
    required this.emoji,
    required this.startX,
  });

  static IconData getReactionIcon(String key) {
    switch (key) {
      case 'fire':
      case 'laser':
        return Icons.local_fire_department_rounded;
      case 'bolt':
      case 'magic':
        return Icons.bolt_rounded;
      case 'alien':
      case 'ufo':
        return Icons.flight_takeoff_rounded;
      case 'star':
      case 'gem':
        return Icons.diamond_rounded;
      case 'target':
        return Icons.gps_fixed_rounded;
      case 'rocket':
      case 'hyperspace':
        return Icons.rocket_launch_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'robot':
        return Icons.smart_toy_rounded;
      default:
        return Icons.thumb_up_rounded;
    }
  }
}

class _FloatingStickerWidget extends StatefulWidget {
  final _FloatingStickerData data;
  const _FloatingStickerWidget({super.key, required this.data});

  @override
  State<_FloatingStickerWidget> createState() => _FloatingStickerWidgetState();
}

class _FloatingStickerWidgetState extends State<_FloatingStickerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        final y = screenHeight * (0.85 - (progress * 0.65));
        final x = (screenWidth * widget.data.startX) + (sin(progress * 6 * 3.14159) * 20);
        final opacity = (1.0 - (progress * 0.8)).clamp(0.0, 1.0);
        final scale = 0.8 + (sin(progress * 3.14159) * 0.6);

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4 * opacity),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _FloatingStickerData.getReactionIcon(widget.data.emoji),
                  color: const Color(0xFF00E5FF),
                  size: 34,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// Custom Sci-Fi Holographic Radar Painter
// ---------------------------------------------------------
class _SciFiCallRadarPainter extends CustomPainter {
  final double holoProgress;
  final double pulseProgress;
  final double waveProgress;
  final bool isConnected;

  _SciFiCallRadarPainter({
    required this.holoProgress,
    required this.pulseProgress,
    required this.waveProgress,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);

    // 1. Expanding Sonar Rings
    for (int i = 0; i < 3; i++) {
      final ringWave = (waveProgress + (i * 0.33)) % 1.0;
      final radius = 90.0 + (ringWave * 140.0);
      final opacity = (1.0 - ringWave).clamp(0.0, 1.0) * (isConnected ? 0.3 : 0.5);

      final wavePaint = Paint()
        ..color = (isConnected ? const Color(0xFF00FF88) : const Color(0xFF00E5FF)).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawCircle(center, radius, wavePaint);
    }

    // 2. Rotating Segmented Quantum Arc Ring
    const ringRadius = 115.0;
    final angleOffset = holoProgress * 2 * 3.14159;

    final arcPaint = Paint()
      ..color = const Color(0xFFB44FFF).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int j = 0; j < 4; j++) {
      final startAngle = angleOffset + (j * (3.14159 / 2)) + 0.15;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startAngle,
        0.8,
        false,
        arcPaint,
      );
    }

    // 3. Counter-Rotating Outer Orbit Ring with glowing nodes
    const outerRingRadius = 145.0;
    final counterAngle = -holoProgress * 2 * 3.14159;

    final outerPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, outerRingRadius, outerPaint);

    final nodePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    for (int k = 0; k < 6; k++) {
      final nodeAngle = counterAngle + (k * (3.14159 / 3));
      final nodeX = center.dx + (outerRingRadius * cos(nodeAngle));
      final nodeY = center.dy + (outerRingRadius * sin(nodeAngle));
      canvas.drawCircle(Offset(nodeX, nodeY), 3.0, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SciFiCallRadarPainter oldDelegate) => true;
}

// ---------------------------------------------------------
// Live Audio Equalizer Bars Widget
// ---------------------------------------------------------
class _AudioEqualizerBars extends StatelessWidget {
  final double pulse;
  const _AudioEqualizerBars({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const barCount = 11;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(barCount, (index) {
        final factor = (sin((pulse * 3.14159 * 2) + (index * 0.6)).abs() * 0.7) + 0.3;
        final height = 8.0 + (factor * 26.0);

        return Container(
          width: 3.5,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xFF00E5FF),
                Color(0xFFB44FFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        );
      }),
    );
  }
}
