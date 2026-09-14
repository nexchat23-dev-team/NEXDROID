import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/utils/music_download_utils.dart';

void main() {
  group('music download utilities', () {
    test('sanitizeTrackFileName strips invalid characters', () {
      expect(sanitizeTrackFileName('My / Track: #1'), 'My_Track_1');
      expect(sanitizeTrackFileName('  Listen  '), 'Listen');
    });
  });
}
