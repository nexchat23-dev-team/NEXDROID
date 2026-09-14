import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../services/permissions_service.dart';
import '../utils/constants.dart';
import '../utils/qr_content_analyzer.dart';
import '../widgets/cyber_background.dart';

class QrScannerScreen extends StatefulWidget {
  static const routeName = '/qr-scanner';
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  String? _scannedValue;
  bool _permissionGranted = true;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final service = PermissionsService();
    final granted = await service.requestCameraPermission();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
    });
  }

  Future<void> _pickAndAnalyzeQrImage() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.image,
      );
      if (result == null || result.path == null || result.path!.isEmpty) {
        return;
      }

      final filePath = result.path!;
      final capture = await _controller.analyzeImage(filePath);
      final barcode = capture?.barcodes.isNotEmpty == true
          ? capture?.barcodes.first
          : null;
      final value = barcode?.rawValue;

      if (value == null || value.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code was found in the image.')),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _scannedValue = value;
        _isScanning = false;
      });

      try {
        await _controller.stop();
      } catch (_) {}
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to analyze image: ${error.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF060B14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
          ),
          title: const Text('QR', style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            tabs: [Tab(text: 'Scan'), Tab(text: 'Create')],
            indicatorColor: kNeonGreen,
            labelColor: kNeonGreen,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(
                child: CyberBackground(
              backgroundColors: [
                Color(0xFF02040A),
                Color(0xFF07111E),
                Color(0xFF0D1730),
                Color(0xFF04050C),
              ],
              leftAuroraColors: [
                Color(0xFF00F0B6),
                Color(0xFF5A50FF),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFFB14BFF),
                Color(0xFF3B82F6),
                Color(0x00000000),
              ],
              fogColor: Color(0x1EFFFFFF),
              leftAuroraCenter: Alignment(-0.24, -0.23),
              rightAuroraCenter: Alignment(0.82, -0.16),
            )),
            TabBarView(
              children: [
                // Scan tab (original scanner view with enhanced result actions)
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _permissionGranted
                                ? Stack(
                                    children: [
                                      MobileScanner(
                                        controller: _controller,
                                        onDetect: (capture) async {
                                          if (!_isScanning) return;
                                          final barcodes = capture.barcodes;
                                          final barcode = barcodes.isNotEmpty
                                              ? barcodes.first
                                              : null;
                                          final value = barcode?.rawValue;
                                          if (value == null || value.isEmpty) {
                                            return;
                                          }
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(() {
                                            _scannedValue = value;
                                            _isScanning = false;
                                          });
                                          try {
                                            await _controller.stop();
                                          } catch (_) {}
                                        },
                                      ),
                                      Positioned.fill(
                                          child: CustomPaint(
                                              painter:
                                                  _ScannerOverlayPainter())),
                                    ],
                                  )
                                : Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D1E36)
                                            .withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(18),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.camera_alt,
                                              color: kNeonBlue, size: 34),
                                          const SizedBox(height: 12),
                                          const Text(
                                              'Camera permission is needed to scan QR codes.',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final granted =
                                                  await PermissionsService()
                                                      .requestCameraPermission();
                                              if (!mounted) return;
                                              setState(() =>
                                                  _permissionGranted = granted);
                                            },
                                            icon: const Icon(
                                                Icons.refresh_rounded),
                                            label: const Text('Try again'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: kNeonGreen,
                                                foregroundColor: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          onPressed: _pickAndAnalyzeQrImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload QR image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNeonBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_scannedValue != null)
                        _buildScannedResultCard(context),
                    ],
                  ),
                ),

                // Create tab
                const SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Create QR',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 12),
                        Text('Create a QR code from a URL or text',
                            style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 16),
                        _CreateQrForm(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedResultCard(BuildContext context) {
    final value = _scannedValue ?? '';
    final isUrl = value.startsWith('http://') || value.startsWith('https://');
    final analysis = analyzeQrContent(value);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E36).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kNeonGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scanned result',
              style: TextStyle(
                  color: kNeonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SelectableText(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.summary,
                  style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip('Letters', '${analysis.letters}'),
                    _buildMetricChip('Numbers', '${analysis.numbers}'),
                    _buildMetricChip('Chars', '${analysis.symbols}'),
                    _buildMetricChip('Total', '${analysis.totalCharacters}'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fingerprint: ${analysis.fingerprint}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isUrl)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(value);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Link'),
                    style: ElevatedButton.styleFrom(backgroundColor: kNeonBlue),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Copied to clipboard')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(backgroundColor: kNeonBlue),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _scannedValue = null;
                      _isScanning = true;
                    });
                    _controller.start();
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan again'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kNeonBlue,
                      side: const BorderSide(color: kNeonBlue)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }
}

class _CreateQrForm extends StatefulWidget {
  const _CreateQrForm({Key? key}) : super(key: key);

  @override
  State<_CreateQrForm> createState() => _CreateQrFormState();
}

class _CreateQrFormState extends State<_CreateQrForm> {
  final TextEditingController _dataController = TextEditingController();
  String _data = '';

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _dataController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter URL or text',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF0D1E36),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.link, color: kNeonBlue),
          ),
          onChanged: (v) => setState(() => _data = v),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF0D1E36),
                borderRadius: BorderRadius.circular(12)),
            child: _data.isEmpty
                ? const Text('QR preview will appear here',
                    style: TextStyle(color: Colors.white38))
                : QrImageView(
                    data: _data,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _data.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: _data));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('QR data copied')));
                  }
                },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Data'),
          style: ElevatedButton.styleFrom(
              backgroundColor: kNeonGreen, foregroundColor: Colors.black),
        ),
      ],
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutout = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 - 20),
        width: size.width * 0.72,
        height: size.width * 0.72,
      ),
      const Radius.circular(24),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(cutout),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = kNeonGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(cutout, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
