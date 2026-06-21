import 'package:almi3/core/enums.dart';
import 'package:drift/drift.dart';



@TableIndex(name: 'bookmark_entity_type_idx', columns: {#entityId, #type})
class BookmarkTable extends Table {
  IntColumn get entityId => integer()();
  TextColumn get type => textEnum<BookmarkType>()();
  IntColumn get bookmarkedAt => integer()();

  @override
  Set<Column> get primaryKey => {entityId, type};

  @override
  String get tableName => 'bookmark_table';
}
