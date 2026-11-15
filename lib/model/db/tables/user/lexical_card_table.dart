import 'package:drift/drift.dart';

import 'card_fsrs_table.dart';
import 'lexeme_progress_table.dart';

// CREATE TABLE lexical_card (
//     card_id            INTEGER PRIMARY KEY REFERENCES card_fsrs(id) ON DELETE CASCADE,
//     lexeme_progress_id INTEGER NOT NULL REFERENCES lexeme_progress(id) ON DELETE CASCADE,
//     direction          INTEGER NOT NULL   -- 0=recognition, 1=production
// );
// CREATE INDEX idx_lexcard_lexeme ON lexical_card (lexeme_progress_id);
@TableIndex(name: 'idx_lexcard_lexeme', columns: {#lexemeProgressId})
class LexicalCardTable extends Table {
  IntColumn get cardId => integer().references(CardFsrsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get lexemeProgressId => integer().references(LexemeProgressTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get direction => integer()();

  @override
  Set<Column> get primaryKey => {cardId};

  @override
  String get tableName => 'lexical_card';
}
