import 'package:drift/drift.dart';

// CREATE TABLE answer_log (
//     id                  INTEGER PRIMARY KEY,
//     card_id             INTEGER NOT NULL,  -- ref card_fsrs (no CASCADE: log outlives card)
//     answered_at         INTEGER NOT NULL,
//     source              INTEGER NOT NULL,  -- 0=scheduled, 1=practice
//     counted_in_fsrs     INTEGER NOT NULL,  -- bool: went through reviewCard?
//     rating              INTEGER,           -- 1..4, null if ungraded
//     was_correct         INTEGER NOT NULL,  -- bool, before rating mapping
//     quiz_type           INTEGER NOT NULL,
//     response_time_ms    INTEGER,
//     shown_verb_id       INTEGER,           -- soft-ref
//     fsrs_params_version INTEGER NOT NULL
// );
// CREATE INDEX idx_answerlog_card ON answer_log (card_id, answered_at);
// CREATE INDEX idx_answerlog_time ON answer_log (answered_at);
@TableIndex(name: 'idx_answerlog_card', columns: {#cardId, #answeredAt})
@TableIndex(name: 'idx_answerlog_time', columns: {#answeredAt})
class AnswerLogTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  // No FK/CASCADE: the answer log must outlive the card_fsrs row it references.
  IntColumn get cardId => integer()();
  IntColumn get answeredAt => integer()();
  IntColumn get source => integer()();
  BoolColumn get countedInFsrs => boolean()();
  IntColumn get rating => integer().nullable()();
  BoolColumn get wasCorrect => boolean()();
  IntColumn get quizType => integer()();
  IntColumn get responseTimeMs => integer().nullable()();
  IntColumn get shownVerbId => integer().nullable()();
  IntColumn get fsrsParamsVersion => integer()();

  @override
  String get tableName => 'answer_log';
}
