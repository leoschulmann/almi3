import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_dto.dart';
import 'package:almi3/model/dto/verb_word_dto.dart';
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

  static const _superscriptDigits = ['⁰','¹','²','³','⁴','⁵','⁶','⁷','⁸','⁹'];

  String _superscript(int n) => n.toString().split('').map((d) => _superscriptDigits[int.parse(d)]).join();

  Future<List<VerbWordDto>> getVerbsByRootId(int rootId, String lang) async {
    final query = database.select(database.verbTable).join([
      leftOuterJoin(
        database.verbTranslationTable,
        database.verbTranslationTable.verbId.equalsExp(database.verbTable.id) &
            database.verbTranslationTable.lang.equals(lang),
      ),
    ])
      ..where(database.verbTable.rootId.equals(rootId));

    final rows = await query.get();

    final grouped = <int, ({VerbTableData verb, List<String> translations})>{};
    for (final row in rows) {
      final verb = row.readTable(database.verbTable);
      final t9n = row.readTableOrNull(database.verbTranslationTable);
      final entry = grouped.putIfAbsent(verb.id, () => (verb: verb, translations: []));
      if (t9n != null) entry.translations.add(t9n.value);
    }

    return grouped.values.map((entry) {
      final t = entry.translations;
      final first = t.isEmpty ? '' : t[0];
      final label = t.length <= 1 ? first : '$first⁺${_superscript(t.length - 1)}';
      return VerbWordDto(id: entry.verb.id, value: entry.verb.value, translation: label);
    }).toList();
  }
}
