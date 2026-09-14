import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/utils/compass_utils.dart';

void main() {
  group('compass utilities', () {
    test('cardinalDirection maps headings to the correct direction', () {
      expect(cardinalDirection(0), 'N');
      expect(cardinalDirection(45), 'NE');
      expect(cardinalDirection(90), 'E');
      expect(cardinalDirection(180), 'S');
      expect(cardinalDirection(270), 'W');
      expect(cardinalDirection(359), 'N');
    });

    test('headingStatusLabel reports live, calibrating, or offline state', () {
      expect(headingStatusLabel(0.95, true), 'Live');
      expect(headingStatusLabel(0.4, true), 'Calibrating');
      expect(headingStatusLabel(0.0, false), 'Offline');
    });
  });
}
