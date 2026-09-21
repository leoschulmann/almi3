import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _insertVerb(VocabularyDatabase db, {required int id, required int rootId, int binyanId = 1}) async {
  await db.into(db.verbTable).insert(
        VerbTableCompanion.insert(id: Value(id), value: 'v$id', version: 1, rootId: rootId, binyanId: binyanId),
      );
}

Future<void> _insertBinyanAndRoot(VocabularyDatabase db, {int binyanId = 1, int rootId = 1}) async {
  await db.into(db.binyanTable).insert(
        BinyanTableCompanion.insert(id: Value(binyanId), value: 'b$binyanId', version: 1),
      );
  await db.into(db.rootTable).insert(
        RootTableCompanion.insert(id: Value(rootId), value: 'r$rootId', version: 1),
      );
}

Future<void> _insertVerbTranslation(
  VocabularyDatabase db, {
  required int id,
  required int verbId,
  required String lang,
  required String value,
}) async {
  await db.into(db.verbTranslationTable).insert(
        VerbTranslationTableCompanion.insert(id: Value(id), verbId: verbId, lang: lang, value: value, version: 1),
      );
}

Future<void> _insertVerbForm(VocabularyDatabase db, {required int id, required int verbId}) async {
  await db.into(db.verbFormTable).insert(
        VerbFormTableCompanion.insert(
          id: Value(id),
          verbId: verbId,
          value: 'f$id',
          tense: 0,
          person: 0,
          plurality: 0,
          gender: 0,
          version: 1,
        ),
      );
}

Future<void> _insertFormTranslit(
  VocabularyDatabase db, {
  required int id,
  required int verbFormId,
  required String lang,
  required String value,
}) async {
  await db.into(db.verbFormTransliterationTable).insert(
        VerbFormTransliterationTableCompanion.insert(
          id: Value(id),
          verbFormId: verbFormId,
          lang: lang,
          value: value,
          version: 1,
        ),
      );
}

Future<void> _insertExample(VocabularyDatabase db, {required int id, required int verbFormId}) async {
  await db.into(db.verbFormExampleTable).insert(
        VerbFormExampleTableCompanion.insert(id: Value(id), verbFormId: verbFormId, value: 'ex$id', version: 1),
      );
}

Future<void> _insertExampleTranslation(
  VocabularyDatabase db, {
  required int id,
  required int exampleId,
  required String lang,
  required String value,
}) async {
  await db.into(db.verbFormExampleTranslationTable).insert(
        VerbFormExampleTranslationTableCompanion.insert(
          id: Value(id),
          exampleId: exampleId,
          lang: lang,
          value: value,
          version: 1,
        ),
      );
}

