import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:drift/drift.dart';

import '../sync_result.dart';

class RootRepository {
  final AppDatabase database;

  RootRepository(this.database);

  Future<void> insertRoot(RootDto dto) async {
    await database
        .into(database.rootTable)
        .insert(RootTableCompanion(id: Value(dto.id), value: Value(dto.value), version: Value(dto.version)));
  }

  Future<List<RootDto>> getRootsPaged(int page, int size) async {
    try {
      logger.d('getRootsPaged: page=$page, size=$size');
      final List<RootTableData> future = await (database.select(
        database.rootTable,
      )..limit(size, offset: page * size)).get();

      logger.i('getRootsPaged: fetched ${future.length} items from database');
      final result = future.map((data) => RootDto(id: data.id, value: data.value, version: data.version)).toList();
      logger.d('getRootsPaged: converted to ${result.length} DTOs');
      return result;
    } catch (e, stackTrace) {
      logger.e('getRootsPaged: ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Upsert a batch of roots with version checking logic
  /// Fetches all IDs from DB first, then determines what to do
  Future<SyncResult> upsertBatch(List<RootDto> batch) async {
    try {
      Map<int, RootTableData> existingMap = await _getExistingAsMap(batch);

      final toInsert = <RootTableCompanion>[];
      final toUpdate = <RootTableCompanion>[];
      // todo add toDelete

      int inserted = 0;
      int updated = 0;
      int skipped = 0;

      for (final RootDto apiRoot in batch) {
        final RootTableData? existing = existingMap[apiRoot.id];

        if (existing == null) {
          // Root doesn't exist - MARK FOR INSERT
          toInsert.add(
            RootTableCompanion(id: Value(apiRoot.id), value: Value(apiRoot.value), version: Value(apiRoot.version)),
          );
          inserted++;
          logger.d('Upsert: will insert root id=${apiRoot.id}, value=${apiRoot.value}');
        } else if (apiRoot.version > existing.version) {
          // Root exists but backend version is newer - MARK FOR UPDATE
          toUpdate.add(
            RootTableCompanion(id: Value(apiRoot.id), value: Value(apiRoot.value), version: Value(apiRoot.version)),
          );
          updated++;
          logger.d('Upsert: will update root id=${apiRoot.id}, version ${existing.version} -> ${apiRoot.version}');
        } else {
          // Root exists and local version is same or newer - SKIP
          skipped++;
          logger.d(
            'Upsert: will skip root id=${apiRoot.id}, local version=${existing.version} >= backend version=${apiRoot.version}',
          );
        }
      }

      if (toInsert.isNotEmpty) {
        logger.d('Batch inserting ${toInsert.length} roots');
        await database.batch((batch) {
          batch.insertAll(database.rootTable, toInsert);
        });
      }

      if (toUpdate.isNotEmpty) {
        logger.d('Batch updating ${toUpdate.length} roots');
        for (final companion in toUpdate) {
          await database.update(database.rootTable).replace(companion);
        }
      }

      logger.i('Batch complete: inserted=$inserted, updated=$updated, skipped=$skipped');
      return SyncResult(inserted: inserted, updated: updated, skipped: skipped);
    } catch (e, stackTrace) {
      logger.e('Error in _upsertBatch', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<int, RootTableData>> _getExistingAsMap(List<RootDto> batch) async {
    // Get IDs of all roots in this batch
    final batchIds = batch.map((r) => r.id).toList();

    // Fetch ALL existing roots with these IDs from database in one query
    final List<RootTableData> existingRoots = await (database.select(
      database.rootTable,
    )..where((t) => t.id.isIn(batchIds))).get();

    // Create a map for quick lookup: id -> existing root
    return {for (final root in existingRoots) root.id: root};
  }
}
