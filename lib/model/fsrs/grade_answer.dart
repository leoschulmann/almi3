import 'package:almi3/core/engine_config.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';

/// Rating values (§5.3, §6.1) — matches fsrs.Rating's 1..4 encoding exactly,
/// kept as plain ints here since this is the boundary where the app's answer
/// model turns into the library's Rating right before scheduler.reviewCard.
const int ratingAgain = 1;
const int ratingHard = 2;
const int ratingGood = 3;
const int ratingEasy = 4;

/// The single place a user's answer becomes an FSRS rating (§5.3). Pure
/// function — no side effects, no FSRS/db access.
int gradeAnswer(QuizResult result) {
  if (!result.wasCorrect) return ratingAgain;

  switch (result.quizType) {
    case QuizType.typedProduction:
    case QuizType.conjProduce:
    case QuizType.conjIdentify:
      // Free input / an operation, not guessing (§5.3): full scale, same as
      // typed_production for both conjugation formats.
      if (result.hadTypo) return ratingHard;
      if (result.responseTimeMs < typedProductionFastMs) return ratingEasy;
      if (result.responseTimeMs > typedProductionSlowMs) return ratingHard;
      return ratingGood;

    case QuizType.mc2Recognition:
    case QuizType.mc4Recognition:
    case QuizType.mc2Production:
    case QuizType.mc4Production:
      // Weak signal (guessing): never Easy.
      return result.responseTimeMs > mcSlowMs ? ratingHard : ratingGood;

    case QuizType.listening:
      // Medium signal: Easy only on a fast, unambiguous correct answer.
      if (result.responseTimeMs < listeningFastMs) return ratingEasy;
      if (result.responseTimeMs > listeningSlowMs) return ratingHard;
      return ratingGood;
  }
}
