import 'dart:async';

import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/viewmodel/practice_notifier.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

/// Inserts a "started" lexeme (lexeme_progress + card_fsrs + lexical_card)
/// -- the free-practice candidate pool's exact shape (spec Decided:
/// `getStartedProgressIds`, no `due` filter). Stability/lastReview control
/// the card's retrievability, i.e. whether practice_gate's threshold
/// (§6.3, `stability`/`lastReview` combos matching practice_gate_test.dart)
/// accepts or rejects the answer.
Future<int> _insertStartedLexeme(
  UserDatabase db, {
  required int verbId,
  required int state,
  int? step,
  double? stability,
  double? difficulty,
  int? lastReview,
  int direction = directionRecognition,
}) async {
  final now = nowUtcSeconds();
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: now - 100,
          state: state,
          step: Value(step),
          reps: Value(lastReview != null ? 1 : 0),
          stability: Value(stability),
          difficulty: Value(difficulty),
          lastReview: Value(lastReview),
          createdAt: 1000,
        ),
      );
  final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0,
          entityId: verbId,
          status: 0,
          firstSeenAt: Value(now),
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
/// `loading`), matching session_notifier_test.dart's `_settle`.
Future<PracticeState> _settle(ProviderContainer container) async {
  var state = container.read(practiceNotifierProvider);
  if (state.phase != PracticePhase.loading) return state;

  final completer = Completer<PracticeState>();
  late final ProviderSubscription<PracticeState> sub;
  sub = container.listen<PracticeState>(practiceNotifierProvider, (previous, next) {
    if (next.phase != PracticePhase.loading && !completer.isCompleted) {
      completer.complete(next);
    }
  });
  final result = await completer.future;
  sub.close();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PracticeNotifier', () {
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

    ProviderContainer buildContainer({AppSettings? settings}) {
      return ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(userDb),
          appDatabaseProvider.overrideWithValue(contentDb),
          settingsProvider.overrideWith(() => _SettingsNotifier(settings ?? AppSettings.defaultSettings())),
        ],
      );
    }

    test('no started words -> phase empty, no quiz', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, PracticePhase.empty);
      expect(state.queue, isEmpty);
    });

    test(
      'strong format, mature non-fresh card -> counted in FSRS, reaction shown',
      () async {
        await _insertVerb(contentDb, id: 10, value: 'שמר', translation: 'to guard');
        final now = DateTime.now().toUtc();
        final cardId = await _insertStartedLexeme(
          userDb,
          verbId: 10,
          state: fsrs.State.review.value,
          stability: 5,
          difficulty: 5,
          lastReview: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
        );

        final container = buildContainer();
        addTearDown(container.dispose);
        await _settle(container);

        final notifier = container.read(practiceNotifierProvider.notifier);
        await notifier.submitAnswer(
          const QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 500),
        );

        final reacting = container.read(practiceNotifierProvider);
        expect(reacting.phase, PracticePhase.reacting);
        expect(reacting.reaction, isNotNull);
        expect(reacting.reaction!.wasCorrect, isTrue);
        expect(reacting.reaction!.healthBefore, isNotNull);
        expect(reacting.reaction!.healthAfter, isNotNull);

        final log = (await userDb.select(userDb.answerLogTable).get()).single;
        expect(log.source, 1); // answerSourcePractice
        expect(log.countedInFsrs, isTrue);
        expect(log.rating, isNotNull);

        final updatedCard =
            await (userDb.select(userDb.cardFsrsTable)..where((t) => t.id.equals(cardId))).getSingle();
        expect(updatedCard.reps, 2); // seeded reps=1 (had a lastReview) -> reviewCard advances it
      },
    );

    test(
      'gate rejects (too-fresh card) -> answer only logged, reaction visually identical to a counted answer',
      () async {
        await _insertVerb(contentDb, id: 11, value: 'עמד', translation: 'to stand');
        final now = DateTime.now().toUtc();
        final cardId = await _insertStartedLexeme(
          userDb,
          verbId: 11,
          state: fsrs.State.review.value,
          stability: 1000,
          difficulty: 5,
          lastReview: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        );

        final container = buildContainer();
        addTearDown(container.dispose);
        await _settle(container);

        final notifier = container.read(practiceNotifierProvider.notifier);
        await notifier.submitAnswer(
          const QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 500),
        );

        // Same reacting shape as the counted case -- no "not counted" flag
        // anywhere in state, matching AnswerReaction's visual contract.
        final reacting = container.read(practiceNotifierProvider);
        expect(reacting.phase, PracticePhase.reacting);
        expect(reacting.reaction, isNotNull);
        expect(reacting.reaction!.wasCorrect, isTrue);
        expect(reacting.reaction!.healthBefore, isNotNull);
        expect(reacting.reaction!.healthAfter, isNotNull);

        final log = (await userDb.select(userDb.answerLogTable).get()).single;
        expect(log.source, 1); // answerSourcePractice
        expect(log.countedInFsrs, isFalse);
        expect(log.rating, isNull);

        // card_fsrs was NOT touched by the gated-out answer.
        final updatedCard =
            await (userDb.select(userDb.cardFsrsTable)..where((t) => t.id.equals(cardId))).getSingle();
        expect(updatedCard.reps, 1); // unchanged from the seeded value
      },
    );

    test('single-item pool exhausted after one answer -> phase complete', () async {
      await _insertVerb(contentDb, id: 12, value: 'ישב', translation: 'to sit');
      await _insertStartedLexeme(
        userDb,
        verbId: 12,
        state: fsrs.State.learning.value,
        step: 0,
        stability: 1,
        difficulty: 5,
        lastReview: nowUtcSeconds() - 3600,
      );

      final container = buildContainer();
      addTearDown(container.dispose);
      await _settle(container);

      final notifier = container.read(practiceNotifierProvider.notifier);
      final item = container.read(practiceNotifierProvider).currentItem!;
      await notifier.submitAnswer(
        QuizResult(quizType: item.renderedQuizType, wasCorrect: true, responseTimeMs: 100),
      );
      await notifier.dismissReaction();

      expect(container.read(practiceNotifierProvider).phase, PracticePhase.complete);
    });

    test('2-item pool advances to the second distinct item, then completes', () async {
      await _insertVerb(contentDb, id: 15, value: 'סגר', translation: 'to close');
      await _insertVerb(contentDb, id: 16, value: 'פתח', translation: 'to open');
      await _insertStartedLexeme(
        userDb,
        verbId: 15,
        state: fsrs.State.learning.value,
        step: 0,
        stability: 1,
        difficulty: 5,
        lastReview: nowUtcSeconds() - 3600,
      );
      await _insertStartedLexeme(
        userDb,
        verbId: 16,
        state: fsrs.State.learning.value,
        step: 0,
        stability: 1,
        difficulty: 5,
        lastReview: nowUtcSeconds() - 3600,
      );

      final container = buildContainer();
      addTearDown(container.dispose);
      await _settle(container);

      final notifier = container.read(practiceNotifierProvider.notifier);

      final firstItem = container.read(practiceNotifierProvider).currentItem!;
      final firstEntityId = firstItem.entityId;
      final firstVerb = container.read(practiceNotifierProvider).currentVerb;
      expect({15, 16}, contains(firstEntityId));

      await notifier.submitAnswer(
        QuizResult(quizType: firstItem.renderedQuizType, wasCorrect: true, responseTimeMs: 100),
      );
      await notifier.dismissReaction();

      final secondState = container.read(practiceNotifierProvider);
      expect(secondState.phase, PracticePhase.ready);
      final secondItem = secondState.currentItem!;
      // The second item is the OTHER lexeme, not a repeat of the first --
      // and its loaded verb content actually changed too.
      expect(secondItem.entityId, isNot(firstEntityId));
      expect({15, 16}, contains(secondItem.entityId));
      expect(secondState.currentVerb, isNotNull);
      expect(secondState.currentVerb!.id, isNot(firstVerb?.id));

      await notifier.submitAnswer(
        QuizResult(quizType: secondItem.renderedQuizType, wasCorrect: true, responseTimeMs: 100),
      );
      await notifier.dismissReaction();

      expect(container.read(practiceNotifierProvider).phase, PracticePhase.complete);
    });

    test('still-New card (never reviewed, chooseFormat -> null) is excluded from the pool', () async {
      await _insertVerb(contentDb, id: 13, value: 'קם', translation: 'to rise');
      // No lastReview -> isNew == true -> chooseFormat returns null -> skipped.
      await _insertStartedLexeme(
        userDb,
        verbId: 13,
        state: fsrs.State.learning.value,
        step: 0,
        lastReview: null,
      );

      final container = buildContainer();
      addTearDown(container.dispose);

      final state = await _settle(container);
      expect(state.phase, PracticePhase.empty);
    });

    test('reentrancy guard: a double-tap on submitAnswer only logs once', () async {
      await _insertVerb(contentDb, id: 14, value: 'נתן', translation: 'to give');
      await _insertStartedLexeme(
        userDb,
        verbId: 14,
        state: fsrs.State.learning.value,
        step: 0,
        stability: 1,
        difficulty: 5,
        lastReview: nowUtcSeconds() - 3600,
      );

      final container = buildContainer();
      addTearDown(container.dispose);
      await _settle(container);

      final notifier = container.read(practiceNotifierProvider.notifier);
      final item = container.read(practiceNotifierProvider).currentItem!;
      final result = QuizResult(quizType: item.renderedQuizType, wasCorrect: true, responseTimeMs: 100);

      final first = notifier.submitAnswer(result);
      final second = notifier.submitAnswer(result);
      await Future.wait([first, second]);

      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log, hasLength(1));
    });
  });
}
