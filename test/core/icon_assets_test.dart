import 'package:almi3/core/icon_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('heartHealthLevel', () {
    test('null health -> na (0)', () {
      expect(heartHealthLevel(null), 0);
    });

    test('NaN health -> na (0), not empty (1)', () {
      expect(heartHealthLevel(double.nan), 0);
    });

    test('quintile boundaries map to 1..5', () {
      expect(heartHealthLevel(0), 1);
      expect(heartHealthLevel(19.9), 1);
      expect(heartHealthLevel(20), 2);
      expect(heartHealthLevel(39.9), 2);
      expect(heartHealthLevel(40), 3);
      expect(heartHealthLevel(59.9), 3);
      expect(heartHealthLevel(60), 4);
      expect(heartHealthLevel(79.9), 4);
      expect(heartHealthLevel(80), 5);
      expect(heartHealthLevel(100), 5);
    });

    test('health above 100 (practice bonus) -> super (6)', () {
      expect(heartHealthLevel(100.1), 6);
      expect(heartHealthLevel(140), 6);
    });
  });
}
