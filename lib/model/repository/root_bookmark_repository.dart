import 'package:almi3/model/db/db.dart';
import 'package:drift/drift.dart';

class RootBookmarkRepository {
  final AppDatabase database;

  RootBookmarkRepository(this.database);

  Future<Set<int>> getBookmarkedRootIds() async {
    final List<RootBookmarkTableData> rows = await database.select(database.rootBookmarkTable).get();
    return rows.map((r) => r.rootId).toSet();
  }

  Future<bool> toggleBookmark(int rootId) async {
    final RootBookmarkTableData? existing = await (database.select(database.rootBookmarkTable)
          ..where((t) => t.rootId.equals(rootId)))
        .getSingleOrNull();

    if (existing != null) {
      await (database.delete(database.rootBookmarkTable)
            ..where((t) => t.rootId.equals(rootId)))
          .go();
      return false;
    } else {
      await database.into(database.rootBookmarkTable).insert(
            RootBookmarkTableCompanion(
              rootId: Value(rootId),
              bookmarkedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      return true;
    }
  }
}
