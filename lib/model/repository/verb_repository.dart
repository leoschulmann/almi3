import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/example_display_dto.dart';
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

  Future<List<VerbFormExampleGroupDto>> getExamplesForVerb(int verbId, String lang) async {
    // SELECT * FROM verb_form_table WHERE verb_id = ?
    final List<VerbFormTableData> formRows = await (database.select(database.verbFormTable)
      ..where((t) => t.verbId.equals(verbId)))
        .get();

    if (formRows.isEmpty) return [];

    final formIds = formRows.map((f) => f.id).toList();

    // SELECT vfe.*, vfet.value
    // FROM verb_form_example_table vfe
    // LEFT OUTER JOIN verb_form_example_translation_table vfet
    //   ON vfet.example_id = vfe.id AND vfet.lang = ?
    // WHERE vfe.verb_form_id IN (?)
    final List<TypedResult> exampleRows = await (database.select(database.verbFormExampleTable).join([
      leftOuterJoin(
        database.verbFormExampleTranslationTable,
        database.verbFormExampleTranslationTable.exampleId
            .equalsExp(database.verbFormExampleTable.id) &
        database.verbFormExampleTranslationTable.lang.equals(lang),
      ),
    ])
      ..where(database.verbFormExampleTable.verbFormId.isIn(formIds)))
        .get();

    final exampleMap = <int, ({VerbFormExampleTableData ex, String translation})>{};
    for (final r in exampleRows) {
      final ex = r.readTable(database.verbFormExampleTable);
      final t9n = r.readTableOrNull(database.verbFormExampleTranslationTable);
      exampleMap.putIfAbsent(ex.id, () => (ex: ex, translation: t9n?.value ?? ''));
    }

    final grouped = <int, List<ExampleDisplayDto>>{};
    for (final entry in exampleMap.values) {
      grouped.putIfAbsent(entry.ex.verbFormId, () => []).add(ExampleDisplayDto(
        exampleId: entry.ex.id,
        sentence: entry.ex.value,
        translation: entry.translation,
      ));
    }

    return formRows
        .where((f) => grouped.containsKey(f.id))
        .map((f) =>
        VerbFormExampleGroupDto(
          formId: f.id,
          formValue: f.value,
          tense: Tense.values[f.tense],
          person: GrammaticalPerson.values[f.person],
          plurality: Plurality.values[f.plurality],
          gender: GrammaticalGender.values[f.gender],
          examples: grouped[f.id]!,
        ))
        .toList();
  }
  // SELECT COUNT(*) FROM verb_table
  Future<int> getTotalCount() async {
    final countExp = database.verbTable.id.count();
    final query = database.selectOnly(database.verbTable)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // SELECT root_id, COUNT(*) FROM verb_table WHERE root_id IN (?) GROUP BY root_id
  Future<Map<int, int>> getVerbCountsByRootIds(List<int> rootIds) async {
    if (rootIds.isEmpty) return {};
    final rows = await (database.select(database.verbTable)
          ..where((t) => t.rootId.isIn(rootIds)))
        .get();
    final counts = <int, int>{};
    for (final row in rows) {
      counts[row.rootId] = (counts[row.rootId] ?? 0) + 1;
    }
    return counts;
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
