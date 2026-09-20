import 'dart:async';

import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/production_card_introduction.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/conjugation_card_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/viewmodel/session_notifier.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _SettingsNotifier extends SettingsNotifier {
  final AppSettings _settings;
  _SettingsNotifier(this._settings);

  @override
  AppSettings build() => _settings;
}

/// A scheduled-review service whose due-queue lookup always fails, to
/// exercise SessionNotifier's error path without depending on a specific
/// invalid DB state.
class _FailingScheduledReviewService extends ScheduledReviewService {
  _FailingScheduledReviewService({
    required super.ref,
    required super.cardFsrsRepository,
    required super.lexicalCardRepository,
    required super.conjugationCardRepository,
    required super.answerLogRepository,
    required super.fsrsParamsRepository,
    required super.healthService,
    required super.productionCardIntroductionService,
  });

  @override
  Future<List<DueLexicalCard>> getDueQueuePrioritized({int? dailyCap}) {
    throw StateError('simulated due-queue failure');
  }
}

Future<void> _seedRootAndBinyan(VocabularyDatabase db) async {
  await db.into(db.rootTable).insert(RootTableCompanion.insert(id: const Value(1), value: 'כתב', version: 1));
  await db.into(db.binyanTable).insert(BinyanTableCompanion.insert(id: const Value(1), value: 'פעל', version: 1));
}

Future<void> _insertVerb(
  VocabularyDatabase db, {
  required int id,
  required String value,
  required String translation,
  int? frequencyRank,
}) async {
  await db.into(db.verbTable).insert(
        VerbTableCompanion.insert(
          id: Value(id),
          value: value,
          version: 1,
          rootId: 1,
          binyanId: 1,
          frequencyRank: Value(frequencyRank),
        ),
      );
  await db.into(db.verbTranslationTable).insert(
        VerbTranslationTableCompanion.insert(
          id: Value(id * 100),
          value: translation,
          version: 1,
          lang: 'EN',
          verbId: id,
        ),
      );
}

/// Inserts a due lexical card (card_fsrs + lexical_card + lexeme_progress)
/// pointing at content-db verb [verbId]. Early-Learning + step 0 keeps
/// chooseFormat deterministic (mc2*, narrowed to the MVP format for its
/// direction) rather than the Review stage's probabilistic pick.
Future<int> _insertDueCard(
  UserDatabase db, {
  required int verbId,
  required int direction,
  int? due,
}) async {
  final now = nowUtcSeconds();
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: due ?? now - 100,
          state: fsrs.State.learning.value,
          step: const Value(0),
          reps: const Value(1),
          lastReview: Value(now - 3600),
          stability: const Value(1.0),
          difficulty: const Value(5.0),
          createdAt: 1000,
        ),
      );
  final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0,
          entityId: verbId,
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

