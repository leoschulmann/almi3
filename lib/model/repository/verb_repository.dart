import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_dto.dart';
import 'package:almi3/model/repository/generic_repo.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbRepository extends GenericRepository<VerbSyncDto, VerbTableData, VerbTableCompanion> {
  final AppDatabase database;

  VerbRepository(this.database);

  @override
  VerbTableCompanion createCompanion(VerbSyncDto dto) {
    return VerbTableCompanion(
      id: Value(dto.id),
      value: Value(dto.value),
      version: Value(dto.version),
      rootId: Value(dto.rootId),
      binyanId: Value(dto.binyanId),
    );
  }

  @override
  Future<void> executeBatchInsert(List<VerbTableCompanion> companions) async =>
      database.batch((Batch batch) => batch.insertAll(database.verbTable, companions));

  @override
  Future<void> executeBatchUpdate(List<VerbTableCompanion> companions) async =>
      database.batch((batch) => batch.replaceAll(database.verbTable, companions));

  @override
  Future<List<VerbTableData>> fetchExistingByIds(List<int> ids) async {
    return await (database.select(database.verbTable)..where((table) => table.id.isIn(ids))).get();
  }

  @override
  int getDataId(VerbTableData data) => data.id;

  @override
  int getDtoId(VerbSyncDto dto) => dto.id;

  @override
  int getDtoVersion(VerbSyncDto dto) => dto.version;

  @override
  int getExistingVersion(VerbTableData existing) => existing.version;

  Future<SyncResult> upsertVerbs(List<VerbSyncDto> apiBatch) async {
    return upsertBatch(apiBatch);
  }
}
