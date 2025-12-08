import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

import 'generic_repo.dart';

class RootRepository extends GenericRepository<RootDto, RootTableData, RootTableCompanion> {
  final AppDatabase database;

  RootRepository(this.database);

  @override
  int getDtoId(RootDto dto) => dto.id;

  @override
  int getDataId(RootTableData data) => data.id;

  @override
  int getDtoVersion(RootDto dto) => dto.version;

  @override
  int getExistingVersion(RootTableData existing) => existing.version;

  @override
  RootTableCompanion createCompanion(RootDto dto) =>
      RootTableCompanion(id: Value(dto.id), value: Value(dto.value), version: Value(dto.version));

  @override
  Future<void> executeBatchInsert(List<RootTableCompanion> companions) async {
    await database.batch((batch) {
      batch.insertAll(database.rootTable, companions);
    });
  }

  @override
  Future<void> executeBatchUpdate(List<RootTableCompanion> companions) async {
    for (final companion in companions) {
      await database.update(database.rootTable).replace(companion);
    }
  }

  @override
  Future<List<RootTableData>> fetchExistingByIds(List<int> ids) async {
    return await (database.select(database.rootTable)
      ..where((t) => t.id.isIn(ids))).get();
  }

  /// Upsert a batch of roots with version checking logic
  Future<SyncResult> upsertRoots(List<RootDto> batch) async {
    return await upsertBatch(batch);
  }

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
      )
        ..limit(size, offset: page * size)).get();

      logger.i('getRootsPaged: fetched ${future.length} items from database');
      final result = future.map((data) => RootDto(id: data.id, value: data.value, version: data.version)).toList();
      logger.d('getRootsPaged: converted to ${result.length} DTOs');
      return result;
    } catch (e, stackTrace) {
      logger.e('getRootsPaged: ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
