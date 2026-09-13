const double defaultDesiredRetention = 0.9;

const List<Duration> defaultLearningSteps = [
  Duration(minutes: 1),
  Duration(minutes: 10),
];

const List<Duration> defaultRelearningSteps = [
  Duration(minutes: 10),
];

const int defaultMaximumInterval = 36500;

const List<double> defaultFsrsWeights = [
  0.2172, 1.1771, 3.2602, 16.1507, 7.0114, 0.57, 2.0966, 0.0069, 1.5261, 0.112,
  1.0178, 1.849, 0.1133, 0.3127, 2.2934, 0.2191, 3.0004, 0.7536, 0.3332, 0.1437,
  0.2,
];

// Grading time thresholds (§5.3). Calibratable — rough defaults, not tuned
// on real data yet.

/// typed_production: below this, a correct answer is graded Easy.
const int typedProductionFastMs = 3000;

/// typed_production: above this, a correct answer is graded Hard.
const int typedProductionSlowMs = 10000;

/// mc2_*/mc4_*: above this, a correct answer is graded Hard instead of Good.
const int mcSlowMs = 6000;

/// listening: below this, a correct answer is graded Easy.
const int listeningFastMs = 4000;

/// listening: above this, a correct answer is graded Hard.
const int listeningSlowMs = 10000;

/// Review-state recognition format mix: probability of picking `listening`
/// over `mc4Recognition` (§5.2 "разнообразие и повторяемость").
const double reviewListeningWeight = 0.5;

// Free-practice gate (§6.3) and composite health bonus (§8.3) constants.
// Rough defaults, not tuned on real data yet.

/// Practice gate: a card is "too fresh" to count as a real review when its
/// retrievability is above this threshold (don't force-review a fresh card).
const double practiceGateRetrievabilityThreshold = 0.95;

/// Half-life (in days) for the practice-bonus decay curve (§8.3): a
/// practice event's contribution to `raw` decays by half every this many
/// days.
const double practiceBonusHalflifeDays = 3;

/// Saturation cap for the practice bonus (§8.3): the bonus can add at most
/// this much (as a 0..1 fraction) to base health, however many practice
/// events pile up.
const double practiceBonusSaturationCap = 0.30;

/// Saturation curve constant (§8.3's `K`) for `bonus = CAP * (1 - exp(-raw/K))`.
/// Not named explicitly in the spec — chosen so a handful of recent correct
/// practice events already approach the cap, rather than needing dozens.
const double practiceBonusK = 1.0;
