/// quiz_type enum (§5.1). Only MVP formats are implemented (mc2/mc4
/// recognition+production, typed_production, listening, conj_produce,
/// conj_identify); the remaining spec values (niqqud, cloze, preposition)
/// are reserved but not yet used anywhere in the codebase.
enum QuizType {
  mc2Recognition(0),
  mc4Recognition(1),
  mc2Production(2),
  mc4Production(3),
  typedProduction(4),
  // 5 = niqqud       -- reserved, not MVP
  // 6 = cloze         -- reserved, not MVP
  listening(7),
  // 8 = preposition  -- reserved, not MVP
  conjProduce(9),
  conjIdentify(10),
  ;

  final int value;
  const QuizType(this.value);
}

/// lexical_card.direction / answer direction (§3.1, §5.1): 0=recognition,
/// 1=production. Direction of a QUIZ ANSWER is derived from quiz_type here
/// — it is not stored separately (only the CARD's direction is stored).
const int directionRecognition = 0;
const int directionProduction = 1;

/// Null for conj_produce/conj_identify — conjugation cards have no
/// recognition/production direction (§5.1's table marks their direction
/// column "(спряжение)", not recognition/production).
int? quizTypeDirection(QuizType quizType) {
  switch (quizType) {
    case QuizType.mc2Recognition:
    case QuizType.mc4Recognition:
    case QuizType.listening:
      return directionRecognition;
    case QuizType.mc2Production:
    case QuizType.mc4Production:
    case QuizType.typedProduction:
      return directionProduction;
    case QuizType.conjProduce:
    case QuizType.conjIdentify:
      return null;
  }
}
