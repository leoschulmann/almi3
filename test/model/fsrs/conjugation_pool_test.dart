import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/conjugation_pool.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

Future<void> _markVerbKnown(UserDatabase db, int verbId, {bool known = true}) async {
  final progressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0,
          entityId: verbId,
          status: 0,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: 0,
          state: known ? fsrs.State.review.value : fsrs.State.learning.value,
          step: Value(known ? null : 0),
          stability: Value(known ? 10.0 : null),
          difficulty: Value(known ? 5.0 : null),
          lastReview: Value(known ? 0 : null),
          reps: Value(known ? 3 : 0),
          createdAt: 1000,
        ),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(
          cardId: Value(cardId),
          lexemeProgressId: progressId,
          direction: directionRecognition,
        ),
      );
}

void main() {
  group('ConjugationPoolService', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;
    late ConjugationPoolService service;

    setUp(() async {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());
      service = ConjugationPoolService(
        verbRepository: VerbRepository(contentDb),
        lexicalCardRepository: LexicalCardRepository(userDb),
        answerLogRepository: AnswerLogRepository(userDb),
      );

      await contentDb.into(contentDb.rootTable).insert(
            RootTableCompanion.insert(id: const Value(1), value: 'כתב', version: 1),
          );
      await contentDb.into(contentDb.binyanTable).insert(
            BinyanTableCompanion.insert(id: const Value(1), value: 'פעל', version: 1),
          );
      await contentDb.into(contentDb.binyanTable).insert(
            BinyanTableCompanion.insert(id: const Value(2), value: 'פיעל', version: 1),
          );
      await contentDb.into(contentDb.gizrahTable).insert(
            GizrahTableCompanion.insert(id: const Value(1), value: 'ע"ו', version: 1),
          );

      // verb 1: binyan 1, regular (no gizrah row), known.
      // verb 2: binyan 1, gizrah 1, known.
      // verb 3: binyan 1, regular, NOT known (should be excluded).
      // verb 4: binyan 2 (wrong binyan), regular, known.
      for (final id in [1, 2, 3, 4]) {
        await contentDb.into(contentDb.verbTable).insert(
              VerbTableCompanion.insert(
                id: Value(id),
                value: 'v$id',
                version: 1,
                rootId: 1,
                binyanId: id == 4 ? 2 : 1,
              ),
            );
      }
      await contentDb.into(contentDb.verbGizrahTable).insert(
            VerbGizrahTableCompanion.insert(verbId: 2, gizrahId: 1),
          );

      await _markVerbKnown(userDb, 1);
      await _markVerbKnown(userDb, 2);
      await _markVerbKnown(userDb, 3, known: false);
      await _markVerbKnown(userDb, 4);
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    test('regular pool (gizrahId null): known, right binyan, no gizrah row', () async {
      final card = ConjugationCardTableData(
        cardId: 1,
        binyanId: 1,
        gizrahId: null,
        tense: 0,
        person: 0,
        plurality: 0,
        gender: 0,
      );
      final pool = await service.getPool(card);
      expect(pool, [1]);
    });

    test('gizrah pool: known, right binyan, matching gizrah row', () async {
      final card = ConjugationCardTableData(
        cardId: 1,
        binyanId: 1,
        gizrahId: 1,
        tense: 0,
        person: 0,
        plurality: 0,
        gender: 0,
      );
      final pool = await service.getPool(card);
      expect(pool, [2]);
    });

    test('unknown verbs are excluded even if binyan/gizrah match', () async {
      final card = ConjugationCardTableData(
        cardId: 1,
        binyanId: 1,
        gizrahId: null,
        tense: 0,
        person: 0,
        plurality: 0,
        gender: 0,
      );
      final pool = await service.getPool(card);
      expect(pool.contains(3), isFalse);
    });

    test('wrong binyan is excluded', () async {
      final card = ConjugationCardTableData(
        cardId: 1,
        binyanId: 1,
        gizrahId: null,
        tense: 0,
        person: 0,
        plurality: 0,
        gender: 0,
      );
      final pool = await service.getPool(card);
      expect(pool.contains(4), isFalse);
    });

    test('pickVerb excludes the most-recently-shown verb for interleaving', () async {
      const conjugationCardId = 99;
      await AnswerLogRepository(userDb).insert(
        AnswerLogTableCompanion.insert(
          cardId: conjugationCardId,
          answeredAt: 1000,
          source: 0,
          countedInFsrs: true,
          rating: const Value(3),
          wasCorrect: true,
          quizType: QuizType.conjProduce.value,
          shownVerbId: const Value(1),
          fsrsParamsVersion: 1,
        ),
      );

      final picked = await service.pickVerb(conjugationCardId, [1, 2]);
      expect(picked, 2);
    });

    test('pickVerb falls back to the pool if excluding recents leaves nothing', () async {
      const conjugationCardId = 99;
      await AnswerLogRepository(userDb).insert(
        AnswerLogTableCompanion.insert(
          cardId: conjugationCardId,
          answeredAt: 1000,
          source: 0,
          countedInFsrs: true,
          rating: const Value(3),
          wasCorrect: true,
          quizType: QuizType.conjProduce.value,
          shownVerbId: const Value(1),
          fsrsParamsVersion: 1,
        ),
      );

      final picked = await service.pickVerb(conjugationCardId, [1]);
      expect(picked, 1);
    });

    test('pickVerb returns null for an empty pool', () async {
      expect(await service.pickVerb(1, []), isNull);
    });
  });
}
