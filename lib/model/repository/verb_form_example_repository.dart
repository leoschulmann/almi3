import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_form_example_simple_dto.dart';
import 'package:almi3/model/repository/generic_repo.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbFormExampleRepository
    extends GenericRepository<VerbFormExampleSimpleDto, VerbFormExampleTableData, VerbFormExampleTableCompanion> {
  final AppDatabase database;

  VerbFormExampleRepository(this.database);

  @override
  VerbFormExampleTableCompanion createCompanion(VerbFormExampleSimpleDto dto) => VerbFormExampleTableCompanion(
        id: Value(dto.id),
        verbFormId: Value(dto.verbFormId),
        value: Value(dto.value),
        file: Value(dto.file),
        version: Value(dto.version),
      );

  @override
  Future<void> executeBatchInsert(List<VerbFormExampleTableCompanion> companions) async =>
      database.batch((b) => b.insertAll(database.verbFormExampleTable, companions));

  @override
  Future<void> executeBatchUpdate(List<VerbFormExampleTableCompanion> companions) async =>
      database.batch((b) => b.replaceAll(database.verbFormExampleTable, companions));

  @override
  Future<List<VerbFormExampleTableData>> fetchExistingByIds(List<int> ids) =>
      (database.select(database.verbFormExampleTable)..where((t) => t.id.isIn(ids))).get();

  @override
  int getDataId(VerbFormExampleTableData data) => data.id;

  @override
  int getDtoId(VerbFormExampleSimpleDto dto) => dto.id;

  @override
  int getDtoVersion(VerbFormExampleSimpleDto dto) => dto.version;

  @override
  int getExistingVersion(VerbFormExampleTableData existing) => existing.version;

  Future<SyncResult> upsertExamples(List<VerbFormExampleSimpleDto> batch) => upsertBatch(batch);
}
