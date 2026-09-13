import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/grade_answer.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _FixedSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings.defaultSettings();
}

/// Settings that would starve new-lexeme intake entirely (zero new cards/day,
/// no active decks) -- used to prove the due queue doesn't read them (CAP-7).
class _NoNewCardsSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings.defaultSettings().copyWith(newCardsPerDay: 0, activeDeckIds: const []);
}

Future<int> _insertCard(
  UserDatabase db, {
  required int due,
  required int state,
  int? step,
  int reps = 0,
  int lapses = 0,
  int? lastReview,
  int direction = directionRecognition,
  double? stability,
  double? difficulty,
}) async {
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: due,
          state: state,
          step: Value(step),
          reps: Value(reps),
          lapses: Value(lapses),
          lastReview: Value(lastReview ?? (state != fsrs.State.learning.value ? due - 86400 : null)),
          stability: Value(stability ?? (state != fsrs.State.learning.value ? 10.0 : null)),
          difficulty: Value(difficulty ?? (state != fsrs.State.learning.value ? 5.0 : null)),
          createdAt: 1000,
        ),
      );
  final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0,
          entityId: cardId,
          status: 0,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(
          cardId: Value(cardId),
          lexemeProgressId: lexemeProgressId,
          direction: direction,
        ),
      );
  return cardId;
}

