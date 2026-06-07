import 'package:drift/drift.dart';

@TableIndex(name: 'root_bookmark_root_id_idx', columns: {#rootId})
class RootBookmarkTable extends Table {
  IntColumn get rootId => integer()();
  IntColumn get bookmarkedAt => integer()();

  @override
  Set<Column> get primaryKey => {rootId};

  @override
  String get tableName => 'root_bookmark_table';
}
