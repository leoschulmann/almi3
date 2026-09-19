import 'dart:convert';

import 'package:almi3/core/clock.dart';
import 'package:almi3/core/engine_config.dart';
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

  /// Snapshots [desiredRetention] into a new fsrs_params row -- the only
  /// legal way to record an intensity change (§4.1). No-op if it equals
  /// getLatest()'s value; if getLatest() is null, inserts with the default
  /// params_json. Shared by onboarding's initial insert and later Settings
  /// changes so there is exactly one place that decides "did this change".
  Future<void> snapshotIfChanged(double desiredRetention) async {
    await database.transaction(() async {
      final latest = await getLatest();
      if (latest != null && latest.desiredRetention == desiredRetention) {
        return;
      }
      await insert(
        FsrsParamsTableCompanion.insert(
          paramsJson: latest != null ? latest.paramsJson : jsonEncode(defaultFsrsWeights),
          desiredRetention: desiredRetention,
          createdAt: nowUtcSeconds(),
          note: latest != null ? const Value('intensity-change') : const Value('default'),
        ),
      );
    });
  }
}
