import 'dart:math' as math;

/// Fractional-day FSRS retrievability. Same model as `fsrs.Scheduler.getCardRetrievability`
/// (`retrievability = (1 + factor * elapsedDays / stability) ^ decay`), but `elapsedDays`
/// is a double (fractional days) instead of `Duration.inDays` truncating to whole days —
/// so the value decays continuously between reviews instead of holding a 100% plateau for
/// a full calendar day (see docs/learning_engine_spec.md §8.1).
///
/// Pure and read-only: no DB/service dependency, never writes to card_fsrs.
double fractionalDayRetrievability({
  required double stability,
  required DateTime lastReview,
  required DateTime currentDateTime,
  required double factor,
  required double decay,
}) {
  final elapsedDays = math.max(
    0.0,
    currentDateTime.difference(lastReview).inMicroseconds / Duration.microsecondsPerDay,
  );
  return math.pow(1 + factor * elapsedDays / stability, decay).toDouble();
}

/// Derives `factor`/`decay` from live FSRS weights the same way `fsrs.Scheduler` does
/// internally (`decay = -weights[20]; factor = 0.9^(1/decay) - 1`), so callers can pass
/// the live `fsrs_params.params_json` weights without duplicating the derivation.
({double factor, double decay}) deriveFsrsFactorAndDecay(List<double> weights) {
  final decay = -weights[20];
  final factor = math.pow(0.9, 1 / decay) - 1;
  return (factor: factor.toDouble(), decay: decay);
}
