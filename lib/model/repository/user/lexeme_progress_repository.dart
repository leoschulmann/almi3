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
}
