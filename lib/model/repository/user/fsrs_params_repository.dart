import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fsrsParamsRepositoryProvider =
    Provider((ref) => FsrsParamsRepository(ref.watch(userDbProvider)));

/// CRUD-only access to fsrs_params. No business logic here.
class FsrsParamsRepository {
  final UserDatabase database;

  FsrsParamsRepository(this.database);

  // INSERT INTO fsrs_params (...) VALUES (...)
  Future<int> insert(FsrsParamsTableCompanion companion) {
    return database.into(database.fsrsParamsTable).insert(companion);
  }

  // SELECT * FROM fsrs_params ORDER BY version DESC LIMIT 1
  Future<FsrsParamsTableData?> getLatest() {
    return (database.select(database.fsrsParamsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.version)])
          ..limit(1))
        .getSingleOrNull();
  }
}
