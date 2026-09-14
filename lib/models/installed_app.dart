import 'dart:typed_data';

class InstalledApp {
  final String packageName;
  final String appName;
  final Uint8List? icon;

  const InstalledApp({
    required this.packageName,
    required this.appName,
    this.icon,
  });
}
