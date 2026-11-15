import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/dto/example_display_dto.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/model/dto/verb_dto.dart';
import 'package:almi3/model/dto/verb_word_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

import 'generic_repo.dart';

class VerbRepository extends GenericRepository<VerbSyncDto, VerbTableData, VerbTableCompanion> {
  final VocabularyDatabase database;

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

  // Fallback candidate order for a selected `lang` (dbCode): the selected
  // language itself first, then EN (unless it IS the selected language),
  // then the remaining AppLanguage.values in declaration order. Spec
  // (CAP-3 / story 2): fixed order, no user-configurable priority.
  List<String> _fallbackOrder(String lang) {
    final rest = AppLanguage.values.where((l) => l.dbCode != lang && l != AppLanguage.en).map((l) => l.dbCode);
    return [lang, if (lang != AppLanguage.en.dbCode) AppLanguage.en.dbCode, ...rest];
  }

  // Resolves a single value per parent id, trying `lang` first and then the
  // fallback order (EN, then remaining AppLanguage.values), one query per
  // candidate language covering all still-unresolved parents. Returns a map
  // parentId -> (value, isFallback); a parent id absent from the result has
  // no value on any language.
  Future<Map<int, (String value, bool isFallback)>> _resolveWithFallback({
    required List<int> parentIds,
    required String lang,
    required Future<Map<int, String>> Function(List<int> ids, String candidateLang) fetch,
  }) async {
    final result = <int, (String, bool)>{};
    if (parentIds.isEmpty) return result;
    var remaining = parentIds.toSet();
    for (final candidate in _fallbackOrder(lang)) {
      if (remaining.isEmpty) break;
      final rows = await fetch(remaining.toList(), candidate);
      final isFallback = candidate != lang;
      for (final entry in rows.entries) {
        if (!remaining.contains(entry.key)) continue;
        result[entry.key] = (entry.value, isFallback);
        remaining.remove(entry.key);
      }
    }
    return result;
  }

  // Same as _resolveWithFallback but for parents that carry a *list* of
  // values per language (e.g. multiple translations per verb) -- used where
  // a single language block (all-or-nothing per parent) is the fallback
  // unit, per Design Notes.
  Future<Map<int, (List<String> values, bool isFallback)>> _resolveListWithFallback({
    required List<int> parentIds,
    required String lang,
    required Future<Map<int, List<String>>> Function(List<int> ids, String candidateLang) fetch,
  }) async {
    final result = <int, (List<String>, bool)>{};
    if (parentIds.isEmpty) return result;
    var remaining = parentIds.toSet();
    for (final candidate in _fallbackOrder(lang)) {
      if (remaining.isEmpty) break;
      final rows = await fetch(remaining.toList(), candidate);
      final isFallback = candidate != lang;
      for (final entry in rows.entries) {
        if (!remaining.contains(entry.key) || entry.value.isEmpty) continue;
        result[entry.key] = (entry.value, isFallback);
        remaining.remove(entry.key);
      }
    }
    return result;
  }

  // SELECT verb_id, value FROM verb_t9n_table WHERE verb_id IN (?) AND lang = ?
  Future<Map<int, List<String>>> _fetchVerbTranslations(List<int> verbIds, String lang) async {
    if (verbIds.isEmpty) return {};
    final rows = await (database.select(database.verbTranslationTable)
          ..where((t) => t.verbId.isIn(verbIds) & t.lang.equals(lang)))
        .get();
    final map = <int, List<String>>{};
    for (final r in rows) {
      map.putIfAbsent(r.verbId, () => []).add(r.value);
    }
    return map;
  }

  // SELECT verb_form_id, value FROM verb_form_t13n_table WHERE verb_form_id IN (?) AND lang = ?
  Future<Map<int, String>> _fetchFormTransliterations(List<int> formIds, String lang) async {
    if (formIds.isEmpty) return {};
    final rows = await (database.select(database.verbFormTransliterationTable)
          ..where((t) => t.verbFormId.isIn(formIds) & t.lang.equals(lang)))
        .get();
    final map = <int, String>{};
    for (final r in rows) {
      map.putIfAbsent(r.verbFormId, () => r.value);
    }
    return map;
  }

