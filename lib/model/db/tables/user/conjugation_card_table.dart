import 'package:drift/drift.dart';

import 'card_fsrs_table.dart';

// CREATE TABLE conjugation_card (
//     card_id    INTEGER PRIMARY KEY REFERENCES card_fsrs(id) ON DELETE CASCADE,
//     binyan_id  INTEGER NOT NULL,  -- soft-ref content.binyan_table
//     gizrah_id  INTEGER,           -- soft-ref content.gizrah_table; NULL = general pool (regular verbs)
//     tense      INTEGER NOT NULL,  -- same encoding as content.verb_form_table
//     person     INTEGER NOT NULL,
//     plurality  INTEGER NOT NULL,
//     gender     INTEGER NOT NULL
// );
// CREATE INDEX idx_conjcard_slot ON conjugation_card (binyan_id, gizrah_id);
@TableIndex(name: 'idx_conjcard_slot', columns: {#binyanId, #gizrahId})
class ConjugationCardTable extends Table {
  IntColumn get cardId => integer().references(CardFsrsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get binyanId => integer()();
  IntColumn get gizrahId => integer().nullable()();
  IntColumn get tense => integer()();
  IntColumn get person => integer()();
  IntColumn get plurality => integer()();
  IntColumn get gender => integer()();

  @override
  Set<Column> get primaryKey => {cardId};

  @override
  String get tableName => 'conjugation_card';
}
