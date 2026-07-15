import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lexemeProgressRepositoryProvider =
    Provider((ref) => LexemeProgressRepository(ref.watch(userDbProvider)));

/// CRUD-only access to lexeme_progress. No business logic here.
class LexemeProgressRepository {
  final UserDatabase database;

  LexemeProgressRepository(this.database);

  // INSERT INTO lexeme_progress (...) VALUES (...)
  Future<int> insert(LexemeProgressTableCompanion companion) {
    return database.into(database.lexemeProgressTable).insert(companion);
  }

  // SELECT * FROM lexeme_progress WHERE entity_type = ? AND entity_id = ?
  Future<LexemeProgressTableData?> getByEntity(int entityType, int entityId) {
    return (database.select(database.lexemeProgressTable)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId)))
        .getSingleOrNull();
  }

  // UPDATE lexeme_progress SET status = ?, updated_at = ? WHERE id = ?
  Future<void> updateStatus(int id, int status, int updatedAt) {
    return (database.update(database.lexemeProgressTable)..where((t) => t.id.equals(id))).write(
      LexemeProgressTableCompanion(
        status: Value(status),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  // SELECT entity_id FROM lexeme_progress WHERE entity_type = ?
  Future<List<int>> getStartedEntityIds(int entityType) async {
    final rows = await (database.selectOnly(database.lexemeProgressTable)
          ..addColumns([database.lexemeProgressTable.entityId])
          ..where(database.lexemeProgressTable.entityType.equals(entityType)))
        .get();
    return rows.map((r) => r.read(database.lexemeProgressTable.entityId)!).toList();
  }

  // SELECT COUNT(*) FROM lexeme_progress WHERE first_seen_at >= ?
  Future<int> countIntroducedSince(int unixSec) async {
    final countExp = database.lexemeProgressTable.id.count();
    final query = database.selectOnly(database.lexemeProgressTable)
      ..addColumns([countExp])
      ..where(database.lexemeProgressTable.firstSeenAt.isBiggerOrEqualValue(unixSec));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }
}