  // SELECT example_id, value FROM verb_form_example_t9n_table WHERE example_id IN (?) AND lang = ?
  Future<Map<int, String>> _fetchExampleTranslations(List<int> exampleIds, String lang) async {
    if (exampleIds.isEmpty) return {};
    final rows = await (database.select(database.verbFormExampleTranslationTable)
          ..where((t) => t.exampleId.isIn(exampleIds) & t.lang.equals(lang)))
        .get();
    final map = <int, String>{};
    for (final r in rows) {
      map.putIfAbsent(r.exampleId, () => r.value);
    }
    return map;
  }

  // todo seems heavy
  Future<VerbDetailDto?> getVerbDetail(int verbId, String lang) async {
    // SELECT * FROM verb_table
    // INNER JOIN binyan_table ON binyan_table.id = verb_table.binyan_id
    // INNER JOIN root_table ON root_table.id = verb_table.root_id
    // WHERE verb_table.id = ?
    final query = database.select(database.verbTable).join([
      innerJoin(database.binyanTable, database.binyanTable.id.equalsExp(database.verbTable.binyanId)),
      innerJoin(database.rootTable, database.rootTable.id.equalsExp(database.verbTable.rootId)),
    ])
      ..where(database.verbTable.id.equals(verbId));

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final row = rows.first;
    final verb = row.readTable(database.verbTable);
    final binyan = row.readTable(database.binyanTable);
    final root = row.readTable(database.rootTable);

    final translationResult = await _resolveListWithFallback(
      parentIds: [verbId],
      lang: lang,
      fetch: _fetchVerbTranslations,
    );
    final translationEntry = translationResult[verbId];
    final translations = translationEntry?.$1 ?? const <String>[];
    final translationsIsFallback = translationEntry?.$2 ?? false;

    final gizrahRows = await (database.select(database.gizrahTable).join([
      innerJoin(database.verbGizrahTable, database.verbGizrahTable.gizrahId.equalsExp(database.gizrahTable.id)),
    ])..where(database.verbGizrahTable.verbId.equals(verbId))).get();

    final prepRows = await (database.select(database.prepositionTable).join([
      innerJoin(database.verbPrepTable, database.verbPrepTable.prepId.equalsExp(database.prepositionTable.id)),
    ])..where(database.verbPrepTable.verbId.equals(verbId))).get();

    // SELECT * FROM verb_form_table WHERE verb_id = ?
    final formRows = await (database.select(database.verbFormTable)
          ..where((t) => t.verbId.equals(verbId)))
        .get();

    final formIds = formRows.map((f) => f.id).toList();
    final translitResult = await _resolveWithFallback(
      parentIds: formIds,
      lang: lang,
      fetch: _fetchFormTransliterations,
    );

    return VerbDetailDto(
      id: verb.id,
      value: verb.value,
      binyan: binyan.value,
      root: root.value,
      gizrahs: gizrahRows.map((r) => r.readTable(database.gizrahTable).value).toList(),
      preps: prepRows.map((r) => r.readTable(database.prepositionTable).value).toList(),
      translations: translations,
      translationsIsFallback: translationsIsFallback,
      forms: formRows.map((f) {
        final translit = translitResult[f.id];
        return VerbFormDisplayDto(
          id: f.id,
          value: f.value,
          translit: translit?.$1 ?? '',
          translitIsFallback: translit?.$2 ?? false,
          tense: Tense.values[f.tense],
          person: GrammaticalPerson.values[f.person],
          plurality: Plurality.values[f.plurality],
          gender: GrammaticalGender.values[f.gender],
        );
      }).toList(),
    );
  }

