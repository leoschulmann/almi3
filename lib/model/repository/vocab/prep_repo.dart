import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/dto/prep_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

import 'generic_repo.dart';

class PrepositionRepository extends GenericRepository<PrepositionDto, PrepositionTableData, PrepositionTableCompanion> {
  final VocabularyDatabase database;

  PrepositionRepository({required this.database});

  @override
  PrepositionTableCompanion createCompanion(PrepositionDto dto) {
    return PrepositionTableCompanion(id: Value(dto.id), value: Value(dto.value), version: Value(dto.version));
  }

  @override
  Future<void> executeBatchInsert(List<PrepositionTableCompanion> companions) async {
    await database.batch((batch) => batch.insertAll(database.prepositionTable, companions));
  }

  @override
  Future<void> executeBatchUpdate(List<PrepositionTableCompanion> companions) async {
    await database.batch((batch) => batch.replaceAll(database.prepositionTable, companions));
  }

  @override
  Future<List<PrepositionTableData>> fetchExistingByIds(List<int> ids) async {
    return await (database.select(database.prepositionTable)..where((tbl) => tbl.id.isIn(ids))).get();
  }

  @override
  int getDtoId(PrepositionDto dto) => dto.id;
  
  @override
  int getDataId(PrepositionTableData data) => data.id;
  
  @override
  int getDtoVersion(PrepositionDto dto) => dto.version;

  @override
  int getExistingVersion(PrepositionTableData existing) => existing.version;
  
  Future<SyncResult> upsertPrepositions(List<PrepositionDto> preps) async {
    return await upsertBatch(preps);
  }
}
