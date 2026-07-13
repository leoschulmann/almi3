import 'package:drift/drift.dart';

// CREATE TABLE bookmark_table (
//     entity_id     INTEGER NOT NULL,  -- soft-ref
//     type          INTEGER NOT NULL,  -- see core/enums.dart BookmarkType.index
//     bookmarked_at INTEGER NOT NULL,
//     PRIMARY KEY (entity_id, type)
// );
class BookmarkTable extends Table {
  IntColumn get entityId => integer()();
  IntColumn get type => integer()();
  IntColumn get bookmarkedAt => integer()();

  @override
  Set<Column> get primaryKey => {entityId, type};

  @override
  String get tableName => 'bookmark_table';
}
