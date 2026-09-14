import 'package:flutter/services.dart';
 class ProtectionService {
  static const MethodChannel _channel = MethodChannel('nex_app/protection');

  Future<bool> startProtection() async {
    final result = await _channel.invokeMethod<bool>('startProtection');
    return result ?? false;
  }

  Future<bool> stopProtection() async {
    final result = await _channel.invokeMethod<bool>('stopProtection');
    return result ?? false;
  }

  Future<bool> isProtectionEnabled() async {
    final result = await _channel.invokeMethod<bool>('isProtectionEnabled');
    return result ?? false;
  }
}
