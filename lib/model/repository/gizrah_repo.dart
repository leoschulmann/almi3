import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/gizrah_dto.dart';
import 'package:almi3/model/dto/prep_dto.dart';
import 'package:almi3/model/repository/generic_repo.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class GizrahRepository extends GenericRepository<GizrahDto, GizrahTableData, GizrahTableCompanion> {
  final AppDatabase database;

  GizrahRepository({required this.database});


  @override
  GizrahTableCompanion createCompanion(GizrahDto dto) {
    return GizrahTableCompanion(id: Value(dto.id), value: Value(dto.value), version: Value(dto.version));
  }

  @override
  Future<void> executeBatchInsert(List<GizrahTableCompanion> companions) async {
    await database.batch((batch) {
      batch.insertAll(database.gizrahTable, companions);
    });
  }

  @override
  Future<void> executeBatchUpdate(List<GizrahTableCompanion> companions) async {
    await database.batch((batch) => batch.replaceAll(database.gizrahTable, companions));
  }

  @override
  Future<List<GizrahTableData>> fetchExistingByIds(List<int> ids) async {
    return await (database.select(database.gizrahTable)..where((tbl) => tbl.id.isIn(ids))).get();
  }

  @override
  int getDtoId(GizrahDto dto) => dto.id;
  
  @override
  int getDataId(GizrahTableData data) => data.id;
  
  @override
  int getDtoVersion(GizrahDto dto) => dto.version;

  @override
  int getExistingVersion(GizrahTableData existing) => existing.version;
  
  Future<SyncResult> upsertGizrah(List<GizrahDto> preps) async {
    return await upsertBatch(preps);
  }
}
