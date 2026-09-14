import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/about_developers_screen.dart';
import '../utils/constants.dart';

class AutoTrackerScreen extends StatefulWidget {
  static const routeName = '/auto-tracker';
  const AutoTrackerScreen({super.key});

  @override
  State<AutoTrackerScreen> createState() => _AutoTrackerScreenState();
}

class _AutoTrackerScreenState extends State<AutoTrackerScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _useFrontCamera = false;
  bool _isTracking = true;
  bool _permissionDenied = false;
  bool _initializationFailed = false;
  bool _isProcessing = false;
  String _statusMessage = 'Initializing targeting system...';
  List<_DetectionResult> _detections = [];
  bool _devPanelExpanded = false;

  // Vision modes
  int _visionMode = 0; // 0=NORMAL, 1=THERMAL, 2=NIGHT, 3=EDGE, 4=MATRIX
  static const _visionModes = ['NORMAL', 'THERMAL', 'NIGHT-VIS', 'EDGE-DET', 'MATRIX'];
  static const _visionIcons = [
    Icons.visibility_rounded,
    Icons.local_fire_department_rounded,
    Icons.nightlight_rounded,
    Icons.blur_on_rounded,
    Icons.grid_on_rounded,
  ];
  static const _visionColors = [
    Colors.white,
    Colors.deepOrange,
    Colors.greenAccent,
    Colors.white,
    Colors.green,
  ];

  // ML Kit
  late ObjectDetector _objectDetector;

  // Animations
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnim;

  // FPS tracking
  int _frameCount = 0;
  int _fps = 0;
  Timer? _fpsTimer;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);

    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _fps = _frameCount;
          _frameCount = 0;
        });
      }
    });

    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _objectDetector.close();
    _radarController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    _fpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializationFailed = true;
            _statusMessage = 'NO IMAGING SENSORS DETECTED';
          });
        }
        return;
      }

      final description = _useFrontCamera && _availableCameras.length > 1
          ? _availableCameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _availableCameras.first)
          : _availableCameras.first;

      _cameraController = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      await _cameraController!.startImageStream(_processImage);
      setState(() => _statusMessage = 'TARGETING SYSTEM ONLINE');
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('permission') ||
              e.toString().contains('Permission')) {
            _permissionDenied = true;
            _statusMessage = 'CAMERA ACCESS DENIED';
          } else {
            _initializationFailed = true;
            _statusMessage = 'SENSOR INIT FAILED: $e';
          }
        });
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (!_isTracking || _isProcessing) return;
    _isProcessing = true;
    _frameCount++;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final objects = await _objectDetector.processImage(inputImage);
      if (!mounted) return;

      setState(() {
        _detections = objects.map((obj) {
          final label = obj.labels.isNotEmpty
              ? _normalizeLabel(obj.labels.first.text)
              : 'Unknown';
          final confidence =
              obj.labels.isNotEmpty ? obj.labels.first.confidence : 0.0;
          return _DetectionResult(
            label: label,
            confidence: confidence,
            boundingBox: obj.boundingBox,
            trackingId: obj.trackingId,
          );
        }).toList();

        _statusMessage = _detections.isEmpty
            ? 'SCANNING... NO TARGETS'
            : '${_detections.length} TARGET${_detections.length > 1 ? 'S' : ''} ACQUIRED';
      });
    } catch (_) {
      // silently skip frame errors
    }
    _isProcessing = false;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final allBytes = image.planes.fold<List<int>>(
        [], (prev, plane) => prev..addAll(plane.bytes));
    final bytes = Uint8List.fromList(allBytes);
    final description = _cameraController!.description;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final rotation =
        _rotationIntToImageRotation(description.sensorOrientation);
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;
    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  String _normalizeLabel(String rawLabel) {
    final label = rawLabel.toLowerCase();
    if (label.contains('person') || label.contains('human')) return 'HUMAN';
    if (label.contains('bicycle') || label.contains('bike')) return 'BIKE';
    if (label.contains('car') ||
        label.contains('truck') ||
        label.contains('vehicle') ||
        label.contains('bus') ||
        label.contains('train')) {
      return 'VEHICLE';
    }
    if (label.contains('motorcycle') || label.contains('scooter')) {
      return 'MOTORBIKE';
    }
    if (label.contains('building') ||
        label.contains('architecture') ||
        label.contains('structure')) {
      return 'STRUCTURE';
    }
    return rawLabel.isNotEmpty ? rawLabel.toUpperCase() : 'OBJECT';
  }

  String _threatLevel(String label) {
    switch (label) {
      case 'HUMAN':
        return 'MEDIUM';
      case 'VEHICLE':
      case 'MOTORBIKE':
        return 'HIGH';
      case 'STRUCTURE':
        return 'LOW';
      default:
        return 'LOW';
    }
  }

  Color _threatColor(String threat) {
    switch (threat) {
      case 'HIGH':
        return Colors.redAccent;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return kNeonGreen;
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) return;
    _useFrontCamera = !_useFrontCamera;
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;
    await _initializeCamera();
  }

  void _toggleTracking() {
    setState(() => _isTracking = !_isTracking);
  }

  Future<void> _launchDeveloperLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the link right now.')),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: SafeArea(
        child: Column(
          children: [
            // Tactical status bar
            _buildStatusBar(),
            // Camera + HUD
            Expanded(
              flex: 55,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _buildCameraPreview(),
              ),
            ),
            // Vision mode switcher
            _buildVisionModeSwitcher(),
            // Target dossier panel
            Expanded(
              flex: 45,
              child: _buildTargetDossier(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Bar ──────────────────────────────────────────────────────────
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        border: Border(
          bottom: BorderSide(color: kNeonGreen.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: kNeonGreen, size: 16),
          ),
          const SizedBox(width: 10),
          // Title
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kNeonGreen, Color(0xFF00B4D8)]),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.track_changes_rounded,
                color: Colors.black, size: 14),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEXUS TARGETING',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              Text('COMBAT VISION SYSTEM',
                  style: TextStyle(
                      color: Colors.white30,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          // FPS
          _statusBadge('${_fps}FPS',
              _fps > 10 ? kNeonGreen : Colors.orange),
          const SizedBox(width: 6),
          // Object count
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) => _statusBadge(
              '${_detections.length} TGT',
              _detections.isNotEmpty
                  ? Colors.redAccent.withValues(alpha: _pulseAnim.value)
                  : Colors.white30,
            ),
          ),
          const SizedBox(width: 6),
          // Tracking status
          GestureDetector(
            onTap: _toggleTracking,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isTracking
                    ? kNeonGreen.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isTracking
                      ? kNeonGreen.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _isTracking ? 'ACTIVE' : 'STANDBY',
                style: TextStyle(
                    color: _isTracking ? kNeonGreen : Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Camera switch
          if (_availableCameras.length > 1)
            GestureDetector(
              onTap: _switchCamera,
              child: Icon(
                _useFrontCamera ? Icons.camera_front : Icons.camera_rear,
                color: Colors.white54,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace')),
    );
  }

  // ── Vision Mode Switcher ────────────────────────────────────────────────
  Widget _buildVisionModeSwitcher() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: List.generate(_visionModes.length, (i) {
          final isActive = _visionMode == i;
          final color = _visionColors[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _visionMode = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? Border.all(color: color.withValues(alpha: 0.4))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_visionIcons[i], color: isActive ? color : Colors.white30, size: 12),
                    const SizedBox(width: 3),
                    Text(_visionModes[i],
                        style: TextStyle(
                            color: isActive ? color : Colors.white30,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Camera Preview + HUD ────────────────────────────────────────────────
  Widget _buildCameraPreview() {
    if (_permissionDenied || _initializationFailed) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(_statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ],
          ),
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(kNeonGreen.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('INITIALIZING SENSORS...',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ],
          ),
        ),
      );
    }

    final preview = CameraPreview(_cameraController!);
    final cameraSize =
        _cameraController!.value.previewSize ?? const Size(1, 1);

    // Vision mode color filter
    Widget filteredPreview = preview;
    switch (_visionMode) {
      case 1: // THERMAL
        filteredPreview = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1.5, 0, 0, 0, 40,
            0, 0.5, 0, 0, 0,
            0, 0, 0.3, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: preview,
        );
        break;
      case 2: // NIGHT-VIS
        filteredPreview = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.3, 0.6, 0.1, 0, 0,
            0.3, 0.9, 0.1, 0, 20,
            0.1, 0.3, 0.1, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: preview,
        );
        break;
      case 3: // EDGE-DETECT (high contrast B&W)
        filteredPreview = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            3, -1, -1, 0, -80,
            -1, 3, -1, 0, -80,
            -1, -1, 3, 0, -80,
            0, 0, 0, 1, 0,
          ]),
          child: preview,
        );
        break;
      case 4: // MATRIX
        filteredPreview = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0, 0, 0, 0, 0,
            0.3, 1, 0.3, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: preview,
        );
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: cameraSize.width / cameraSize.height,
            child: filteredPreview,
          ),
          // Radar sweep at edges
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) => CustomPaint(
              painter: _RadarSweepPainter(
                progress: _radarController.value,
                hasTargets: _detections.isNotEmpty,
              ),
            ),
          ),
          // Tactical HUD overlay
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) => CustomPaint(
              painter: _TacticalHUDPainter(
                detections: _detections,
                imageSize: Size(cameraSize.width, cameraSize.height),
                scanProgress: _scanController.value,
              ),
            ),
          ),
          // Bearing indicator top
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: kNeonGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'BRG: ${(math.Random().nextDouble() * 360).toStringAsFixed(1)}° • ALT: ${(math.Random().nextDouble() * 100 + 50).toStringAsFixed(0)}m',
                  style: TextStyle(
                      color: kNeonGreen.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          // Status overlay
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isTracking ? _statusMessage : 'TARGETING STANDBY',
                style: TextStyle(
                    color: _isTracking ? kNeonGreen : Colors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Target Dossier Panel ────────────────────────────────────────────────
  Widget _buildTargetDossier() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
            top: BorderSide(color: kNeonGreen.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, _) => Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _detections.isNotEmpty
                          ? Colors.redAccent
                              .withValues(alpha: 0.15 * _pulseAnim.value)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.radar_rounded,
                      color: _detections.isNotEmpty
                          ? Colors.redAccent
                          : Colors.white30,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TARGET DOSSIER',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                      Text(
                        _detections.isEmpty
                            ? 'No targets in scope'
                            : '${_detections.length} target${_detections.length > 1 ? 's' : ''} locked',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
                // Threat assessment
                if (_detections.isNotEmpty) _buildThreatAssessment(),
              ],
            ),
          ),
          // Detection list
          Expanded(
            child: _detections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_off_rounded,
                            color: Colors.white.withValues(alpha: 0.12),
                            size: 36),
                        const SizedBox(height: 8),
                        Text(
                          _permissionDenied || _initializationFailed
                              ? _statusMessage
                              : 'Aim sensor to detect targets',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: _detections.length + 1, // +1 for dev panel
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index < _detections.length) {
                        return _buildDossierCard(_detections[index]);
                      }
                      return _buildDevPanel();
                    },
                  ),
          ),
          if (_detections.isEmpty) _buildDevPanel(),
        ],
      ),
    );
  }

  Widget _buildThreatAssessment() {
    final hasHigh = _detections.any(
        (d) => _threatLevel(d.label) == 'HIGH');
    final hasMedium = _detections.any(
        (d) => _threatLevel(d.label) == 'MEDIUM');
    final level = hasHigh
        ? 'HIGH'
        : hasMedium
            ? 'MEDIUM'
            : 'LOW';
    final color = _threatColor(level);

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1 * _pulseAnim.value),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 12),
            const SizedBox(width: 4),
            Text('THREAT: $level',
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierCard(_DetectionResult detection) {
    final threat = _threatLevel(detection.label);
    final tColor = _threatColor(threat);
    final confPercent = (detection.confidence * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: detection.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Classification icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: detection.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_classIcon(detection.label),
                color: detection.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(detection.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: tColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(threat,
                          style: TextStyle(
                              color: tColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Confidence bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: detection.confidence,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              detection.color),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$confPercent%',
                        style: TextStyle(
                            color: detection.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tracking ID
          Column(
            children: [
              Text('ID',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 8,
                      fontWeight: FontWeight.w700)),
              Text('${detection.trackingId ?? 0}',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _classIcon(String label) {
    switch (label) {
      case 'HUMAN':
        return Icons.person_rounded;
      case 'VEHICLE':
        return Icons.directions_car_rounded;
      case 'BIKE':
        return Icons.pedal_bike_rounded;
      case 'MOTORBIKE':
        return Icons.two_wheeler_rounded;
      case 'STRUCTURE':
        return Icons.apartment_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // ── Developer Panel (collapsible) ───────────────────────────────────────
  Widget _buildDevPanel() {
    return Padding(
      padding: _detections.isEmpty
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => setState(() => _devPanelExpanded = !_devPanelExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0A0F1E),
                const Color(0xFF140F2B).withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.code_rounded,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEXDROID // NEXO TECH',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8)),
                        Text('Developer Dossier',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ),
                  Icon(
                    _devPanelExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
              if (_devPanelExpanded) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _developerTag(
                      label: 'anonyemichael',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF00E5FF),
                      onTap: () => launchUrl(
                        Uri.parse('https://github.com/anonyemichael'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    _developerTag(
                      label: 'SECURITY TEAM',
                      icon: Icons.shield_rounded,
                      color: const Color(0xFF00FF88),
                      onTap: () => launchUrl(
                        Uri.parse(
                            'https://github.com/alexhack235-code/REDOX-PY_SCANNER.git'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _developerActionButton(
                        label: 'Website',
                        icon: Icons.language_rounded,
                        onPressed: () => _launchDeveloperLink(
                            'https://nexo-tech-ltd.vercel.app'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _developerActionButton(
                        label: 'GitHub',
                        icon: Icons.code_rounded,
                        onPressed: () => _launchDeveloperLink(
                            'https://github.com/nexchat23-dev-team/NEXO-TECHNOLOGIES.git'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                      context, AboutDevelopersScreen.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: Colors.black, size: 14),
                        SizedBox(width: 6),
                        Text('FULL DEVELOPER DOSSIER',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _developerActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF8B5CF6), size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _developerTag({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DETECTION RESULT
// ════════════════════════════════════════════════════════════════════════════
class _DetectionResult {
  _DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.trackingId,
  });

  final String label;
  final double confidence;
  final Rect boundingBox;
  final int? trackingId;

  Color get color {
    final normalized = label.toLowerCase();
    if (normalized.contains('human')) return Colors.tealAccent;
    if (normalized.contains('bike')) return Colors.orangeAccent;
    if (normalized.contains('vehicle') || normalized.contains('car')) {
      return Colors.blueAccent;
    }
    if (normalized.contains('structure') || normalized.contains('building')) {
      return Colors.purpleAccent;
    }
    if (normalized.contains('motorbike')) return Colors.amberAccent;
    return Colors.greenAccent;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TACTICAL HUD PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _TacticalHUDPainter extends CustomPainter {
  _TacticalHUDPainter({
    required this.detections,
    required this.imageSize,
    required this.scanProgress,
  });

  final List<_DetectionResult> detections;
  final Size imageSize;
  final double scanProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;

    // Range finder hash marks on sides
    _drawRangeFinder(canvas, size);

    // Draw detection reticles
    for (var i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;
      final rect = Rect.fromLTRB(
        detection.boundingBox.left * scaleX,
        detection.boundingBox.top * scaleY,
        detection.boundingBox.right * scaleX,
        detection.boundingBox.bottom * scaleY,
      );

      final color = detection.color;
      paint
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = 2;

      final cornerLen = math.min(rect.width, rect.height) * 0.25;

      // Top-left corner bracket
      canvas.drawLine(rect.topLeft, Offset(rect.left + cornerLen, rect.top), paint);
      canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + cornerLen), paint);
      // Top-right
      canvas.drawLine(rect.topRight, Offset(rect.right - cornerLen, rect.top), paint);
      canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + cornerLen), paint);
      // Bottom-left
      canvas.drawLine(rect.bottomLeft, Offset(rect.left + cornerLen, rect.bottom), paint);
      canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - cornerLen), paint);
      // Bottom-right
      canvas.drawLine(rect.bottomRight, Offset(rect.right - cornerLen, rect.bottom), paint);
      canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - cornerLen), paint);

      // Primary target crosshair (highest confidence)
      if (i == 0) {
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        final crossSize = math.min(rect.width, rect.height) * 0.15;
        paint
          ..color = Colors.redAccent.withValues(alpha: 0.7)
          ..strokeWidth = 1.5;
        canvas.drawLine(
            Offset(cx - crossSize, cy), Offset(cx + crossSize, cy), paint);
        canvas.drawLine(
            Offset(cx, cy - crossSize), Offset(cx, cy + crossSize), paint);

        // Rotating outer ring
        final ringR = math.min(rect.width, rect.height) * 0.35;
        paint
          ..color = Colors.redAccent.withValues(alpha: 0.4)
          ..strokeWidth = 1;
        final arcStart = scanProgress * math.pi * 2;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: ringR),
          arcStart,
          math.pi * 1.2,
          false,
          paint,
        );
      }

      // Label
      final label =
          '${detection.label} ${(detection.confidence * 100).toInt()}%';
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          backgroundColor: Colors.black.withValues(alpha: 0.5),
        ),
      );
      final textPainter = TextPainter(
          text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout(
          minWidth: 0, maxWidth: size.width - rect.left - 8);
      textPainter.paint(
          canvas, Offset(rect.left, rect.top - textPainter.height - 4));

      // Prediction arrow
      if (rect.center.dx < size.width * 0.5) {
        paint
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 1;
        canvas.drawLine(
          rect.center,
          Offset(rect.center.dx + rect.width * 0.3,
              rect.center.dy - rect.height * 0.1),
          paint,
        );
      }
    }

    // Scan line
    final scanY = size.height * scanProgress;
    paint
      ..color = kNeonGreen.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), paint);
  }

  void _drawRangeFinder(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kNeonGreen.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Left side hashes
    for (var y = 0.0; y < size.height; y += 30) {
      final len = (y % 90 == 0) ? 16.0 : 8.0;
      canvas.drawLine(Offset(0, y), Offset(len, y), paint);
    }
    // Right side hashes
    for (var y = 0.0; y < size.height; y += 30) {
      final len = (y % 90 == 0) ? 16.0 : 8.0;
      canvas.drawLine(
          Offset(size.width, y), Offset(size.width - len, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalHUDPainter oldDelegate) => true;
}

// ════════════════════════════════════════════════════════════════════════════
// RADAR SWEEP PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _RadarSweepPainter extends CustomPainter {
  _RadarSweepPainter({required this.progress, required this.hasTargets});

  final double progress;
  final bool hasTargets;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.sqrt(cx * cx + cy * cy) * 0.3;

    // Concentric rings at corners
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var r = maxR * 0.3; r <= maxR; r += maxR * 0.25) {
      paint.color = kNeonGreen.withValues(alpha: 0.04);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // Sweep beam
    if (hasTargets) {
      final angle = progress * math.pi * 2;
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: angle - 0.5,
          endAngle: angle,
          colors: [
            Colors.transparent,
            kNeonGreen.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
      canvas.drawCircle(Offset(cx, cy), maxR, sweepPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hasTargets != hasTargets;
}
