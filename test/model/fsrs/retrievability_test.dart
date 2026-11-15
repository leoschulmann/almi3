import 'package:almi3/model/fsrs/retrievability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

void main() {
  group('deriveFsrsFactorAndDecay', () {
    test('matches fsrs.Scheduler internal derivation for default weights', () {
      final result = deriveFsrsFactorAndDecay(fsrs.defaultParameters);
      // decay = -weights[20]; factor = 0.9^(1/decay) - 1, weights[20] == 0.2
      expect(result.decay, closeTo(-0.2, 1e-12));
      expect(result.factor, closeTo(0.6935087808, 1e-9));
    });

    test('derives from a custom (non-default) weights vector', () {
      final weights = List<double>.filled(21, 1.0)..[20] = 0.5;
      final result = deriveFsrsFactorAndDecay(weights);
      // decay = -0.5; factor = 0.9^(1/-0.5) - 1 = 0.9^-2 - 1
      expect(result.decay, closeTo(-0.5, 1e-12));
      expect(result.factor, closeTo(0.2345679012, 1e-9));
    });
  });

  group('fractionalDayRetrievability', () {
    const stability = 10.0;
    final derived = deriveFsrsFactorAndDecay(fsrs.defaultParameters);

    test('equals 1.0 at zero elapsed time', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final r = fractionalDayRetrievability(
        stability: stability,
        lastReview: now,
        currentDateTime: now,
        factor: derived.factor,
        decay: derived.decay,
      );
      expect(r, closeTo(1.0, 1e-9));
    });

    test('decays continuously within the first calendar day (no 100% plateau)', () {
      final lastReview = DateTime.utc(2026, 1, 1, 0);
      final at6h = fractionalDayRetrievability(
        stability: stability,
        lastReview: lastReview,
        currentDateTime: lastReview.add(const Duration(hours: 6)),
        factor: derived.factor,
        decay: derived.decay,
      );
      final at12h = fractionalDayRetrievability(
        stability: stability,
        lastReview: lastReview,
        currentDateTime: lastReview.add(const Duration(hours: 12)),
        factor: derived.factor,
        decay: derived.decay,
      );
      final at23h = fractionalDayRetrievability(
        stability: stability,
        lastReview: lastReview,
        currentDateTime: lastReview.add(const Duration(hours: 23)),
        factor: derived.factor,
        decay: derived.decay,
      );

      expect(at6h, lessThan(1.0));
      expect(at12h, lessThan(at6h));
      expect(at23h, lessThan(at12h));
    });

    test('matches fsrs.Scheduler.getCardRetrievability exactly on whole-day boundaries', () {
      final lastReview = DateTime.utc(2026, 1, 1, 0);
      final currentDateTime = DateTime.utc(2026, 1, 4, 0); // exactly 3 whole days later
      final ours = fractionalDayRetrievability(
        stability: stability,
        lastReview: lastReview,
        currentDateTime: currentDateTime,
        factor: derived.factor,
        decay: derived.decay,
      );

      final card = fsrs.Card(
        cardId: 1,
        state: fsrs.State.review,
        stability: stability,
        lastReview: lastReview,
      );
      final scheduler = fsrs.Scheduler();
      final theirs = scheduler.getCardRetrievability(card, currentDateTime: currentDateTime);

      expect(ours, closeTo(theirs, 1e-9));
    });

    test('elapsed time before last review clamps to zero instead of going negative', () {
      final lastReview = DateTime.utc(2026, 1, 2, 0);
      final r = fractionalDayRetrievability(
        stability: stability,
        lastReview: lastReview,
        currentDateTime: lastReview.subtract(const Duration(hours: 1)),
        factor: derived.factor,
        decay: derived.decay,
      );
      expect(r, closeTo(1.0, 1e-9));
    });
  });
}
