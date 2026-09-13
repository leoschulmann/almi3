import 'package:almi3/model/db/user_db.dart';

/// answer_log.state_before values (§12).
const int stateBeforeNew = 0;
const int stateBeforeLearning = 1;
const int stateBeforeReview = 2;
const int stateBeforeRelearning = 3;

/// The fsrs library has no synthetic "New" state (State enum is only
/// Learning/Review/Relearning) — a card is "new" iff it has never been
/// reviewed. This is the ONE place in the codebase that determines "New".
bool isNew(int reps, DateTime? lastReview) => reps == 0 && lastReview == null;

/// answer_log.state_before encoding (§12): unlike card_fsrs.state, this
/// captures a HISTORICAL fact ("what was the card's state right before
/// this answer"), and New really did happen at some point in that history
/// — so it gets a real value here (0), unlike card_fsrs.state where New is
/// purely derived and never stored.
int stateBeforeValue(CardFsrsTableData row) =>
    isNew(row.reps, row.lastReview != null ? DateTime.fromMillisecondsSinceEpoch(row.lastReview! * 1000) : null)
        ? 0
        : row.state;
