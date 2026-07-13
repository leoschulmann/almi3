import 'package:drift/drift.dart';

// CREATE TABLE card_fsrs (
//     id           INTEGER PRIMARY KEY,
//     card_type    INTEGER NOT NULL,   -- discriminator: 0=lexical, 1=conjugation, (2=mishkal...)
//     due          INTEGER NOT NULL,   -- unix sec; main index
//     stability    REAL,               -- null until first review
//     difficulty   REAL,
//     state        INTEGER NOT NULL,   -- 1=Learning 2=Review 3=Relearning (fsrs library ordinal; no synthetic 'New' value)
//     step         INTEGER,            -- learning/relearning step
//     last_review  INTEGER,            -- unix sec, null until first review
//     reps         INTEGER NOT NULL DEFAULT 0,
//     lapses       INTEGER NOT NULL DEFAULT 0,
//     created_at   INTEGER NOT NULL
// );
// CREATE INDEX idx_cardfsrs_due   ON card_fsrs (due);
// CREATE INDEX idx_cardfsrs_state ON card_fsrs (state);
@TableIndex(name: 'idx_cardfsrs_due', columns: {#due})
@TableIndex(name: 'idx_cardfsrs_state', columns: {#state})
class CardFsrsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardType => integer()();
  IntColumn get due => integer()();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  IntColumn get state => integer()();
  IntColumn get step => integer().nullable()();
  IntColumn get lastReview => integer().nullable()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  String get tableName => 'card_fsrs';
}
