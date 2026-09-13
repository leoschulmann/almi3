import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_state.dart' as card_state;
import 'package:flutter_test/flutter_test.dart';

CardFsrsTableData _row({required int state, int reps = 0, int? lastReview}) => CardFsrsTableData(
      id: 1,
      cardType: 0,
      due: 0,
      state: state,
      reps: reps,
      lapses: 0,
      lastReview: lastReview,
      createdAt: 0,
    );

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

  group('stateBeforeValue', () {
    test('New row (reps=0, lastReview=null) -> 0, regardless of stored state', () {
      final row = _row(state: card_state.stateBeforeLearning, reps: 0, lastReview: null);
      expect(card_state.stateBeforeValue(row), card_state.stateBeforeNew);
    });

    test('Learning row (reviewed at least once) -> row.state (1)', () {
      final row = _row(state: card_state.stateBeforeLearning, reps: 1, lastReview: 1000);
      expect(card_state.stateBeforeValue(row), card_state.stateBeforeLearning);
    });

    test('Review row -> row.state (2)', () {
      final row = _row(state: card_state.stateBeforeReview, reps: 3, lastReview: 1000);
      expect(card_state.stateBeforeValue(row), card_state.stateBeforeReview);
    });

    test('Relearning row -> row.state (3)', () {
      final row = _row(state: card_state.stateBeforeRelearning, reps: 4, lastReview: 1000);
      expect(card_state.stateBeforeValue(row), card_state.stateBeforeRelearning);
    });
  });
}