void main() {
  group('VerbRepository.getVerbIdsByRootIds', () {
    late VocabularyDatabase db;
    late VerbRepository repo;

    setUp(() {
      db = VocabularyDatabase(NativeDatabase.memory());
      repo = VerbRepository(db);
    });

    tearDown(() async => db.close());

    test('groups verb ids by root id, preserving all matching roots', () async {
      await _insertVerb(db, id: 1, rootId: 10);
      await _insertVerb(db, id: 2, rootId: 10);
      await _insertVerb(db, id: 3, rootId: 20);

      final result = await repo.getVerbIdsByRootIds([10, 20]);

      expect(result[10]!.toSet(), {1, 2});
      expect(result[20]!.toSet(), {3});
    });

    test('a root with no verbs among the given ids has no entry', () async {
      await _insertVerb(db, id: 1, rootId: 10);

      final result = await repo.getVerbIdsByRootIds([10, 30]);

      expect(result.containsKey(30), isFalse);
    });

    test('a verb whose root id is not in the requested list is excluded', () async {
      await _insertVerb(db, id: 1, rootId: 10);
      await _insertVerb(db, id: 2, rootId: 99);

      final result = await repo.getVerbIdsByRootIds([10]);

      expect(result.keys, [10]);
      expect(result[10], [1]);
    });

    test('empty rootIds -> empty map, no query executed', () async {
      final result = await repo.getVerbIdsByRootIds([]);

      expect(result, isEmpty);
    });
  });

  group('VerbRepository fallback resolution (story 2)', () {
    late VocabularyDatabase db;
    late VerbRepository repo;

    setUp(() async {
      db = VocabularyDatabase(NativeDatabase.memory());
      repo = VerbRepository(db);
      await _insertBinyanAndRoot(db);
    });

    tearDown(() async => db.close());

    test('getVerbDetail: translation present on selected lang -> no fallback', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerbTranslation(db, id: 1, verbId: 1, lang: 'RU', value: 'рус');
      await _insertVerbTranslation(db, id: 2, verbId: 1, lang: 'EN', value: 'eng');

      final detail = await repo.getVerbDetail(1, 'RU');

      expect(detail!.translations, ['рус']);
      expect(detail.translationsIsFallback, isFalse);
    });

    test('getVerbDetail: translation missing on selected lang, present on EN -> fallback flagged', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerbTranslation(db, id: 1, verbId: 1, lang: 'EN', value: 'eng');

      final detail = await repo.getVerbDetail(1, 'RU');

      expect(detail!.translations, ['eng']);
      expect(detail.translationsIsFallback, isTrue);
    });

    test('getVerbDetail: translation missing on every language -> empty, no false-positive fallback', () async {
      await _insertVerb(db, id: 1, rootId: 1);

      final detail = await repo.getVerbDetail(1, 'RU');

      expect(detail!.translations, isEmpty);
      expect(detail.translationsIsFallback, isFalse);
    });

    test('getVerbDetail: form translit resolves independently of the verb translation fallback', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerbTranslation(db, id: 1, verbId: 1, lang: 'RU', value: 'рус');
      await _insertVerbForm(db, id: 10, verbId: 1);
      await _insertFormTranslit(db, id: 1, verbFormId: 10, lang: 'EN', value: 'translit-en');

      final detail = await repo.getVerbDetail(1, 'RU');

      expect(detail!.translationsIsFallback, isFalse);
      expect(detail.forms.single.translit, 'translit-en');
      expect(detail.forms.single.translitIsFallback, isTrue);
    });

    test('getVerbDetail: form translit missing everywhere -> empty, no fallback flag', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerbForm(db, id: 10, verbId: 1);

      final detail = await repo.getVerbDetail(1, 'RU');

      expect(detail!.forms.single.translit, '');
      expect(detail.forms.single.translitIsFallback, isFalse);
    });

    test('getExamplesForVerb: example translation missing on selected lang falls back to EN', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerbForm(db, id: 10, verbId: 1);
      await _insertExample(db, id: 100, verbFormId: 10);
      await _insertExampleTranslation(db, id: 1, exampleId: 100, lang: 'EN', value: 'example en');

      final groups = await repo.getExamplesForVerb(1, 'RU');

      final example = groups.single.examples.single;
      expect(example.translation, 'example en');
      expect(example.isFallback, isTrue);
    });

    test('getExamplesForVerb: example translation present on selected lang -> no fallback', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerbForm(db, id: 10, verbId: 1);
      await _insertExample(db, id: 100, verbFormId: 10);
      await _insertExampleTranslation(db, id: 1, exampleId: 100, lang: 'RU', value: 'example ru');
      await _insertExampleTranslation(db, id: 2, exampleId: 100, lang: 'EN', value: 'example en');

      final groups = await repo.getExamplesForVerb(1, 'RU');

      final example = groups.single.examples.single;
      expect(example.translation, 'example ru');
      expect(example.isFallback, isFalse);
    });

    test('getVerbsByRootId: partial RU/EN parity resolves fallback independently per verb', () async {
      await _insertVerb(db, id: 1, rootId: 1);
      await _insertVerb(db, id: 2, rootId: 1);
      // Verb 1 has a RU translation; verb 2 only has an EN translation.
      await _insertVerbTranslation(db, id: 1, verbId: 1, lang: 'RU', value: 'рус1');
      await _insertVerbTranslation(db, id: 2, verbId: 2, lang: 'EN', value: 'eng2');

      final words = await repo.getVerbsByRootId(1, 'RU');
      final byId = {for (final w in words) w.id: w};

      expect(byId[1]!.translation, 'рус1');
      expect(byId[1]!.isFallback, isFalse);
      expect(byId[2]!.translation, 'eng2');
      expect(byId[2]!.isFallback, isTrue);
    });
  });
}
