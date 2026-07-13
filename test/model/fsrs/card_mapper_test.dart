import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

void main() {
  group('card_mapper round-trip', () {
    test('fresh Card.create() round-trips through row conversion', () async {
      final card = await fsrs.Card.create();

      final companion = libraryCardToCardFsrsCompanion(
        card,
        cardType: 0,
        id: 1,
        reps: 0,
        lapses: 0,
        createdAt: 1000,
      );

      final row = CardFsrsTableData(
        id: companion.id.value,
        cardType: companion.cardType.value,
        due: companion.due.value,
        stability: companion.stability.value,
        difficulty: companion.difficulty.value,
        state: companion.state.value,
        step: companion.step.value,
        lastReview: companion.lastReview.present ? companion.lastReview.value : null,
        reps: companion.reps.value,
        lapses: companion.lapses.value,
        createdAt: companion.createdAt.value,
      );

      final roundTripped = cardFsrsRowToLibraryCard(row);

      expect(roundTripped.state, card.state);
      expect(roundTripped.step, card.step);
      expect(roundTripped.stability, card.stability);
      expect(roundTripped.difficulty, card.difficulty);
      expect(roundTripped.due.toUtc().millisecondsSinceEpoch ~/ 1000,
          card.due.toUtc().millisecondsSinceEpoch ~/ 1000);
      expect(roundTripped.lastReview, isNull);
      expect(card.lastReview, isNull);
    });

    test('post-review Card with stability/difficulty round-trips', () async {
      final scheduler = fsrs.Scheduler();
      final fresh = await fsrs.Card.create();
      final result = scheduler.reviewCard(fresh, fsrs.Rating.good);
      final reviewed = result.card;

      expect(reviewed.stability, isNotNull);
      expect(reviewed.difficulty, isNotNull);
      expect(reviewed.lastReview, isNotNull);

      final companion = libraryCardToCardFsrsCompanion(
        reviewed,
        cardType: 1,
        id: 2,
        reps: 1,
        lapses: 0,
        createdAt: 1000,
      );

      final row = CardFsrsTableData(
        id: companion.id.value,
        cardType: companion.cardType.value,
        due: companion.due.value,
        stability: companion.stability.value,
        difficulty: companion.difficulty.value,
        state: companion.state.value,
        step: companion.step.value,
        lastReview: companion.lastReview.present ? companion.lastReview.value : null,
        reps: companion.reps.value,
        lapses: companion.lapses.value,
        createdAt: companion.createdAt.value,
      );

      final roundTripped = cardFsrsRowToLibraryCard(row);

      expect(roundTripped.stability, reviewed.stability);
      expect(roundTripped.difficulty, reviewed.difficulty);
      expect(roundTripped.state, reviewed.state);
      expect(roundTripped.lastReview!.toUtc().millisecondsSinceEpoch ~/ 1000,
          reviewed.lastReview!.toUtc().millisecondsSinceEpoch ~/ 1000);
    });

    test('state ordinals are 1/2/3 (regression guard: no synthetic New value)', () {
      expect(fsrs.State.learning.value, 1);
      expect(fsrs.State.review.value, 2);
      expect(fsrs.State.relearning.value, 3);
      expect(fsrs.State.values.length, 3);
    });
  });
}
