import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/services/rust_scan_service.dart';

void main() {
  group('RustScanService', () {
    test('parses summary, risk, and findings from scanner output', () {
      const output = '''summary:Rust scan completed with 2 profile checks.
risk:High Risk
stats:files_scanned:5\ndirs_scanned:2\nbytes_scanned:2048\nhigh_risk_matches:1\nmedium_risk_matches:1\nlow_risk_matches:0
finding:payload.exe|Suspicious command sequence|High|The content contains command patterns often used by payload installers or loaders.
finding:notes.tmp|Transient artifact|Low|Temporary or cache file artifacts can be noisy and may indicate staging behavior.
''';

      final parsed = RustScanService.parseScanOutput(output);

      expect(parsed['summary'], contains('2 profile checks'));
      expect(parsed['risk'], 'High Risk');
      expect(parsed['findings'], hasLength(2));
      expect(parsed['findings'][0]['label'], 'payload.exe');
      expect(parsed['findings'][1]['severity'], 'Low');
    });

    test('parses findings without optional reasoning and with pipes in reasoning', () {
      const output = '''summary:Rust scan completed.
risk:Medium
finding:payload.exe|Suspicious command sequence|High|Pattern with pipe | character
finding:notes.tmp|Transient artifact|Low
''';

      final parsed = RustScanService.parseScanOutput(output);

      expect(parsed['findings'], hasLength(2));
      expect(parsed['findings'][0]['reasoning'], 'Pattern with pipe | character');
      expect(parsed['findings'][1]['reasoning'], '');
    });
  });
}
