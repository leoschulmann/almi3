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

// TODO phase 2+, not wired up yet: gate for whether practice sessions may
// touch a card, based on retrievability (spec §6.3), ~0.95.
// const double practiceGateRetrievabilityThreshold = 0.95;

// TODO phase 2+, not wired up yet: half-life (in days) for the practice
// bonus decay curve (spec §8.3), ~3.
// const double practiceBonusHalflifeDays = 3;

// TODO phase 2+, not wired up yet: saturation cap for the practice bonus
// (spec §8.3), ~0.30.
// const double practiceBonusSaturationCap = 0.30;
