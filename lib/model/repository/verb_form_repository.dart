import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_form_simple_dto.dart';
import 'package:almi3/model/repository/generic_repo.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbFormRepository extends GenericRepository<VerbFormSimpleDto, VerbFormTableData, VerbFormTableCompanion> {
  final AppDatabase database;

  VerbFormRepository(this.database);

  @override
  VerbFormTableCompanion createCompanion(VerbFormSimpleDto dto) => VerbFormTableCompanion(
        id: Value(dto.id),
        verbId: Value(dto.verbId),
        value: Value(dto.value),
        version: Value(dto.version),
        tense: Value(dto.tense),
        person: Value(dto.person),
        plurality: Value(dto.plurality),
        gender: Value(dto.gender),
      );

  @override
  Future<void> executeBatchInsert(List<VerbFormTableCompanion> companions) async =>
      database.batch((b) => b.insertAll(database.verbFormTable, companions));

  @override
  Future<void> executeBatchUpdate(List<VerbFormTableCompanion> companions) async =>
      database.batch((b) => b.replaceAll(database.verbFormTable, companions));

  @override
  Future<List<VerbFormTableData>> fetchExistingByIds(List<int> ids) =>
      (database.select(database.verbFormTable)..where((t) => t.id.isIn(ids))).get();

  @override
  int getDataId(VerbFormTableData data) => data.id;

  @override
  int getDtoId(VerbFormSimpleDto dto) => dto.id;

  @override
  int getDtoVersion(VerbFormSimpleDto dto) => dto.version;

  @override
  int getExistingVersion(VerbFormTableData existing) => existing.version;

  Future<SyncResult> upsertVerbForms(List<VerbFormSimpleDto> batch) => upsertBatch(batch);
}
