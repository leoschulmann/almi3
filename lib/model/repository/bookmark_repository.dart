import 'package:almi3/model/db/db.dart';
import 'package:drift/drift.dart';

import '../../core/enums.dart';

class BookmarkRepository {
  final AppDatabase database;

  BookmarkRepository(this.database);

  // SELECT entity_id FROM bookmark_table WHERE type = ?
  Future<Set<int>> getBookmarkedIds(BookmarkType type) async {
    final rows = await (database.select(database.bookmarkTable)
          ..where((t) => t.type.equals(type.name)))
        .get();
    return rows.map((r) => r.entityId).toSet();
  }

  Future<void> toggleBookmark(int entityId, BookmarkType type) async {
    final existing = await (database.select(database.bookmarkTable)
          ..where((t) => t.entityId.equals(entityId) & t.type.equals(type.name)))
        .getSingleOrNull();

    if (existing != null) {
      await (database.delete(database.bookmarkTable)
            ..where((t) => t.entityId.equals(entityId) & t.type.equals(type.name)))
          .go();
    } else {
      await database.into(database.bookmarkTable).insert(
            BookmarkTableCompanion(
              entityId: Value(entityId),
              type: Value(type),
              bookmarkedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
    }
  }
}
