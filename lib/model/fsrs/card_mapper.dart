import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// Pure mapping functions between the fsrs library's [fsrs.Card] and the
/// card_fsrs table row. Handles DateTime<->unix-seconds-UTC conversion
/// explicitly. The library's Card.cardId is never persisted — the row's
/// own autoincrement `id` is the authoritative primary key.

DateTime _fromUnixSec(int unixSec) => DateTime.fromMillisecondsSinceEpoch(unixSec * 1000, isUtc: true);

int _toUnixSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;

/// Converts a card_fsrs row into a library [fsrs.Card]. The row's `id` is
/// used as the library card's cardId only for in-memory identification
/// during the review call; it must never be written back to storage.
fsrs.Card cardFsrsRowToLibraryCard(CardFsrsTableData row) {
  return fsrs.Card(
    cardId: row.id,
    state: fsrs.State.fromValue(row.state),
    step: row.step,
    stability: row.stability,
    difficulty: row.difficulty,
    due: _fromUnixSec(row.due),
    lastReview: row.lastReview != null ? _fromUnixSec(row.lastReview!) : null,
  );
}

/// Converts a library [fsrs.Card] into a card_fsrs companion suitable for
/// insert (when [id] is null) or update (when [id] is provided).
CardFsrsTableCompanion libraryCardToCardFsrsCompanion(
  fsrs.Card card, {
  required int cardType,
  int? id,
  int? reps,
  int? lapses,
  int? createdAt,
}) {
  return CardFsrsTableCompanion(
    id: id != null ? Value(id) : const Value.absent(),
    cardType: Value(cardType),
    due: Value(_toUnixSec(card.due)),
    stability: Value(card.stability),
    difficulty: Value(card.difficulty),
    state: Value(card.state.value),
    step: Value(card.step),
    lastReview: card.lastReview != null ? Value(_toUnixSec(card.lastReview!)) : const Value.absent(),
    reps: reps != null ? Value(reps) : const Value.absent(),
    lapses: lapses != null ? Value(lapses) : const Value.absent(),
    createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
  );
}

/// Full-column companion that restores a card_fsrs row to an exact prior
/// snapshot (every field explicit, including nulls). Distinct from
/// [libraryCardToCardFsrsCompanion]: that one derives a row from a library
/// [fsrs.Card] after a real review; this one is for undo (§10's "I know"
/// rollback), which must restore the row byte-for-byte, not re-derive it.
CardFsrsTableCompanion cardFsrsRowToFullCompanion(CardFsrsTableData row) {
  return CardFsrsTableCompanion(
    id: Value(row.id),
    cardType: Value(row.cardType),
    due: Value(row.due),
    stability: Value(row.stability),
    difficulty: Value(row.difficulty),
    state: Value(row.state),
    step: Value(row.step),
    lastReview: Value(row.lastReview),
    reps: Value(row.reps),
    lapses: Value(row.lapses),
    createdAt: Value(row.createdAt),
  );
}
