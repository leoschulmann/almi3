import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quizTypeDirection', () {
    test('niqqud/cloze/preposition are production (§5.1)', () {
      expect(quizTypeDirection(QuizType.niqqud), directionProduction);
      expect(quizTypeDirection(QuizType.cloze), directionProduction);
      expect(quizTypeDirection(QuizType.preposition), directionProduction);
    });

    test('listening is recognition (§5.1)', () {
      expect(quizTypeDirection(QuizType.listening), directionRecognition);
    });

    test('conjugation formats have no direction', () {
      expect(quizTypeDirection(QuizType.conjProduce), isNull);
      expect(quizTypeDirection(QuizType.conjIdentify), isNull);
    });
  });
}
