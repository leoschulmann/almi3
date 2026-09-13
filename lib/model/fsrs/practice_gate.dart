import 'package:almi3/core/engine_config.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';

/// MC formats are a weak memory signal (guessing among options) — same
/// grouping grade_answer.dart uses for "never Easy" (§5.3).
bool _isWeakFormat(QuizType quizType) {
  switch (quizType) {
    case QuizType.mc2Recognition:
    case QuizType.mc4Recognition:
    case QuizType.mc2Production:
    case QuizType.mc4Production:
      return true;
    case QuizType.typedProduction:
    case QuizType.listening:
    case QuizType.conjProduce:
    case QuizType.conjIdentify:
      return false;
  }
}

/// Free-practice gate (§6.3): a practice answer only becomes a real FSRS
/// review when the card is "worthy" of it. Rule 3 (preposition ambiguity)
/// is omitted — no preposition entity type exists yet (phase 2, §13).
Future<bool> shouldCountPractice({
  required CardFsrsTableData row,
  required QuizType quizType,
  required HealthService healthService,
}) async {
  final retrievability = await healthService.cardRetrievability(row);
  if (retrievability > practiceGateRetrievabilityThreshold) return false;
  if (_isWeakFormat(quizType)) return false;
  return true;
}
