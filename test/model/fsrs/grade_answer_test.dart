import 'package:almi3/model/fsrs/grade_answer.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gradeAnswer', () {
    test('any incorrect answer -> Again, regardless of format', () {
      for (final qt in QuizType.values) {
        final result = QuizResult(quizType: qt, wasCorrect: false, responseTimeMs: 1);
        expect(gradeAnswer(result), ratingAgain, reason: qt.name);
      }
    });

    group('typed_production (full scale)', () {
      test('correct + typo -> Hard', () {
        final r = QuizResult(
          quizType: QuizType.typedProduction,
          wasCorrect: true,
          responseTimeMs: 500,
          hadTypo: true,
        );
        expect(gradeAnswer(r), ratingHard);
      });

      test('correct + fast -> Easy', () {
        final r = QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 100);
        expect(gradeAnswer(r), ratingEasy);
      });

      test('correct + slow -> Hard', () {
        final r = QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 20000);
        expect(gradeAnswer(r), ratingHard);
      });

      test('correct + normal speed -> Good', () {
        final r = QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 5000);
        expect(gradeAnswer(r), ratingGood);
      });
    });

    group('MC formats (weak signal): never Easy', () {
      for (final qt in [
        QuizType.mc2Recognition,
        QuizType.mc4Recognition,
        QuizType.mc2Production,
        QuizType.mc4Production,
      ]) {
        test('${qt.name}: correct + fast -> Good (never Easy)', () {
          final r = QuizResult(quizType: qt, wasCorrect: true, responseTimeMs: 1);
          expect(gradeAnswer(r), ratingGood);
        });

        test('${qt.name}: correct + slow -> Hard', () {
          final r = QuizResult(quizType: qt, wasCorrect: true, responseTimeMs: 100000);
          expect(gradeAnswer(r), ratingHard);
        });
      }
    });

    group('listening (medium signal)', () {
      test('correct + fast -> Easy', () {
        final r = QuizResult(quizType: QuizType.listening, wasCorrect: true, responseTimeMs: 100);
        expect(gradeAnswer(r), ratingEasy);
      });

      test('correct + slow -> Hard', () {
        final r = QuizResult(quizType: QuizType.listening, wasCorrect: true, responseTimeMs: 100000);
        expect(gradeAnswer(r), ratingHard);
      });

      test('correct + normal speed -> Good', () {
        final r = QuizResult(quizType: QuizType.listening, wasCorrect: true, responseTimeMs: 6000);
        expect(gradeAnswer(r), ratingGood);
      });
    });

    group('conjugation formats (full scale, like typed_production)', () {
      for (final qt in [QuizType.conjProduce, QuizType.conjIdentify]) {
        test('${qt.name}: correct + typo -> Hard', () {
          final r = QuizResult(quizType: qt, wasCorrect: true, responseTimeMs: 500, hadTypo: true);
          expect(gradeAnswer(r), ratingHard);
        });

        test('${qt.name}: correct + fast -> Easy', () {
          final r = QuizResult(quizType: qt, wasCorrect: true, responseTimeMs: 100);
          expect(gradeAnswer(r), ratingEasy);
        });

        test('${qt.name}: correct + slow -> Hard', () {
          final r = QuizResult(quizType: qt, wasCorrect: true, responseTimeMs: 20000);
          expect(gradeAnswer(r), ratingHard);
        });

        test('${qt.name}: correct + normal speed -> Good', () {
          final r = QuizResult(quizType: qt, wasCorrect: true, responseTimeMs: 5000);
          expect(gradeAnswer(r), ratingGood);
        });
      }
    });
  });
}
