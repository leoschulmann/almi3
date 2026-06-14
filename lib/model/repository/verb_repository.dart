import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
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

  // todo seems heavy
  Future<VerbDetailDto?> getVerbDetail(int verbId, String lang) async {
    final query = database.select(database.verbTable).join([
      innerJoin(database.binyanTable, database.binyanTable.id.equalsExp(database.verbTable.binyanId)),
      innerJoin(database.rootTable, database.rootTable.id.equalsExp(database.verbTable.rootId)),
      leftOuterJoin(
        database.verbTranslationTable,
        database.verbTranslationTable.verbId.equalsExp(database.verbTable.id) &
            database.verbTranslationTable.lang.equals(lang),
      ),
    ])
      ..where(database.verbTable.id.equals(verbId));

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final row = rows.first;
    final verb = row.readTable(database.verbTable);
    final binyan = row.readTable(database.binyanTable);
    final root = row.readTable(database.rootTable);
    final translations = rows
        .map((r) => r.readTableOrNull(database.verbTranslationTable)?.value)
        .whereType<String>()
        .toList();

    final gizrahRows = await (database.select(database.gizrahTable).join([
      innerJoin(database.verbGizrahTable, database.verbGizrahTable.gizrahId.equalsExp(database.gizrahTable.id)),
    ])..where(database.verbGizrahTable.verbId.equals(verbId))).get();

    final prepRows = await (database.select(database.prepositionTable).join([
      innerJoin(database.verbPrepTable, database.verbPrepTable.prepId.equalsExp(database.prepositionTable.id)),
    ])..where(database.verbPrepTable.verbId.equals(verbId))).get();

    final formRows = await (database.select(database.verbFormTable).join([
      leftOuterJoin(
        database.verbFormTransliterationTable,
        database.verbFormTransliterationTable.verbFormId.equalsExp(database.verbFormTable.id) &
            database.verbFormTransliterationTable.lang.equals(lang),
      ),
    ])..where(database.verbFormTable.verbId.equals(verbId))).get();

    final formMap = <int, ({VerbFormTableData form, String? translit})>{};
    for (final r in formRows) {
      final f = r.readTable(database.verbFormTable);
      final t = r.readTableOrNull(database.verbFormTransliterationTable);
      formMap.putIfAbsent(f.id, () => (form: f, translit: t?.value));
    }

    return VerbDetailDto(
      id: verb.id,
      value: verb.value,
      binyan: binyan.value,
      root: root.value,
      gizrahs: gizrahRows.map((r) => r.readTable(database.gizrahTable).value).toList(),
      preps: prepRows.map((r) => r.readTable(database.prepositionTable).value).toList(),
      translations: translations,
      forms: formMap.values.map((e) => VerbFormDisplayDto(
        id: e.form.id,
        value: e.form.value,
        translit: e.translit ?? '',
        tense: Tense.values[e.form.tense],
        person: GrammaticalPerson.values[e.form.person],
        plurality: Plurality.values[e.form.plurality],
        gender: GrammaticalGender.values[e.form.gender],
      )).toList(),
    );
  }

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
