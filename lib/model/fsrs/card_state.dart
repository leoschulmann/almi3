/// The fsrs library has no synthetic "New" state (State enum is only
/// Learning/Review/Relearning) — a card is "new" iff it has never been
/// reviewed. This is the ONE place in the codebase that determines "New".
bool isNew(int reps, DateTime? lastReview) => reps == 0 && lastReview == null;
