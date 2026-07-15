import 'dart:math';

import 'package:almi3/model/fsrs/choose_format.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _FixedRandom implements Random {
  final double value;
  const _FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('chooseFormat', () {
    test('isNew always returns null, regardless of state', () {
      expect(
        chooseFormat(isNew: true, state: fsrs.State.learning.value, step: 0, direction: directionRecognition),
        isNull,
      );
      expect(
        chooseFormat(isNew: true, state: fsrs.State.review.value, step: null, direction: directionProduction),
        isNull,
      );
    });

    test('early Learning -> mc2 per direction', () {
      expect(
        chooseFormat(isNew: false, state: fsrs.State.learning.value, step: 0, direction: directionRecognition),
        QuizType.mc2Recognition,
      );
      expect(
        chooseFormat(isNew: false, state: fsrs.State.learning.value, step: 0, direction: directionProduction),
        QuizType.mc2Production,
      );
    });

    test('late Learning -> mc4 per direction', () {
      expect(
        chooseFormat(isNew: false, state: fsrs.State.learning.value, step: 1, direction: directionRecognition),
        QuizType.mc4Recognition,
      );
      expect(
        chooseFormat(isNew: false, state: fsrs.State.learning.value, step: 1, direction: directionProduction),
        QuizType.mc4Production,
      );
    });

    test('Review production -> always typedProduction', () {
      expect(
        chooseFormat(isNew: false, state: fsrs.State.review.value, step: null, direction: directionProduction),
        QuizType.typedProduction,
      );
      expect(
        chooseFormat(isNew: false, state: fsrs.State.relearning.value, step: 0, direction: directionProduction),
        QuizType.typedProduction,
      );
    });

    test('Review recognition -> both mc4Recognition and listening reachable', () {
      expect(
        chooseFormat(
          isNew: false,
          state: fsrs.State.review.value,
          step: null,
          direction: directionRecognition,
          random: const _FixedRandom(0.0),
        ),
        QuizType.listening,
      );
      expect(
        chooseFormat(
          isNew: false,
          state: fsrs.State.review.value,
          step: null,
          direction: directionRecognition,
          random: const _FixedRandom(0.99),
        ),
        QuizType.mc4Recognition,
      );
    });
  });
}