/// Polls until the notifier's initial async load finishes (phase leaves
/// `loading`), rather than assuming a fixed number of event-loop turns.
Future<SessionState> _settle(ProviderContainer container) async {
  var state = container.read(sessionNotifierProvider);
  if (state.phase != SessionPhase.loading) return state;

  final completer = Completer<SessionState>();
  late final ProviderSubscription<SessionState> sub;
  sub = container.listen<SessionState>(sessionNotifierProvider, (previous, next) {
    if (next.phase != SessionPhase.loading && !completer.isCompleted) {
      completer.complete(next);
    }
  });
  final result = await completer.future;
  sub.close();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('narrowQuizType (pure)', () {
    test('the two MVP formats pass through unchanged', () {
      expect(narrowQuizType(QuizType.mc4Recognition), QuizType.mc4Recognition);
      expect(narrowQuizType(QuizType.typedProduction), QuizType.typedProduction);
    });

    test('recognition-direction formats narrow to mc4Recognition', () {
      expect(narrowQuizType(QuizType.mc2Recognition), QuizType.mc4Recognition);
      expect(narrowQuizType(QuizType.listening), QuizType.mc4Recognition);
    });

    test('production-direction formats narrow to typedProduction', () {
      expect(narrowQuizType(QuizType.mc2Production), QuizType.typedProduction);
      expect(narrowQuizType(QuizType.mc4Production), QuizType.typedProduction);
      expect(narrowQuizType(QuizType.niqqud), QuizType.typedProduction);
      expect(narrowQuizType(QuizType.cloze), QuizType.typedProduction);
      expect(narrowQuizType(QuizType.preposition), QuizType.typedProduction);
    });
  });

  group('interleaveSessionQueue (pure)', () {
    test('alternates due/new items, preserving each list\'s own order', () {
      const dueA = SessionNewItem(entityType: 0, entityId: 1);
      const dueB = SessionNewItem(entityType: 0, entityId: 2);
      const new1 = SessionNewItem(entityType: 0, entityId: 11);
      const new2 = SessionNewItem(entityType: 0, entityId: 12);

      final result = interleaveSessionQueue([dueA, dueB], [new1, new2]);
      expect(result, [dueA, new1, dueB, new2]);
    });

    test('appends the remainder when lists have unequal length', () {
      const dueA = SessionNewItem(entityType: 0, entityId: 1);
      const new1 = SessionNewItem(entityType: 0, entityId: 11);
      const new2 = SessionNewItem(entityType: 0, entityId: 12);

      final result = interleaveSessionQueue([dueA], [new1, new2]);
      expect(result, [dueA, new1, new2]);
    });

    test('empty due list -> queue is exactly the new items', () {
      const new1 = SessionNewItem(entityType: 0, entityId: 11);
      final result = interleaveSessionQueue(const [], [new1]);
      expect(result, [new1]);
    });
  });

  group('SessionNotifier', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;

    setUp(() async {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());
      await _seedRootAndBinyan(contentDb);
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    ProviderContainer buildContainer({AppSettings? settings, List<dynamic> extraOverrides = const []}) {
      return ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(userDb),
          appDatabaseProvider.overrideWithValue(contentDb),
          settingsProvider.overrideWith(() => _SettingsNotifier(settings ?? AppSettings.defaultSettings())),
          ...extraOverrides,
        ],
      );
    }

    test('empty queue at session start -> phase empty', () async {
      final container = buildContainer(
        settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0),
      );
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, SessionPhase.empty);
      expect(state.queue, isEmpty);
    });

    test('mixed queue: new lexeme first item shows as an introduction step', () async {
      await _insertVerb(contentDb, id: 10, value: 'כתב', translation: 'to write', frequencyRank: 1);

      final container = buildContainer();
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, SessionPhase.ready);
      expect(state.queue, hasLength(1));
      expect(state.currentItem, isA<SessionNewItem>());
      expect((state.currentItem as SessionNewItem).entityId, 10);
    });

    test('due lexical card renders with a narrowed MVP quiz format', () async {
      await _insertVerb(contentDb, id: 20, value: 'קרא', translation: 'to read');
      // Distractor pool: enough unique-translation verbs so the mc4Recognition
      // minimum-distractor guard doesn't fall this back to typedProduction.
      await _insertVerb(contentDb, id: 21, value: 'רץ', translation: 'to run');
      await _insertVerb(contentDb, id: 22, value: 'ישן', translation: 'to sleep');
      await _insertVerb(contentDb, id: 23, value: 'שר', translation: 'to sing');
      await _insertDueCard(userDb, verbId: 20, direction: directionRecognition);

      final container = buildContainer(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0));
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, SessionPhase.ready);
      expect(state.currentItem, isA<SessionDueItem>());
      final dueItem = state.currentItem as SessionDueItem;
      // Learning + step 0 + recognition -> chooseFormat picks mc2Recognition,
      // narrowed to the MVP recognition format.
      expect(dueItem.renderedQuizType, QuizType.mc4Recognition);
    });

    test('completeIntroduction introduces the lexeme and advances the queue', () async {
      await _insertVerb(contentDb, id: 30, value: 'דבר', translation: 'to speak');

      final container = buildContainer();
      addTearDown(container.dispose);
      await _settle(container);

      await container.read(sessionNotifierProvider.notifier).completeIntroduction();
      final state = container.read(sessionNotifierProvider);

      expect(state.phase, SessionPhase.complete);

      final progress = await userDb.select(userDb.lexemeProgressTable).get();
      expect(progress, hasLength(1));
      expect(progress.single.entityId, 30);
      expect(progress.single.status, 0); // active
    });

    test('submitDueAnswer grades under the hood, shows a reaction, never a rating control', () async {
      await _insertVerb(contentDb, id: 40, value: 'שמר', translation: 'to guard');
      final cardId = await _insertDueCard(userDb, verbId: 40, direction: directionRecognition);

      final container = buildContainer(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0));
      addTearDown(container.dispose);
      await _settle(container);

      final dueItem = container.read(sessionNotifierProvider).currentItem as SessionDueItem;
      await container.read(sessionNotifierProvider.notifier).submitDueAnswer(
            QuizResult(quizType: dueItem.renderedQuizType, wasCorrect: true, responseTimeMs: 500),
          );

      final reacting = container.read(sessionNotifierProvider);
      expect(reacting.phase, SessionPhase.reacting);
      expect(reacting.reaction, isNotNull);
      expect(reacting.reaction!.wasCorrect, isTrue);
      expect(reacting.reaction!.healthBefore, isNotNull);
      expect(reacting.reaction!.healthAfter, isNotNull);

      // submitAnswer (the sole path to reviewCard) actually ran: reps advanced
      // (the seeded card already had reps=1 from one prior review).
      final updatedCard = await (userDb.select(userDb.cardFsrsTable)..where((t) => t.id.equals(cardId))).getSingle();
      expect(updatedCard.reps, 2);

      await container.read(sessionNotifierProvider.notifier).dismissReaction();
      expect(container.read(sessionNotifierProvider).phase, SessionPhase.complete);
    });

    test('queue exhaustion sets phase complete', () async {
      await _insertVerb(contentDb, id: 50, value: 'למד', translation: 'to learn');

      final container = buildContainer();
      addTearDown(container.dispose);
      await _settle(container);

      await container.read(sessionNotifierProvider.notifier).completeIntroduction();
      expect(container.read(sessionNotifierProvider).phase, SessionPhase.complete);
    });

    test('reentrancy guard: a double-tap on completeIntroduction only introduces once', () async {
      await _insertVerb(contentDb, id: 60, value: 'ישב', translation: 'to sit');

      final container = buildContainer();
      addTearDown(container.dispose);
      await _settle(container);

      final notifier = container.read(sessionNotifierProvider.notifier);
      // Fire both calls before either's internal await resolves -- the
      // second must no-op rather than double-introduce/double-advance.
      final first = notifier.completeIntroduction();
      final second = notifier.completeIntroduction();
      await Future.wait([first, second]);

      final progress = await userDb.select(userDb.lexemeProgressTable).get();
      expect(progress, hasLength(1));
    });

    test('reentrancy guard: a double-tap on submitDueAnswer only submits once', () async {
      await _insertVerb(contentDb, id: 61, value: 'עמד', translation: 'to stand');
      await _insertDueCard(userDb, verbId: 61, direction: directionRecognition);

      final container = buildContainer(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0));
      addTearDown(container.dispose);
      await _settle(container);

      final notifier = container.read(sessionNotifierProvider.notifier);
      final dueItem = container.read(sessionNotifierProvider).currentItem as SessionDueItem;
      final result = QuizResult(quizType: dueItem.renderedQuizType, wasCorrect: true, responseTimeMs: 100);

      final first = notifier.submitDueAnswer(result);
      final second = notifier.submitDueAnswer(result);
      await Future.wait([first, second]);

      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log, hasLength(1));
    });

    test('mc4Recognition falls back to typedProduction when the content pool lacks >=3 distractors', () async {
      // Only the target verb exists in content.db -- zero distractor
      // candidates, so the quiz can never reach 4 real options.
      await _insertVerb(contentDb, id: 70, value: 'נפל', translation: 'to fall');
      await _insertDueCard(userDb, verbId: 70, direction: directionRecognition);

      final container = buildContainer(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0));
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, SessionPhase.ready);
      final dueItem = state.currentItem as SessionDueItem;
      expect(dueItem.renderedQuizType, QuizType.typedProduction);
      expect(state.quizOptions, isEmpty);
    });

    test('error path: due-queue failure surfaces as phase error, not a crash', () async {
      final container = buildContainer(
        extraOverrides: [
          scheduledReviewServiceProvider.overrideWith(
            (ref) => _FailingScheduledReviewService(
              ref: ref,
              cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
              lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
              conjugationCardRepository: ref.watch(conjugationCardRepositoryProvider),
              answerLogRepository: ref.watch(answerLogRepositoryProvider),
              fsrsParamsRepository: ref.watch(fsrsParamsRepositoryProvider),
              healthService: ref.watch(healthServiceProvider),
              productionCardIntroductionService: ref.watch(productionCardIntroductionServiceProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, SessionPhase.error);
      expect(state.errorMessage, isNotNull);
    });
  });
}
