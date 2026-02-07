import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/repository/generic_repo.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

import '../dto/verb_t9n_dto.dart';

class VerbTranslationRepository
    extends GenericRepository<VerbTranslationDto, VerbTranslationTableData, VerbTranslationTableCompanion> {
  final AppDatabase database;

  VerbTranslationRepository(this.database);

  @override
  VerbTranslationTableCompanion createCompanion(VerbTranslationDto dto) {
    return VerbTranslationTableCompanion(
      id: Value(dto.id),
      value: Value(dto.value),
      version: Value(dto.version),
      lang: Value(dto.lang),
      verbId: Value(dto.verbId!),
    );
  }

  @override
  Future<void> executeBatchInsert(List<VerbTranslationTableCompanion> companions) async {
    database.batch((runInBatch) => runInBatch.insertAll(database.verbTranslationTable, companions));
  }

  @override
  Future<void> executeBatchUpdate(List<VerbTranslationTableCompanion> companions) async {
    database.batch((runInBatch) => runInBatch.replaceAll(database.verbTranslationTable, companions));
  }

  @override
  Future<List<VerbTranslationTableData>> fetchExistingByIds(List<int> ids) async {
    return await (database.select(database.verbTranslationTable)..where((filter) => filter.id.isIn(ids))).get();
  }

  @override
  int getDataId(VerbTranslationTableData data) => data.id;

  @override
  int getDtoId(VerbTranslationDto dto) => dto.id;

  @override
  int getDtoVersion(VerbTranslationDto dto) => dto.version;

  @override
  int getExistingVersion(VerbTranslationTableData existing) => existing.version;

  Future<SyncResult> upsertForBatch(Map<int, List<VerbTranslationDto>> translationsWithParentIds) async {
    List<VerbTranslationDto> list = translationsWithParentIds.entries.expand((kv) {
      for (var translation in kv.value) {
        translation.verbId = kv.key;
      }
      return kv.value;
    }).toList();

    return upsertBatch(list);
  }
}
