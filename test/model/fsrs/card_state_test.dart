import 'package:almi3/model/fsrs/card_state.dart' as card_state;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNew', () {
    test('true when reps==0 and lastReview==null', () {
      expect(card_state.isNew(0, null), isTrue);
    });

    test('false when reps > 0', () {
      expect(card_state.isNew(1, null), isFalse);
    });

    test('false when lastReview is set', () {
      expect(card_state.isNew(0, DateTime.now()), isFalse);
    });

    test('false when both reps > 0 and lastReview set', () {
      expect(card_state.isNew(3, DateTime.now()), isFalse);
    });
  });
}
