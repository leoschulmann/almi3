import 'package:almi3/model/db/db.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';

final bookmarkRepositoryProvider =
    Provider((ref) => BookmarkRepository(ref.watch(appDatabaseProvider)));

class BookmarkRepository {
  final AppDatabase database;

  BookmarkRepository(this.database);

  // SELECT entity_id FROM bookmark_table WHERE type = ?
  Future<Set<int>> getBookmarkedIds(BookmarkType type) async {
    final rows = await (database.select(database.bookmarkTable)
          ..where((t) => t.type.equalsValue(type)))
        .get();
    return rows.map((r) => r.entityId).toSet();
  }

  Future<void> toggleBookmark(int entityId, BookmarkType type) async {
    final existing = await (database.select(database.bookmarkTable)
          ..where((t) => t.entityId.equals(entityId) & t.type.equalsValue(type)))
        .getSingleOrNull();

    if (existing != null) {
      await (database.delete(database.bookmarkTable)
            ..where((t) => t.entityId.equals(entityId) & t.type.equalsValue(type)))
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