Future<int> _insertConjugationCard(
  UserDatabase db, {
  required int due,
  required int state,
  int? step,
}) async {
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 1,
          due: due,
          state: state,
          step: Value(step),
          stability: Value(state != fsrs.State.learning.value ? 10.0 : null),
          difficulty: Value(state != fsrs.State.learning.value ? 5.0 : null),
          lastReview: Value(state != fsrs.State.learning.value ? due - 86400 : null),
          createdAt: 1000,
        ),
      );
  await db.into(db.conjugationCardTable).insert(
        ConjugationCardTableCompanion.insert(
          cardId: Value(cardId),
          binyanId: 1,
          gizrahId: const Value(null),
          tense: 0,
          person: 0,
          plurality: 0,
          gender: 0,
        ),
      );
  return cardId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduledReviewService', () {
    late UserDatabase db;
    late ProviderContainer container;
    late ScheduledReviewService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(db),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
      service = container.read(scheduledReviewServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('getDueQueue returns only due cards, ordered by due asc, respecting limit', () async {
      final now = nowUtcSeconds();
      final idLater = await _insertCard(db, due: now + 1000, state: fsrs.State.learning.value, step: 0);
      final idDueSoon = await _insertCard(db, due: now - 500, state: fsrs.State.learning.value, step: 0);
      final idDueLong = await _insertCard(db, due: now - 5000, state: fsrs.State.learning.value, step: 0);

      final all = await service.getDueQueue();
      expect(all.map((d) => d.cardFsrsRow.id).toList(), [idDueLong, idDueSoon]);
      expect(all.any((d) => d.cardFsrsRow.id == idLater), isFalse);

      final limited = await service.getDueQueue(limit: 1);
      expect(limited.map((d) => d.cardFsrsRow.id).toList(), [idDueLong]);
    });

    test('submitAnswer on a Learning-state card runs a real reviewCard and persists results', () async {
      final now = nowUtcSeconds();
      final cardId = await _insertCard(db, due: now - 100, state: fsrs.State.learning.value, step: 0);
      final due = (await service.getDueQueue()).single;

      final updated = await service.submitAnswer(
        due: due,
        quizResult: const QuizResult(
          quizType: QuizType.mc2Recognition,
          wasCorrect: true,
          responseTimeMs: 1000,
        ),
      );

      expect(updated.reps, 1);
      expect(updated.stability, isNotNull);
      expect(updated.difficulty, isNotNull);
      expect(updated.lastReview, isNotNull);
      expect(updated.lapses, 0);

      final logs = await db.select(db.answerLogTable).get();
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.cardId, cardId);
      expect(log.source, answerSourceScheduled);
      expect(log.countedInFsrs, isTrue);
      expect(log.rating, 3); // Good, from mc2 correct grading
      expect(log.wasCorrect, isTrue);
      expect(log.quizType, QuizType.mc2Recognition.value);
      expect(log.fsrsParamsVersion, isNotNull);
      expect(log.stateBefore, 0); // New (reps was 0, lastReview was null)
    });

    test('lapse counting: Review-state Again increments lapses, Learning-state Again does not', () async {
      final now = nowUtcSeconds();

      final reviewCardId = await _insertCard(
        db,
        due: now - 100,
        state: fsrs.State.review.value,
        reps: 3,
        stability: 10,
      );
      final learningCardId = await _insertCard(db, due: now - 100, state: fsrs.State.learning.value, step: 0);

      final dueQueue = await service.getDueQueue();
      final reviewDue = dueQueue.firstWhere((d) => d.cardFsrsRow.id == reviewCardId);
      final learningDue = dueQueue.firstWhere((d) => d.cardFsrsRow.id == learningCardId);

      final updatedReview = await service.submitAnswer(
        due: reviewDue,
        quizResult: const QuizResult(quizType: QuizType.typedProduction, wasCorrect: false, responseTimeMs: 1000),
      );
      expect(updatedReview.lapses, 1);

      final updatedLearning = await service.submitAnswer(
        due: learningDue,
        quizResult: const QuizResult(quizType: QuizType.mc2Recognition, wasCorrect: false, responseTimeMs: 1000),
      );
      expect(updatedLearning.lapses, 0);
    });

    test('getDueConjugationQueue returns only conjugation cards, ordered by due asc', () async {
      final now = nowUtcSeconds();
      await _insertCard(db, due: now - 100, state: fsrs.State.learning.value, step: 0); // lexical, excluded
      final conjIdSoon =
          await _insertConjugationCard(db, due: now - 500, state: fsrs.State.learning.value, step: 0);
      final conjIdLong =
          await _insertConjugationCard(db, due: now - 5000, state: fsrs.State.learning.value, step: 0);

      final queue = await service.getDueConjugationQueue();
      expect(queue.map((d) => d.cardFsrsRow.id).toList(), [conjIdLong, conjIdSoon]);
    });

    test('submitConjugationAnswer runs a real reviewCard and logs shownVerbId', () async {
      final now = nowUtcSeconds();
      await _insertConjugationCard(db, due: now - 100, state: fsrs.State.review.value);
      final due = (await service.getDueConjugationQueue()).single;

      final updated = await service.submitConjugationAnswer(
        due: due,
        quizResult: const QuizResult(quizType: QuizType.conjProduce, wasCorrect: true, responseTimeMs: 5000),
        shownVerbId: 42,
      );

      expect(updated.reps, 1);
      expect(updated.stability, isNotNull);

      final log = (await db.select(db.answerLogTable).get()).single;
      expect(log.shownVerbId, 42);
      expect(log.quizType, QuizType.conjProduce.value);
      expect(log.rating, ratingGood);
      expect(log.stateBefore, fsrs.State.review.value);
    });

    group('debt backlog prioritization (§9.4)', () {
      test('getDueQueuePrioritized keeps due-asc order when queue is at/under backlogThreshold', () async {
        final now = nowUtcSeconds();
        final idA = await _insertCard(db, due: now - 5000, state: fsrs.State.review.value, stability: 10);
        final idB = await _insertCard(db, due: now - 100, state: fsrs.State.review.value, stability: 10);

        final prioritized = await service.getDueQueuePrioritized();
        expect(prioritized.map((d) => d.cardFsrsRow.id).toList(), [idA, idB]);
      });

      test('getDueQueuePrioritized sorts by retrievability ascending once past backlogThreshold', () async {
        final now = nowUtcSeconds();

        // Push the queue size just past backlogThreshold (30) so reprioritization kicks in.
        for (var i = 0; i < 30; i++) {
          await _insertCard(db, due: now - 100, state: fsrs.State.review.value, stability: 1000);
        }
        // Almost forgotten (low stability, long-lapsed): should end up first despite being due later.
        final forgottenId = await _insertCard(
          db,
          due: now - 1,
          state: fsrs.State.review.value,
          stability: 0.5,
          lastReview: now - 86400 * 60,
        );

        final prioritized = await service.getDueQueuePrioritized();
        expect(prioritized.length, 31);
        expect(prioritized.first.cardFsrsRow.id, forgottenId);
      });

      test('getDueQueuePrioritized respects dailyCap after sorting', () async {
        final now = nowUtcSeconds();
        for (var i = 0; i < 30; i++) {
          await _insertCard(db, due: now - 100, state: fsrs.State.review.value, stability: 1000);
        }
        final forgottenId = await _insertCard(
          db,
          due: now - 1,
          state: fsrs.State.review.value,
          stability: 0.5,
          lastReview: now - 86400 * 60,
        );

        final capped = await service.getDueQueuePrioritized(dailyCap: 1);
        expect(capped, hasLength(1));
        expect(capped.single.cardFsrsRow.id, forgottenId);
      });
    });

    group('due queue independence from deck/new-limit settings (CAP-7, §9.1)', () {
      test('a due card is returned even with new_cards_per_day=0 and no active decks', () async {
        final now = nowUtcSeconds();
        final starvedContainer = ProviderContainer(
          overrides: [
            userDbProvider.overrideWithValue(db),
            settingsProvider.overrideWith(() => _NoNewCardsSettingsNotifier()),
          ],
        );
        addTearDown(starvedContainer.dispose);
        final starvedService = starvedContainer.read(scheduledReviewServiceProvider);

        final cardId = await _insertCard(db, due: now - 100, state: fsrs.State.review.value, stability: 10);

        final due = await starvedService.getDueQueue();
        expect(due.map((d) => d.cardFsrsRow.id).toList(), [cardId]);
      });
    });

    group('production card trigger (§3.3)', () {
      test('graduating a recognition card to Review via submitAnswer spawns a production card', () async {
        final now = nowUtcSeconds();
        await _insertCard(db, due: now - 100, state: fsrs.State.learning.value, step: 0);
        final due = (await service.getDueQueue()).single;

        await service.submitAnswer(
          due: due,
          quizResult: const QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 100),
        );

        final lexicalCards = await db.select(db.lexicalCardTable).get();
        expect(lexicalCards.map((c) => c.direction).toSet(), {directionRecognition, directionProduction});
      });

      test('an Again answer that stays in Learning does not spawn a production card', () async {
        final now = nowUtcSeconds();
        await _insertCard(db, due: now - 100, state: fsrs.State.learning.value, step: 0);
        final due = (await service.getDueQueue()).single;

        await service.submitAnswer(
          due: due,
          quizResult: const QuizResult(quizType: QuizType.mc2Recognition, wasCorrect: false, responseTimeMs: 100),
        );

        final lexicalCards = await db.select(db.lexicalCardTable).get();
        expect(lexicalCards, hasLength(1));
      });

      test('submitConjugationAnswer never spawns a lexical production card', () async {
        final now = nowUtcSeconds();
        await _insertConjugationCard(db, due: now - 100, state: fsrs.State.learning.value, step: 0);
        final due = (await service.getDueConjugationQueue()).single;

        await service.submitConjugationAnswer(
          due: due,
          quizResult: const QuizResult(quizType: QuizType.conjProduce, wasCorrect: true, responseTimeMs: 100),
          shownVerbId: 1,
        );

        final lexicalCards = await db.select(db.lexicalCardTable).get();
        expect(lexicalCards, isEmpty);
      });
    });
  });
}
