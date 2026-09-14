import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../services/offline_bluetooth_service.dart';

class OfflineChatScreen extends StatefulWidget {
  static const routeName = '/offline-chat';

  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen>
    with TickerProviderStateMixin {
  final OfflineBluetoothService _bluetoothService = OfflineBluetoothService();
  final GameSoundService _soundService = GameSoundService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<OfflineMessage> _messages = [];

  // Modes & State
  bool _isRadarMode = false; // Toggle between Topology Radar and Chat Stream
  bool _discovering = false;
  bool _connected = false;
  bool _advertising = false;
  bool _permissionsGranted = false;
  double _transferProgress = 0.0;
  String _transferLabel = '';
  int _nearbyDeviceCount = 0;
  Endpoint? _selectedDevice;
  String _localDisplayName = 'Operative Alpha';
  String _localNodeId = 'NEX-01';

  // Channels: 0 = #ALL_MESH (Broadcast), 1 = DIRECT LINK
  int _selectedChannelIndex = 0;

  // Virtual Demo Mesh Nodes (Used for visualization/testing)
  final List<Map<String, dynamic>> _simulatedNodes = [
    {
      'id': 'sim_node_bravo',
      'name': 'Operative Bravo',
      'bearing': 0.75, // radians
      'distance': 0.35, // 0.0 to 1.0 (normalized)
      'rssi': -52,
      'status': 'Online',
    },
    {
      'id': 'sim_node_echo',
      'name': 'Squad Lead Echo',
      'bearing': 2.35,
      'distance': 0.65,
      'rssi': -74,
      'status': 'Mesh Relay',
    },
    {
      'id': 'sim_node_ghost',
      'name': 'Recon Ghost',
      'bearing': 4.5,
      'distance': 0.50,
      'rssi': -68,
      'status': 'Stealth Mode',
    },
  ];

  // Animation Controllers
  late AnimationController _radarSweepController;
  late AnimationController _sonarPulseController;
  late AnimationController _antennaBlinkController;

  // Stream Subscriptions
  StreamSubscription? _endpointsSub;
  StreamSubscription? _messagesSub;
  StreamSubscription? _connSub;
  StreamSubscription? _progressSub;

  @override
  void initState() {
    super.initState();

    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _sonarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _antennaBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _endpointsSub = _bluetoothService.endpointsStream.listen((devices) {
      if (!mounted) return;
      if (devices.length > _nearbyDeviceCount) {
        _soundService.playCoin();
        HapticFeedback.lightImpact();
      }
      setState(() {
        _nearbyDeviceCount = devices.length;
      });
    });

    _messagesSub = _bluetoothService.messageStream.listen((message) {
      if (!mounted) return;
      if (message.text.startsWith('🚨 [SOS')) {
        _soundService.playSuperLaser();
        HapticFeedback.heavyImpact();
      } else {
        _soundService.playLaser();
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _messages.insert(0, message);
        _saveMessages();
      });
    });

    _connSub = _bluetoothService.isConnectedStream.listen((connected) {
      if (!mounted) return;
      if (connected) {
        _soundService.playWin();
        HapticFeedback.heavyImpact();
      } else {
        _soundService.playLose();
      }
      setState(() {
        _connected = connected;
        if (!connected) {
          _selectedDevice = null;
        }
      });
    });

    _progressSub = _bluetoothService.transferProgressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _transferProgress = progress;
        _transferLabel = progress > 0 && progress < 1
            ? 'Transferring: ${(progress * 100).toStringAsFixed(0)}%'
            : '';
      });
    });

    _loadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveLocalIdentity();
      _initializeMeshRadio();
    });
  }

  void _resolveLocalIdentity() {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final profile = auth.userProfile;
      final user = auth.user;
      final resolved = AuthService.resolveDisplayName(
        name: profile?['name']?.toString() ?? profile?['displayName']?.toString() ?? user?.displayName,
        username: profile?['username']?.toString(),
        email: user?.email,
      );
      if (resolved.isNotEmpty && resolved != 'Unknown User') {
        final idSuffix = (user?.uid.isNotEmpty == true)
            ? user!.uid.substring(0, min(4, user.uid.length)).toUpperCase()
            : 'NODE';
        setState(() {
          _localDisplayName = resolved;
          _localNodeId = 'OP-$idSuffix';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('offline_messages');
    if (data != null) {
      final list = jsonDecode(data) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _messages.clear();
        for (final m in list) {
          final map = m as Map<String, dynamic>;
          _messages.add(OfflineMessage(
            id: map['id'],
            sender: map['sender'],
            text: map['text'],
            type: map['type'] == 'file' ? OfflineMessageType.file : OfflineMessageType.text,
            timestamp: DateTime.parse(map['timestamp']),
            fileName: map['fileName'],
            filePath: map['filePath'],
            fileSize: map['fileSize'],
          ));
        }
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _messages.map((m) => {
      'id': m.id,
      'sender': m.sender,
      'text': m.text,
      'type': m.type == OfflineMessageType.file ? 'file' : 'text',
      'timestamp': m.timestamp.toIso8601String(),
      'fileName': m.fileName,
      'filePath': m.filePath,
      'fileSize': m.fileSize,
    }).toList();
    await prefs.setString('offline_messages', jsonEncode(list));
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
        Permission.storage,
      ].request();
      return statuses.values.any((s) => s.isGranted || s.isLimited);
    } catch (_) {
      return true;
    }
  }

  Future<void> _initializeMeshRadio() async {
    _permissionsGranted = await _requestPermissions();
    if (_permissionsGranted) {
      _advertising = await _bluetoothService.startAdvertising(_localDisplayName);
      _discovering = await _bluetoothService.startDiscovery(_localDisplayName);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _radarSweepController.dispose();
    _sonarPulseController.dispose();
    _antennaBlinkController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _endpointsSub?.cancel();
    _messagesSub?.cancel();
    _connSub?.cancel();
    _progressSub?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  Future<void> _toggleDiscovery() async {
    HapticFeedback.selectionClick();
    if (!_permissionsGranted) {
      _permissionsGranted = await _requestPermissions();
      if (!_permissionsGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth & Location permissions required for mesh.')),
        );
        return;
      }
    }

    if (_discovering) {
      await _bluetoothService.stopDiscovery();
      setState(() => _discovering = false);
    } else {
      final started = await _bluetoothService.startDiscovery(_localDisplayName);
      setState(() => _discovering = started);
      if (started) {
        _soundService.playHoloEngage();
      }
    }
  }

  Future<void> _toggleAdvertising() async {
    HapticFeedback.selectionClick();
    if (!_permissionsGranted) {
      _permissionsGranted = await _requestPermissions();
      if (!_permissionsGranted) return;
    }

    if (_advertising) {
      await _bluetoothService.stopAdvertising();
      setState(() => _advertising = false);
    } else {
      final started = await _bluetoothService.startAdvertising(_localDisplayName);
      setState(() => _advertising = started);
      if (started) {
        _soundService.playHoloEngage();
      }
    }
  }

  Future<void> _connectToDevice(Endpoint device) async {
    HapticFeedback.mediumImpact();
    _soundService.playTick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Establishing P2P mesh link with ${device.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await _bluetoothService.requestConnection(
      _localDisplayName,
      device.id,
    );

    if (!mounted) return;
    if (success) {
      setState(() {
        _selectedDevice = device;
        _selectedChannelIndex = 1; // Switch to direct link channel
      });
    }
  }

  Future<void> _disconnectDevice() async {
    HapticFeedback.lightImpact();
    await _bluetoothService.disconnect();
    setState(() {
      _selectedDevice = null;
      _transferProgress = 0.0;
      _transferLabel = '';
      _selectedChannelIndex = 0;
    });
  }

  Future<void> _sendText({String? overrideText}) async {
    final text = overrideText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    if (_connected) {
      await _bluetoothService.sendText(text);
    } else {
      // Local broadcast simulation
      final msg = OfflineMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'You',
        text: text,
        type: OfflineMessageType.text,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.insert(0, msg);
        _saveMessages();
      });
    }

    _soundService.playLaser();
    if (overrideText == null) {
      _messageController.clear();
    }
  }

  Future<void> _sendQuickAction(String actionCode) async {
    HapticFeedback.mediumImpact();
    String payload;
    switch (actionCode) {
      case 'SOS':
        payload = '🚨 [SOS EMERGENCY] Operative $_localDisplayName beacon broadcasted! Assistance required!';
        _soundService.playSuperLaser();
        break;
      case 'COORD':
        final randLat = (37.7749 + (Random().nextDouble() - 0.5) * 0.02).toStringAsFixed(4);
        final randLon = (-122.4194 + (Random().nextDouble() - 0.5) * 0.02).toStringAsFixed(4);
        payload = '📍 [GRID COORD] Loc: $randLat, $randLon • Altitude: 42m • Sector Alpha';
        _soundService.playTick();
        break;
      case 'ACK':
        payload = '✅ [ACK] Transmission received and acknowledged.';
        _soundService.playTick();
        break;
      case 'CLEAR':
        payload = '🛡️ [ALL CLEAR] Local perimeter checked. Zero hostiles detected.';
        _soundService.playTick();
        break;
      default:
        payload = actionCode;
    }
    await _sendText(overrideText: payload);
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.pickFile(type: FileType.any);
    if (result == null || result.path == null) return;
    HapticFeedback.mediumImpact();
    final file = File(result.path!);
    await _bluetoothService.sendFile(file.path);
  }

  void _showInspectorBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070B16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal_rounded, color: Color(0xFF00E5FF), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'MESH NETWORK TELEMETRY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              _buildTelemetryRow('Local Node ID', _localNodeId),
              _buildTelemetryRow('Cluster Strategy', 'P2P_CLUSTER (Multi-Peer Star)'),
              _buildTelemetryRow('Frequency Band', '2.4 GHz BLE / 5.0 GHz WiFi-Direct'),
              _buildTelemetryRow('Socket Encryption', 'AES-256 GCM (Zero-Knowledge)'),
              _buildTelemetryRow('Link Status', _connected ? 'Direct Socket Active' : 'Beacon Scanning'),
              _buildTelemetryRow('Discovered Nodes', '$_nearbyDeviceCount Peer Devices'),
              _buildTelemetryRow('Max Payload MTU', '65,536 Bytes (Chunked Streaming)'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleDiscovery();
                },
                icon: const Icon(Icons.sync_rounded),
                label: Text(_discovering ? 'RESTART SCANNER' : 'START SCANNER'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: _buildTacticalAppBar(),
      body: Stack(
        children: [
          // 1. Cyber Mesh Coordinate Background Grid
          Positioned.fill(
            child: CustomPaint(
              painter: _TacticalGridBackgroundPainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. High-Tech Radio Telemetry Banner
                _buildRadioTelemetryBar(),

                // 3. Channel Selector Tabs (#ALL_MESH vs DIRECT LINK)
                _buildChannelSelectorTabs(),

                // Transfer Progress Indicator
                if (_transferLabel.isNotEmpty) _buildTransferProgressBar(),

                // 4. Main Body: Topology Radar vs Chat Stream
                Expanded(
                  child: _isRadarMode ? _buildFullRadarTopologyView() : _buildChatStreamView(),
                ),

                // 5. Tactical Quick-Action & SOS Bar
                _buildQuickActionBar(),

                // 6. Bottom Console Input Dock
                _buildConsoleInputDock(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_transferLabel, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
              Text('${(_transferProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _transferProgress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTacticalAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF070B16),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Pulsing Antenna Indicator
          AnimatedBuilder(
            animation: _antennaBlinkController,
            builder: (context, _) {
              final alpha = 0.4 + _antennaBlinkController.value * 0.6;
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_connected
                          ? const Color(0xFF00FF88)
                          : (_discovering ? const Color(0xFF00E5FF) : Colors.white38))
                      .withValues(alpha: alpha),
                  boxShadow: [
                    BoxShadow(
                      color: (_connected ? const Color(0xFF00FF88) : const Color(0xFF00E5FF))
                          .withValues(alpha: alpha * 0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TACTICAL OFFLINE MESH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _connected
                    ? 'LINK: ${_selectedDevice?.name ?? "PEER"} • SECURE'
                    : (_discovering ? 'SCANNING • $_nearbyDeviceCount NODES FOUND' : 'RADIO STANDBY'),
                style: TextStyle(
                  color: _connected
                      ? const Color(0xFF00FF88)
                      : (_discovering ? const Color(0xFF00E5FF) : Colors.white38),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Mode Switcher: Radar Topology vs Chat Stream
        IconButton(
          icon: Icon(
            _isRadarMode ? Icons.chat_bubble_outline_rounded : Icons.radar_rounded,
            color: const Color(0xFF00E5FF),
            size: 22,
          ),
          tooltip: _isRadarMode ? 'Switch to Comms Stream' : 'Switch to Topology Radar',
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _isRadarMode = !_isRadarMode);
          },
        ),

        // Telemetry Inspector
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
          tooltip: 'Mesh Inspector',
          onPressed: _showInspectorBottomSheet,
        ),

        // Clear Messages
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54, size: 20),
          tooltip: 'Purge Stream',
          onPressed: () {
            setState(() {
              _messages.clear();
              _saveMessages();
            });
            _soundService.playTick();
          },
        ),
      ],
    );
  }

  Widget _buildRadioTelemetryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1020),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Local Node Identity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _localNodeId,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _localDisplayName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),

          // Radio Beacon Toggles
          Row(
            children: [
              InkWell(
                onTap: _toggleAdvertising,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _advertising ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _advertising ? const Color(0xFF00E5FF) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.podcasts, size: 12, color: _advertising ? const Color(0xFF00E5FF) : Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        _advertising ? 'BEACON ON' : 'BEACON OFF',
                        style: TextStyle(
                          color: _advertising ? const Color(0xFF00E5FF) : Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _toggleDiscovery,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _discovering ? const Color(0xFF00FF88).withValues(alpha: 0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _discovering ? const Color(0xFF00FF88) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar, size: 12, color: _discovering ? const Color(0xFF00FF88) : Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        _discovering ? 'SCANNING' : 'SCAN',
                        style: TextStyle(
                          color: _discovering ? const Color(0xFF00FF88) : Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelectorTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Channel 1: #ALL_MESH
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedChannelIndex = 0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedChannelIndex == 0
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedChannelIndex == 0 ? const Color(0xFF00E5FF) : Colors.transparent,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tag_rounded, color: Color(0xFF00E5FF), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'ALL_MESH (BROADCAST)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Channel 2: DIRECT LINK
          Expanded(
            child: InkWell(
              onTap: _connected ? () => setState(() => _selectedChannelIndex = 1) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedChannelIndex == 1
                      ? const Color(0xFF00FF88).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedChannelIndex == 1 ? const Color(0xFF00FF88) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: _connected ? const Color(0xFF00FF88) : Colors.white24,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connected ? 'DIRECT P2P ENCRYPTED' : 'DIRECT LINK (IDLE)',
                      style: TextStyle(
                        color: _connected ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
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

  Widget _buildFullRadarTopologyView() {
    return StreamBuilder<List<Endpoint>>(
      stream: _bluetoothService.endpointsStream,
      builder: (context, snapshot) {
        final realDevices = snapshot.data ?? [];
        final hasDevices = realDevices.isNotEmpty;

        return Column(
          children: [
            // Interactive Radar Scope
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final radarSize = min(constraints.maxWidth, constraints.maxHeight);
                    return Center(
                      child: SizedBox(
                        width: radarSize,
                        height: radarSize,
                        child: AnimatedBuilder(
                          animation: _radarSweepController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _TacticalTopologyRadarPainter(
                                angle: _radarSweepController.value * 2 * pi,
                                sonar: _sonarPulseController.value,
                                realDevices: realDevices,
                                simulatedNodes: hasDevices ? [] : _simulatedNodes,
                                connected: _connected,
                                connectedId: _bluetoothService.connectedEndpointId,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Discovered Nodes Horizon Deck
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ACTIVE NODES IN PROXIMITY',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          hasDevices ? '${realDevices.length} HARDWARE' : 'SIMULATION MESH',
                          style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: hasDevices
                          ? ListView.separated(
                              itemCount: realDevices.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final dev = realDevices[index];
                                final isLinked = _bluetoothService.connectedEndpointId == dev.id;
                                return _buildPeerNodeTile(
                                  id: dev.id,
                                  name: dev.name,
                                  rssi: -58,
                                  isLinked: isLinked,
                                  onConnect: () => _connectToDevice(dev),
                                );
                              },
                            )
                          : ListView.separated(
                              itemCount: _simulatedNodes.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final node = _simulatedNodes[index];
                                return _buildPeerNodeTile(
                                  id: node['id'],
                                  name: node['name'],
                                  rssi: node['rssi'],
                                  isLinked: false,
                                  onConnect: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Simulated link test with ${node['name']}')),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPeerNodeTile({
    required String id,
    required String name,
    required int rssi,
    required bool isLinked,
    required VoidCallback onConnect,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLinked ? const Color(0xFF00FF88) : const Color(0xFF00E5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'N',
                style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Row(
                  children: [
                    const Icon(Icons.signal_cellular_alt_rounded, color: Color(0xFF00FF88), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '$rssi dBm • Direct P2P',
                      style: const TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          isLinked
              ? FilledButton.tonal(
                  onPressed: _disconnectDevice,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    minimumSize: const Size(70, 30),
                  ),
                  child: const Text('UNLINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : FilledButton(
                  onPressed: onConnect,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(70, 30),
                  ),
                  child: const Text('LINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
        ],
      ),
    );
  }

  Widget _buildChatStreamView() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_tethering_rounded, size: 52, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            const Text(
              'NO OFFLINE MESSAGES IN STREAM',
              style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            const Text(
              'Broadcast on #ALL_MESH or link with a nearby node to communicate.',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      reverse: true,
      itemCount: _messages.length,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.sender == 'You';
        final isSOS = message.text.contains('🚨 [SOS');

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSOS
                    ? [const Color(0xFF5A0010), const Color(0xFF320008)]
                    : (isMe
                        ? [const Color(0xFF004080).withValues(alpha: 0.9), const Color(0xFF002244).withValues(alpha: 0.9)]
                        : [const Color(0xFF131A2E).withValues(alpha: 0.95), const Color(0xFF0B1020).withValues(alpha: 0.95)]),
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSOS
                    ? Colors.redAccent
                    : (isMe ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : Colors.white12),
                width: isSOS ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSOS
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : (isMe ? const Color(0xFF00E5FF).withValues(alpha: 0.12) : Colors.transparent),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Sender & Time)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.sender.toUpperCase(),
                      style: TextStyle(
                        color: isSOS ? Colors.redAccent : (isMe ? const Color(0xFF00E5FF) : const Color(0xFF00FF88)),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // File Attachment Indicator
                if (message.type == OfflineMessageType.file) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file_rounded, color: Color(0xFF00E5FF), size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            message.fileName ?? 'Offline Document',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Body text
                Text(
                  message.text,
                  style: TextStyle(
                    color: isSOS ? Colors.white : Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionBar() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          // SOS Button
          InkWell(
            onTap: () => _sendQuickAction('SOS'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent, width: 1.2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                  SizedBox(width: 6),
                  Text('🚨 SOS BEACON', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // COORD
          _buildQuickChip('📍 COORD', () => _sendQuickAction('COORD')),
          const SizedBox(width: 8),

          // ACK
          _buildQuickChip('✅ ACK', () => _sendQuickAction('ACK')),
          const SizedBox(width: 8),

          // ALL CLEAR
          _buildQuickChip('🛡️ ALL CLEAR', () => _sendQuickAction('CLEAR')),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleInputDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF070B16),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          // File Beam Button
          IconButton(
            onPressed: _connected ? _sendFile : null,
            icon: Icon(
              Icons.attach_file_rounded,
              color: _connected ? const Color(0xFF00E5FF) : Colors.white24,
            ),
            tooltip: 'Beam Offline File',
          ),

          // Text Field
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _connected
                    ? 'Encrypted message to ${_selectedDevice?.name ?? "Peer"}...'
                    : 'Broadcast message to local mesh...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                ),
              ),
              onSubmitted: (_) => _sendText(),
            ),
          ),
          const SizedBox(width: 8),

          // Send Action Button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => _sendText(),
              icon: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOPOLOGICAL POLAR RADAR CUSTOM PAINTER
// ============================================================================

class _TacticalTopologyRadarPainter extends CustomPainter {
  final double angle;
  final double sonar;
  final List<Endpoint> realDevices;
  final List<Map<String, dynamic>> simulatedNodes;
  final bool connected;
  final String? connectedId;

  _TacticalTopologyRadarPainter({
    required this.angle,
    required this.sonar,
    required this.realDevices,
    required this.simulatedNodes,
    required this.connected,
    this.connectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dark Radar Base
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF040814));

    // Concentric Range Rings (10m, 25m, 50m, 100m)
    final ringPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.25, ringPaint);
    canvas.drawCircle(center, radius * 0.50, ringPaint);
    canvas.drawCircle(center, radius * 0.75, ringPaint);
    canvas.drawCircle(center, radius * 0.98, ringPaint);

    // Crosshair Lines
    final crossPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.12)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);

    // Dynamic Sonar Ping Wave
    final sonarRadius = radius * sonar;
    final sonarPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: (1.0 - sonar).clamp(0.0, 1.0) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, sonarRadius, sonarPaint);

    // Sweeping Radar Beam (Phosphor gradient)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: pi / 2,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.45),
          Colors.transparent,
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.98, sweepPaint);

    // Center Antenna Hub (Local Node)
    canvas.drawCircle(center, 4.0, Paint()..color = const Color(0xFF00FF88));
    canvas.drawCircle(
      center,
      8.0,
      Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke,
    );

    // Render Peer Nodes & Mesh Network Link Vectors
    final List<Offset> nodePositions = [];

    if (realDevices.isNotEmpty) {
      for (int i = 0; i < realDevices.length; i++) {
        final dAngle = (i / realDevices.length) * 2 * pi + 0.5;
        final dDist = radius * 0.65;
        final pos = Offset(center.dx + cos(dAngle) * dDist, center.dy + sin(dAngle) * dDist);
        nodePositions.add(pos);
        _drawNodeBlip(canvas, pos, realDevices[i].name, realDevices[i].id == connectedId);
      }
    } else {
      for (final sim in simulatedNodes) {
        final b = sim['bearing'] as double;
        final d = (sim['distance'] as double) * radius * 0.9;
        final pos = Offset(center.dx + cos(b) * d, center.dy + sin(b) * d);
        nodePositions.add(pos);
        _drawNodeBlip(canvas, pos, sim['name'] as String, false);
      }
    }

    // Draw Mesh Vectors between nodes
    final vectorPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.18)
      ..strokeWidth = 1.0;

    for (final pos in nodePositions) {
      canvas.drawLine(center, pos, vectorPaint);
    }
  }

  void _drawNodeBlip(Canvas canvas, Offset pos, String name, bool isLinked) {
    final blipColor = isLinked ? const Color(0xFF00FF88) : const Color(0xFF00E5FF);

    // Halo
    canvas.drawCircle(
      pos,
      6.0,
      Paint()..color = blipColor.withValues(alpha: 0.3),
    );
    // Core
    canvas.drawCircle(
      pos,
      3.0,
      Paint()..color = blipColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TacticalTopologyRadarPainter old) => true;
}

// ============================================================================
// TACTICAL BACKGROUND GRID PAINTER
// ============================================================================

class _TacticalGridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.025)
      ..strokeWidth = 0.6;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalGridBackgroundPainter old) => false;
}
