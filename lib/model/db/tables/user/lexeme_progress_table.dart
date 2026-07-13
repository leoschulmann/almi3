import 'package:drift/drift.dart';

// CREATE TABLE lexeme_progress (
//     id            INTEGER PRIMARY KEY,
//     entity_type   INTEGER NOT NULL,  -- 0=verb (later 1=noun 2=adj 3=prep)
//     entity_id     INTEGER NOT NULL,  -- soft-ref content.db
//     status        INTEGER NOT NULL,  -- 0=active 1=known 2=ignored
//     first_seen_at INTEGER,
//     created_at    INTEGER NOT NULL,
//     updated_at    INTEGER NOT NULL,
//     UNIQUE (entity_type, entity_id)
// );
// CREATE INDEX idx_lexprog_status ON lexeme_progress (status);
@TableIndex(name: 'idx_lexprog_status', columns: {#status})
@TableIndex(name: 'idx_lexprog_entity_unique', columns: {#entityType, #entityId}, unique: true)
class LexemeProgressTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entityType => integer()();
  IntColumn get entityId => integer()();
  IntColumn get status => integer()();
  IntColumn get firstSeenAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  String get tableName => 'lexeme_progress';
}
