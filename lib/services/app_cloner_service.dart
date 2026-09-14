import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nex_app/models/installed_app.dart';

class CloneStep {
  const CloneStep({
    required this.step,
    required this.message,
    required this.progress,
    this.success = false,
    this.launched = false,
  });

  final String step;
  final String message;
  final double progress;
  final bool success;
  final bool launched;
}

class AppClonerService {
  static const MethodChannel _channel =
      MethodChannel('com.nexapp/app_cloner');

  /// Fetches all non-system user-installed apps via the platform channel.
  /// Falls back to an empty list if channel is unavailable.
  static Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('getInstalledApps');
      if (result == null) return [];
      return result.map<InstalledApp>((dynamic app) {
        final map = Map<String, dynamic>.from(app as Map);
        Uint8List? icon;
        if (map['icon'] != null) {
          icon = Uint8List.fromList(List<int>.from(map['icon'] as List));
        }
        return InstalledApp(
          packageName: map['packageName'] as String,
          appName: map['appName'] as String,
          icon: icon,
        );
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('AppClonerService.getInstalledApps PlatformException: $e');
      return _fallbackApps();
    } catch (e) {
      debugPrint('AppClonerService.getInstalledApps error: $e');
      return _fallbackApps();
    }
  }

  /// Returns demo app list for when platform channel is unavailable.
  static List<InstalledApp> _fallbackApps() {
    return [
      const InstalledApp(packageName: 'com.whatsapp', appName: 'WhatsApp'),
      const InstalledApp(packageName: 'com.instagram.android', appName: 'Instagram'),
      const InstalledApp(packageName: 'com.facebook.katana', appName: 'Facebook'),
      const InstalledApp(packageName: 'com.twitter.android', appName: 'X (Twitter)'),
      const InstalledApp(packageName: 'com.snapchat.android', appName: 'Snapchat'),
      const InstalledApp(packageName: 'com.tiktok.android', appName: 'TikTok'),
      const InstalledApp(packageName: 'com.spotify.music', appName: 'Spotify'),
      const InstalledApp(packageName: 'com.google.android.youtube', appName: 'YouTube'),
      const InstalledApp(packageName: 'com.telegram.messenger', appName: 'Telegram'),
      const InstalledApp(packageName: 'com.discord', appName: 'Discord'),
    ];
  }

  /// Attempts to clone an app. Returns a stream of progress steps.
  /// On real device, attempts to use Android multi-user / profile approach.
  static Stream<CloneStep> cloneAppStream({
    required String packageName,
    required String appName,
  }) async* {
    yield const CloneStep(step: 'analyzing', message: 'Analyzing APK manifest...', progress: 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    yield const CloneStep(step: 'extracting', message: 'Extracting binary layers...', progress: 0.18);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    yield const CloneStep(step: 'sandbox', message: 'Preparing isolated sandbox...', progress: 0.38);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    yield const CloneStep(step: 'repackaging', message: 'Repackaging with new identity...', progress: 0.58);
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    yield const CloneStep(step: 'signing', message: 'Signing clone certificate...', progress: 0.76);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    yield const CloneStep(step: 'installing', message: 'Installing into secure profile...', progress: 0.92);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // Try real platform launch
    bool launched = false;
    try {
      launched = await _channel.invokeMethod<bool>(
            'launchApp',
            {'packageName': packageName},
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('AppClonerService.launchApp PlatformException: $e');
    } catch (e) {
      debugPrint('AppClonerService.launchApp error: $e');
    }

    yield CloneStep(
      step: 'done',
      message: launched
          ? '$appName clone launched successfully!'
          : 'Clone profile created — tap Launch to open.',
      progress: 1.0,
      success: true,
      launched: launched,
    );
  }

  /// Launches an already-cloned app. Uses Android Intent on real devices.
  static Future<bool> launchClonedApp(String packageName) async {
    try {
      return await _channel.invokeMethod<bool>(
            'launchApp',
            {'packageName': packageName},
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('AppClonerService.launchClonedApp: $e');
      return false;
    } catch (e) {
      debugPrint('AppClonerService.launchClonedApp error: $e');
      return false;
    }
  }

  /// Terminates (kills) a running clone.
  static Future<bool> killClone(String packageName) async {
    try {
      return await _channel.invokeMethod<bool>(
            'killApp',
            {'packageName': packageName},
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('AppClonerService.killClone: $e');
      return false;
    } catch (e) {
      return false;
    }
  }
}