  Future<List<VerbFormExampleGroupDto>> getExamplesForVerb(int verbId, String lang) async {
    // SELECT * FROM verb_form_table WHERE verb_id = ?
    final List<VerbFormTableData> formRows = await (database.select(database.verbFormTable)
      ..where((t) => t.verbId.equals(verbId)))
        .get();

    if (formRows.isEmpty) return [];

    final formIds = formRows.map((f) => f.id).toList();

    // SELECT * FROM verb_form_example_table WHERE verb_form_id IN (?)
    final List<VerbFormExampleTableData> exampleRows = await (database.select(database.verbFormExampleTable)
          ..where((t) => t.verbFormId.isIn(formIds)))
        .get();

    final exampleIds = exampleRows.map((e) => e.id).toList();
    final translationResult = await _resolveWithFallback(
      parentIds: exampleIds,
      lang: lang,
      fetch: _fetchExampleTranslations,
    );

    final grouped = <int, List<ExampleDisplayDto>>{};
    for (final ex in exampleRows) {
      final translation = translationResult[ex.id];
      grouped.putIfAbsent(ex.verbFormId, () => []).add(ExampleDisplayDto(
        exampleId: ex.id,
        sentence: ex.value,
        translation: translation?.$1 ?? '',
        isFallback: translation?.$2 ?? false,
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
  // SELECT id FROM verb_table WHERE binyan_id = ? AND id IN (?)
  // TODO(spec §7.2): pool candidates are restricted to [candidateIds] (the
  // set of verbs whose lexeme is already known, per §7.3's "only known
  // lexemes" guard) — that gate is computed in user.db, so it's passed in
  // rather than joined here (no cross-db joins, §2.3).
  Future<List<int>> getVerbIdsByBinyan(int binyanId, List<int> candidateIds) async {
    if (candidateIds.isEmpty) return [];
    final rows = await (database.select(database.verbTable)
          ..where((t) => t.binyanId.equals(binyanId) & t.id.isIn(candidateIds)))
        .get();
    return rows.map((r) => r.id).toList();
  }

  // SELECT DISTINCT verb_id FROM verb_gizrah_jointable WHERE verb_id IN (?)
  Future<Set<int>> getVerbIdsWithAnyGizrah(List<int> verbIds) async {
    if (verbIds.isEmpty) return {};
    final rows = await (database.select(database.verbGizrahTable)
          ..where((t) => t.verbId.isIn(verbIds)))
        .get();
    return rows.map((r) => r.verbId).toSet();
  }

  // SELECT verb_id FROM verb_gizrah_jointable WHERE gizrah_id = ? AND verb_id IN (?)
  Future<Set<int>> getVerbIdsWithGizrah(int gizrahId, List<int> verbIds) async {
    if (verbIds.isEmpty) return {};
    final rows = await (database.select(database.verbGizrahTable)
          ..where((t) => t.gizrahId.equals(gizrahId) & t.verbId.isIn(verbIds)))
        .get();
    return rows.map((r) => r.verbId).toSet();
  }

  // SELECT COUNT(*) FROM verb_table
  Future<int> getTotalCount() async {
    final countExp = database.verbTable.id.count();
    final query = database.selectOnly(database.verbTable)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // SELECT id, root_id FROM verb_table WHERE root_id IN (?)
  Future<Map<int, List<int>>> getVerbIdsByRootIds(List<int> rootIds) async {
    if (rootIds.isEmpty) return {};
    final rows = await (database.select(database.verbTable)
          ..where((t) => t.rootId.isIn(rootIds)))
        .get();
    final verbIds = <int, List<int>>{};
    for (final row in rows) {
      verbIds.putIfAbsent(row.rootId, () => []).add(row.id);
    }
    return verbIds;
  }

  // SELECT * FROM verb_table WHERE id NOT IN (?)
  // ORDER BY frequency_rank IS NULL, frequency_rank ASC LIMIT ?
  // TODO(spec §9.2): frequency_rank is nullable until ranking data exists for
  // all verbs; verbs with a null rank sort after ranked ones for now.
  Future<List<VerbTableData>> getNewCandidatesOrderedByFrequency(List<int> excludeIds, int limit) async {
    final query = database.select(database.verbTable);
    if (excludeIds.isNotEmpty) {
      query.where((t) => t.id.isNotIn(excludeIds));
    }
    query
      ..orderBy([
        (t) => OrderingTerm(expression: t.frequencyRank, mode: OrderingMode.asc, nulls: NullsOrder.last),
      ])
      ..limit(limit);
    return query.get();
  }

  Future<List<VerbWordDto>> getVerbsByRootId(int rootId, String lang) async {
    // SELECT * FROM verb_table WHERE root_id = ?
    final verbRows = await (database.select(database.verbTable)
          ..where((t) => t.rootId.equals(rootId)))
        .get();

    final verbIds = verbRows.map((v) => v.id).toList();
    final translationResult = await _resolveListWithFallback(
      parentIds: verbIds,
      lang: lang,
      fetch: _fetchVerbTranslations,
    );

    return verbRows.map((verb) {
      final entry = translationResult[verb.id];
      final t = entry?.$1 ?? const <String>[];
      final isFallback = entry?.$2 ?? false;
      final first = t.isEmpty ? '' : t[0];
      final label = t.length <= 1 ? first : '$first⁺${_superscript(t.length - 1)}';
      return VerbWordDto(id: verb.id, value: verb.value, translation: label, isFallback: isFallback);
    }).toList();
  }
}
