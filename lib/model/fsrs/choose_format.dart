import 'dart:math';

import 'package:almi3/core/engine_config.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// Picks a quiz format for a card (§5.2). Pure function of card maturity —
/// the format is never stored on the card itself.
///
/// Returns null for a New card (isNew, per [card_state.isNew]): per §5.2 a
/// New card gets a plain introduction, not a quiz, so there is no rating.
QuizType? chooseFormat({
  required bool isNew,
  required int state,
  required int? step,
  required int direction,
  Random? random,
}) {
  if (isNew) return null;

  final isRecognition = direction == directionRecognition;

  if (state == fsrs.State.learning.value) {
    final isEarly = step == null || step == 0;
    if (isRecognition) {
      return isEarly ? QuizType.mc2Recognition : QuizType.mc4Recognition;
    }
    return isEarly ? QuizType.mc2Production : QuizType.mc4Production;
  }

  // Review or Relearning: strongest MVP formats.
  if (!isRecognition) {
    return QuizType.typedProduction;
  }
  final rng = random ?? Random();
  return rng.nextDouble() < reviewListeningWeight ? QuizType.listening : QuizType.mc4Recognition;
}

/// Picks a quiz format for a conjugation-rule card (§5.2: "для
/// conjugation_card -> только conj_produce / conj_identify"). §5.2 doesn't
/// say which maturity gets which of the two — this mirrors the general
/// maturity gradient used elsewhere: Learning -> conjIdentify (recognize
/// the coordinates, easier), Review/Relearning -> conjProduce (produce the
/// form, harder). Not literal spec text.
QuizType? chooseConjugationFormat({
  required bool isNew,
  required int state,
}) {
  if (isNew) return null;
  if (state == fsrs.State.learning.value) {
    return QuizType.conjIdentify;
  }
  return QuizType.conjProduce;
}
