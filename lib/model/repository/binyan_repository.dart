import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/binyan_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

import 'generic_repo.dart';

class BinyanRepository extends GenericRepository<BinyanDto, BinyanTableData, BinyanTableCompanion> {
  final AppDatabase database;

  BinyanRepository({required this.database});

  @override
  int getDtoId(BinyanDto dto) => dto.id;

  @override
  int getDataId(BinyanTableData data) => data.id;
  
  @override
  int getDtoVersion(BinyanDto dto) => dto.version;

  @override
  int getExistingVersion(BinyanTableData existing) => existing.version;

  @override
  BinyanTableCompanion createCompanion(BinyanDto dto) =>
      BinyanTableCompanion(id: Value(dto.id), value: Value(dto.value), version: Value(dto.version));

  @override
  Future<void> executeBatchInsert(List<BinyanTableCompanion> companions) async {
    await database.batch((batch) => batch.insertAll(database.binyanTable, companions));
  }

  @override
  Future<void> executeBatchUpdate(List<BinyanTableCompanion> companions) async {
    await database.batch((batch) => batch.replaceAll(database.binyanTable, companions));
  }

  @override
  Future<List<BinyanTableData>> fetchExistingByIds(List<int> ids) async {
    return await (database.select(database.binyanTable)..where((tbl) => tbl.id.isIn(ids))).get();
  }

  Future<SyncResult> upsertBinyans(List<BinyanDto> list) async {
    return await upsertBatch(list);
  }
}
