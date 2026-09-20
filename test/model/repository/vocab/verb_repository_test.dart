import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _insertVerb(VocabularyDatabase db, {required int id, required int rootId}) async {
  await db.into(db.verbTable).insert(
        VerbTableCompanion.insert(id: Value(id), value: 'v$id', version: 1, rootId: rootId, binyanId: 1),
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
}
