import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:url_launcher/url_launcher.dart';
import 'about_developers_screen.dart';
import '../services/permissions_service.dart';

class AutoTrackerScreen extends StatefulWidget {
  const AutoTrackerScreen({super.key});

  static const String routeName = '/auto-tracker';

  @override
  State<AutoTrackerScreen> createState() => _AutoTrackerScreenState();
}

class _AutoTrackerScreenState extends State<AutoTrackerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  late final ObjectDetector _objectDetector;
  bool _isBusy = false;
  bool _isTracking = true;
  bool _permissionDenied = false;
  bool _initializationFailed = false;
  String _statusMessage = 'Preparing live tracker...';
  List<CameraDescription> _availableCameras = [];
  final List<_DetectionResult> _detections = [];
  bool _useFrontCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _objectDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed && _cameraDescription != null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final granted = await PermissionsService().requestCameraPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _statusMessage = 'Camera permission denied. Please grant camera access.';
      });
      return;
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        throw StateError('No available cameras found.');
      }

      final lensDirection = _useFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;
      _cameraDescription = _availableCameras.firstWhere(
        (camera) => camera.lensDirection == lensDirection,
        orElse: () => _availableCameras.first,
      );

      _cameraController = CameraController(
        _cameraDescription!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processCameraImage);

      if (!mounted) return;
      setState(() {
        _initializationFailed = false;
        _permissionDenied = false;
        _statusMessage = 'Live camera ready. Tracking objects now.';
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Failed to initialize camera: $e');
      setState(() {
        _initializationFailed = true;
        _statusMessage = 'Could not start the camera. Try again.';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isTracking || _isBusy || _cameraController == null) {
      return;
    }
    _isBusy = true;

    try {
      final inputImage = _cameraImageToInputImage(image, _cameraDescription!);
      final objects = await _objectDetector.processImage(inputImage);
      final results = objects.map((object) {
        final label = object.labels.isNotEmpty
            ? _normalizeLabel(object.labels.first.text)
            : 'Unknown';
        final confidence = object.labels.isNotEmpty ? object.labels.first.confidence : 0.0;
        return _DetectionResult(
          label: label,
          confidence: confidence,
          boundingBox: object.boundingBox,
          trackingId: object.trackingId,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _detections
          ..clear()
          ..addAll(results);
      });
    } catch (e) {
      debugPrint('Object detection failed: $e');
    } finally {
      _isBusy = false;
    }
  }

  InputImage _cameraImageToInputImage(CameraImage image, CameraDescription description) {
    final allBytes = BytesBuilder();
    for (final plane in image.planes) {
      allBytes.add(plane.bytes);
    }
    final bytes = allBytes.toBytes();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = _rotationIntToImageRotation(description.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
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
    if (label.contains('person') || label.contains('human')) {
      return 'Human';
    }
    if (label.contains('bicycle') || label.contains('bike')) {
      return 'Bike';
    }
    if (label.contains('car') || label.contains('truck') || label.contains('vehicle') || label.contains('bus') || label.contains('train')) {
      return 'Vehicle';
    }
    if (label.contains('motorcycle') || label.contains('scooter')) {
      return 'Motorbike';
    }
    if (label.contains('building') || label.contains('architecture') || label.contains('structure')) {
      return 'Building';
    }
    return rawLabel.isNotEmpty ? rawLabel : 'Object';
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
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the link right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Tracker'),
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.pause_circle_filled : Icons.play_circle_filled),
            tooltip: _isTracking ? 'Pause detection' : 'Resume detection',
            onPressed: _toggleTracking,
          ),
          if (_availableCameras.length > 1)
            IconButton(
              icon: Icon(_useFrontCamera ? Icons.camera_front : Icons.camera_rear),
              tooltip: 'Switch camera',
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildCameraPreview(isDark),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live detection',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF070D1E),
                              Color(0xFF140F2B),
                              Color(0xFF111827),
                              Color(0xFF0E1631),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                            width: 1.6,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF8B5CF6),
                              blurRadius: 28,
                              spreadRadius: 1,
                              offset: Offset(0, 14),
                            ),
                            BoxShadow(
                              color: Color(0xFF00E5FF),
                              blurRadius: 16,
                              spreadRadius: 0,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              right: -12,
                              top: -10,
                              child: SizedBox(
                                width: 110,
                                height: 110,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              left: -8,
                              bottom: 0,
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF00E5FF),
                                              blurRadius: 22,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.code_rounded, color: Colors.white, size: 28),
                                      ),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'NEXDROID',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.3,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'DEVELOPERS',
                                              style: TextStyle(
                                                color: Color(0xFFB9C5FF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00FF88).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.38)),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'NEXO TECHNOLOGIES',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'The company behind NEXDROID, building secure, intelligent, and connected digital experiences worldwide.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _developerTag(
                                        label: 'Fullstack Dev: anonyemichael',
                                        icon: Icons.person_rounded,
                                        color: const Color(0xFF00E5FF),
                                        onTap: () => launchUrl(
                                          Uri.parse('https://github.com/anonyemichael'),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                      ),
                                      _developerTag(
                                        label: 'NEXDROID SECURITY TEAM',
                                        icon: Icons.shield_rounded,
                                        color: const Color(0xFF00FF88),
                                        onTap: () => launchUrl(
                                          Uri.parse('https://github.com/alexhack235-code/REDOX-PY_SCANNER.git'),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _developerActionButton(
                                          label: 'Official Web',
                                          icon: Icons.language_rounded,
                                          onPressed: () => _launchDeveloperLink('https://nexo-tech-ltd.vercel.app'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _developerActionButton(
                                          label: 'GitHub',
                                          icon: Icons.code_rounded,
                                          onPressed: () => _launchDeveloperLink('https://github.com/nexchat23-dev-team/NEXO-TECHNOLOGIES.git'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () => Navigator.pushNamed(context, AboutDevelopersScreen.routeName),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6)],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'OPEN FULL DEVELOPER DOSSIER',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _detections.isEmpty
                          ? Center(
                              child: Text(
                                _permissionDenied || _initializationFailed
                                    ? _statusMessage
                                    : 'Look at the camera to start object detection.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              itemCount: _detections.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final detection = _detections[index];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                                    border: Border.all(
                                      color: detection.color.withValues(alpha: 0.18),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: detection.color,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${detection.label} · ${(_confidenceToPercent(detection.confidence))}%',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF111827),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'ID ${detection.trackingId ?? 0}',
                                        style: TextStyle(
                                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                          fontSize: 12,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(bool isDark) {
    if (_permissionDenied || _initializationFailed) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF475569)),
          ),
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final preview = CameraPreview(_cameraController!);
    final cameraSize = _cameraController!.value.previewSize ?? const Size(1, 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: cameraSize.width / cameraSize.height,
            child: preview,
          ),
          CustomPaint(
            painter: _BoundingBoxPainter(
              detections: _detections,
              imageSize: Size(cameraSize.width, cameraSize.height),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _isTracking ? 'Tracking live objects' : 'Paused',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _confidenceToPercent(double value) => (value * 100).clamp(0, 100).toInt();

  Widget _developerActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.36)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    if (normalized.contains('vehicle') || normalized.contains('car')) return Colors.blueAccent;
    if (normalized.contains('building')) return Colors.purpleAccent;
    return Colors.greenAccent;
  }
}

class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({required this.detections, required this.imageSize});

  final List<_DetectionResult> detections;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    for (final detection in detections) {
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;
      final rect = Rect.fromLTRB(
        detection.boundingBox.left * scaleX,
        detection.boundingBox.top * scaleY,
        detection.boundingBox.right * scaleX,
        detection.boundingBox.bottom * scaleY,
      ).deflate(2);

      paint.color = detection.color;
      canvas.drawRect(rect, paint);

      final label = '${detection.label} ${_confidenceToPercent(detection.confidence)}%';
      final textSpan = TextSpan(text: label, style: textStyle.copyWith(backgroundColor: detection.color.withValues(alpha: 0.75)));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout(minWidth: 0, maxWidth: size.width - rect.left - 8);
      textPainter.paint(canvas, Offset(rect.left, rect.top - textPainter.height - 4));
    }
  }

  int _confidenceToPercent(double value) => (value * 100).clamp(0, 100).toInt();

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.imageSize != imageSize;
  }
}
