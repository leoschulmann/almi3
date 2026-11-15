import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LexemeSelectionService', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;
    late LexemeSelectionService service;

    setUp(() async {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());
      service = LexemeSelectionService(
        lexemeProgressRepository: LexemeProgressRepository(userDb),
        verbRepository: VerbRepository(contentDb),
      );

      await contentDb.into(contentDb.rootTable).insert(
            RootTableCompanion.insert(id: const Value(1), value: 'כתב', version: 1),
          );
      await contentDb.into(contentDb.binyanTable).insert(
            BinyanTableCompanion.insert(id: const Value(1), value: 'פעל', version: 1),
          );

      // Three verbs: ranks 2, 1, and unranked.
      await contentDb.into(contentDb.verbTable).insert(
            VerbTableCompanion.insert(
              id: const Value(10),
              value: 'כתב',
              version: 1,
              rootId: 1,
              binyanId: 1,
              frequencyRank: const Value(2),
            ),
          );
      await contentDb.into(contentDb.verbTable).insert(
            VerbTableCompanion.insert(
              id: const Value(20),
              value: 'קרא',
              version: 1,
              rootId: 1,
              binyanId: 1,
              frequencyRank: const Value(1),
            ),
          );
      await contentDb.into(contentDb.verbTable).insert(
            VerbTableCompanion.insert(
              id: const Value(30),
              value: 'דבר',
              version: 1,
              rootId: 1,
              binyanId: 1,
            ),
          );
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    test('orders by frequency_rank ascending, nulls last, respects limit', () async {
      final result = await service.selectNewLexemes(2);
      expect(result.map((v) => v.id).toList(), [20, 10]);
    });

    test('excludes already-started verbs', () async {
      await LexemeProgressRepository(userDb).insert(
        LexemeProgressTableCompanion.insert(
          entityType: entityTypeVerb,
          entityId: 20,
          status: 0,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

      final result = await service.selectNewLexemes(10);
      expect(result.map((v) => v.id).toList(), [10, 30]);
    });

    test('limit <= 0 returns empty', () async {
      expect(await service.selectNewLexemes(0), isEmpty);
    });

    test('countIntroducedToday counts only rows since the day boundary', () async {
      final repo = LexemeProgressRepository(userDb);
      final now = DateTime.now().toUtc();
      final todayBoundaryHour = 4;

      // Insert one lexeme_progress "now" (should count) and one far in the past (should not).
      await repo.insert(LexemeProgressTableCompanion.insert(
        entityType: entityTypeVerb,
        entityId: 1,
        status: 0,
        firstSeenAt: Value(now.millisecondsSinceEpoch ~/ 1000),
        createdAt: 1000,
        updatedAt: 1000,
      ));
      await repo.insert(LexemeProgressTableCompanion.insert(
        entityType: entityTypeVerb,
        entityId: 2,
        status: 0,
        firstSeenAt: const Value(0),
        createdAt: 1000,
        updatedAt: 1000,
      ));

      final count = await service.countIntroducedToday(todayBoundaryHour);
      expect(count, 1);
    });
  });
}
