import 'package:almi3/model/fsrs/quiz_type.dart';

/// The raw result of one quiz answer, before grading (§5.3). [hadTypo] is
/// only meaningful for [QuizType.typedProduction] (a correct-but-misspelled
/// free-text answer) — it isn't in the spec's literal QuizResult field list,
/// added because §5.3's "correct but typo -> Hard" rule needs a signal for it.
class QuizResult {
  final QuizType quizType;
  final bool wasCorrect;
  final int responseTimeMs;
  final bool hadTypo;

  const QuizResult({
    required this.quizType,
    required this.wasCorrect,
    required this.responseTimeMs,
    this.hadTypo = false,
  });
}
