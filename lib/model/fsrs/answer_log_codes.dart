/// answer_log.source (§4). `assertKnown` is an extension beyond the spec's
/// literal 0/1 — needed for the "I know" action (§10), which is neither a
/// scheduled review nor free practice. Comment-documented, not CHECK-
/// enforced, so this doesn't touch table structure.
const int answerSourceScheduled = 0;
const int answerSourcePractice = 1;
const int answerSourceAssertKnown = 2;

/// answer_log.quiz_type marker for rows that aren't a real quiz answer (the
/// "I know" action, §10) — deliberately outside the spec's 0-10 catalog
/// (§5.1) so it can never be mistaken for a real format.
const int quizTypeNoOp = -1;
