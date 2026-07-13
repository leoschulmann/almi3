import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';

final bookmarkRepositoryProvider =
    Provider((ref) => BookmarkRepository(ref.watch(userDbProvider)));

class BookmarkRepository {
  final UserDatabase database;

  BookmarkRepository(this.database);

  // SELECT entity_id FROM bookmark_table WHERE type = ?
  Future<Set<int>> getBookmarkedIds(BookmarkType type) async {
    final rows = await (database.select(database.bookmarkTable)
          ..where((t) => t.type.equals(type.index)))
        .get();
    return rows.map((r) => r.entityId).toSet();
  }

  // SELECT * FROM bookmark_table WHERE entity_id = ? AND type = ?
  Future<void> toggleBookmark(int entityId, BookmarkType type) async {
    final existing = await (database.select(database.bookmarkTable)
          ..where((t) => t.entityId.equals(entityId) & t.type.equals(type.index)))
        .getSingleOrNull();

    if (existing != null) {
      // DELETE FROM bookmark_table WHERE entity_id = ? AND type = ?
      await (database.delete(database.bookmarkTable)
            ..where((t) => t.entityId.equals(entityId) & t.type.equals(type.index)))
          .go();
    } else {
      // INSERT INTO bookmark_table (entity_id, type, bookmarked_at) VALUES (?, ?, ?)
      await database.into(database.bookmarkTable).insert(
            BookmarkTableCompanion(
              entityId: Value(entityId),
              type: Value(type.index),
              bookmarkedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
    }
  }
}
