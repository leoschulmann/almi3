import 'package:almi3/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nowUtcSeconds', () {
    test('is close to DateTime.now().toUtc()', () {
      final expected = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final actual = nowUtcSeconds();
      expect((actual - expected).abs() <= 2, isTrue);
    });
  });

  group('dayBoundary', () {
    test('timestamp exactly at boundary hour returns itself', () {
      final ts = DateTime.utc(2026, 7, 13, 4, 0, 0).millisecondsSinceEpoch ~/ 1000;
      expect(dayBoundary(ts, 4), ts);
    });

    test('timestamp just before boundary rolls back to previous day', () {
      final ts = DateTime.utc(2026, 7, 13, 3, 59, 59).millisecondsSinceEpoch ~/ 1000;
      final expected = DateTime.utc(2026, 7, 12, 4, 0, 0).millisecondsSinceEpoch ~/ 1000;
      expect(dayBoundary(ts, 4), expected);
    });

    test('timestamp just after boundary stays on same day', () {
      final ts = DateTime.utc(2026, 7, 13, 4, 0, 1).millisecondsSinceEpoch ~/ 1000;
      final expected = DateTime.utc(2026, 7, 13, 4, 0, 0).millisecondsSinceEpoch ~/ 1000;
      expect(dayBoundary(ts, 4), expected);
    });

    test('boundary hour 0 behaves like midnight cutoff', () {
      final ts = DateTime.utc(2026, 7, 13, 23, 0, 0).millisecondsSinceEpoch ~/ 1000;
      final expected = DateTime.utc(2026, 7, 13, 0, 0, 0).millisecondsSinceEpoch ~/ 1000;
      expect(dayBoundary(ts, 0), expected);
    });

    test('boundary hour 23, timestamp just before crosses to previous day boundary', () {
      final ts = DateTime.utc(2026, 7, 13, 22, 59, 59).millisecondsSinceEpoch ~/ 1000;
      final expected = DateTime.utc(2026, 7, 12, 23, 0, 0).millisecondsSinceEpoch ~/ 1000;
      expect(dayBoundary(ts, 23), expected);
    });
  });
}
