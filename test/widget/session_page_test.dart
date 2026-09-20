import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/view/home_page.dart';
import 'package:almi3/view/practice_page.dart';
import 'package:almi3/view/session_page.dart';
import 'package:almi3/viewmodel/session_notifier.dart' show backlogWelcomeCopy, newLimitForkCopy;
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
}) async {
  await db.into(db.verbTable).insert(
        VerbTableCompanion.insert(id: Value(id), value: value, version: 1, rootId: 1, binyanId: 1),
      );
  await db.into(db.verbTranslationTable).insert(
        VerbTranslationTableCompanion.insert(id: Value(id * 100), value: translation, version: 1, lang: 'EN', verbId: id),
      );
}

/// Inserts a due lexical card in early Learning (deterministic chooseFormat
/// pick: mc2* for its direction, narrowed to the MVP format).
Future<void> _insertDueCard(UserDatabase db, {required int verbId, required int direction}) async {
  final now = nowUtcSeconds();
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: now - 100,
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
        LexemeProgressTableCompanion.insert(entityType: 0, entityId: verbId, status: 0, createdAt: 1000, updatedAt: 1000),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(cardId: Value(cardId), lexemeProgressId: lexemeProgressId, direction: direction),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionPage', () {
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

    Widget harness({AppSettings? settings}) => ProviderScope(
          overrides: [
            userDbProvider.overrideWithValue(userDb),
            appDatabaseProvider.overrideWithValue(contentDb),
            settingsProvider.overrideWith(() => _SettingsNotifier(settings ?? AppSettings.defaultSettings())),
          ],
          child: const MaterialApp(home: SessionPage()),
        );

    testWidgets('empty queue shows the "nothing to do" state, not a crash', (tester) async {
      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Нечего повторять'), findsOneWidget);
    });

    testWidgets('new-lexeme item shows the introduction screen with "Понятно"', (tester) async {
      await _insertVerb(contentDb, id: 10, value: 'כתב', translation: 'to write');

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('כתב'), findsOneWidget);
      expect(find.text('to write'), findsOneWidget);
      expect(find.text('Понятно'), findsOneWidget);
    });

    testWidgets('tapping "Понятно" introduces the lexeme and ends the (single-item) session', (tester) async {
      await _insertVerb(contentDb, id: 11, value: 'קרא', translation: 'to read');

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      final progress = await userDb.select(userDb.lexemeProgressTable).get();
      expect(progress, hasLength(1));
      expect(progress.single.entityId, 11);
    });

    testWidgets('mc4Recognition due card renders exactly 4 options and no rating control', (tester) async {
      await _insertVerb(contentDb, id: 20, value: 'דבר', translation: 'to speak');
      // Distractor pool: enough unique-translation verbs for a full 4-option quiz.
      await _insertVerb(contentDb, id: 30, value: 'רץ', translation: 'to run');
      await _insertVerb(contentDb, id: 31, value: 'ישן', translation: 'to sleep');
      await _insertVerb(contentDb, id: 32, value: 'שר', translation: 'to sing');
      await _insertDueCard(userDb, verbId: 20, direction: directionRecognition);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      expect(find.text('דבר'), findsOneWidget);
      // All 4 options render (the correct translation plus all 3 distractors
      // -- the pool has exactly 3 other verbs, so no ambiguity about which
      // ones were picked).
      for (final translation in ['to speak', 'to run', 'to sleep', 'to sing']) {
        expect(find.text(translation), findsOneWidget);
      }
      // No Again/Hard/Good/Easy control ever shown (§11 boundaries).
      for (final ratingLabel in ['Again', 'Hard', 'Good', 'Easy', 'Снова', 'Трудно', 'Хорошо', 'Легко']) {
        expect(find.text(ratingLabel), findsNothing);
      }
    });

    testWidgets('mc4Recognition: tapping the correct option grades as correct', (tester) async {
      await _insertVerb(contentDb, id: 24, value: 'קפץ', translation: 'to jump');
      await _insertVerb(contentDb, id: 33, value: 'רץ', translation: 'to run');
      await _insertVerb(contentDb, id: 34, value: 'ישן', translation: 'to sleep');
      await _insertVerb(contentDb, id: 35, value: 'שר', translation: 'to sing');
      await _insertDueCard(userDb, verbId: 24, direction: directionRecognition);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('to jump'));
      await tester.pumpAndSettle();

      expect(find.text('Верно'), findsOneWidget);
      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log.single.wasCorrect, isTrue);
    });

    testWidgets('mc4Recognition: tapping a distractor grades as incorrect', (tester) async {
      await _insertVerb(contentDb, id: 25, value: 'קפץ', translation: 'to jump');
      await _insertVerb(contentDb, id: 36, value: 'רץ', translation: 'to run');
      await _insertVerb(contentDb, id: 37, value: 'ישן', translation: 'to sleep');
      await _insertVerb(contentDb, id: 38, value: 'שר', translation: 'to sing');
      await _insertDueCard(userDb, verbId: 25, direction: directionRecognition);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('to run'));
      await tester.pumpAndSettle();

      expect(find.text('Неверно'), findsOneWidget);
      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log.single.wasCorrect, isFalse);
    });

    testWidgets('typedProduction due card renders a text field and no rating control', (tester) async {
      await _insertVerb(contentDb, id: 21, value: 'שמר', translation: 'to guard');
      await _insertDueCard(userDb, verbId: 21, direction: directionProduction);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      expect(find.text('to guard'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Ответить'), findsOneWidget);
    });

    testWidgets('answering a due card shows a health-delta reaction, then "Далее" advances', (tester) async {
      await _insertVerb(contentDb, id: 22, value: 'למד', translation: 'to learn');
      await _insertDueCard(userDb, verbId: 22, direction: directionProduction);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'למד');
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      expect(find.text('Верно'), findsOneWidget);
      expect(find.text('Далее'), findsOneWidget);

      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      // Single-item queue exhausted -> session pops back (no more Navigator
      // to pop to in this bare-SessionPage harness, so it just stays on the
      // spinner/complete frame without crashing).
      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log, hasLength(1));
      expect(log.single.wasCorrect, isTrue);
    });

    testWidgets('typedProduction: a one-character-off answer is treated as correct-with-typo', (tester) async {
      await _insertVerb(contentDb, id: 26, value: 'כתב', translation: 'to write');
      await _insertDueCard(userDb, verbId: 26, direction: directionProduction);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      // One character off from 'כתב' (ת replaced by כ) -- exercises
      // _isCloseTypo's actual diff-count algorithm, not a hand-set flag.
      await tester.enterText(find.byType(TextField), 'ככב');
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      expect(find.text('Верно'), findsOneWidget);
      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log.single.wasCorrect, isTrue);
      expect(log.single.rating, 2); // Hard -- correct but typo'd (§5.3)
    });

    testWidgets('typedProduction: a clearly wrong answer is graded incorrect', (tester) async {
      await _insertVerb(contentDb, id: 27, value: 'כתב', translation: 'to write');
      await _insertDueCard(userDb, verbId: 27, direction: directionProduction);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'אכל');
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      expect(find.text('Неверно'), findsOneWidget);
      final log = await userDb.select(userDb.answerLogTable).get();
      expect(log.single.wasCorrect, isFalse);
      expect(log.single.rating, 1); // Again
    });

    testWidgets('no FSRS internals (retention/stability/interval) ever appear', (tester) async {
      await _insertVerb(contentDb, id: 23, value: 'אכל', translation: 'to eat');
      await _insertDueCard(userDb, verbId: 23, direction: directionRecognition);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      final allText = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' | ')
          .toLowerCase();

      expect(allText.contains('retention'), isFalse);
      expect(allText.contains('stability'), isFalse);
      expect(allText.contains('interval'), isFalse);
    });

    testWidgets(
      'first day (CAP-6): due=0, new>=2 -> session is all introductions, never the empty state',
      (tester) async {
        await _insertVerb(contentDb, id: 50, value: 'ישב', translation: 'to sit');
        await _insertVerb(contentDb, id: 51, value: 'עמד', translation: 'to stand');

        await tester.pumpWidget(
          harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 2)),
        );
        await tester.pumpAndSettle();

        // Never the "nothing to review" empty state on day one (§11 CAP-6).
        expect(find.textContaining('Нечего повторять'), findsNothing);

        // First introduction card.
        expect(find.text('ישב'), findsOneWidget);
        expect(find.text('to sit'), findsOneWidget);
        expect(find.text('Понятно'), findsOneWidget);

        await tester.tap(find.text('Понятно'));
        await tester.pumpAndSettle();

        // Still no empty-state flash mid-queue; second introduction shows.
        expect(find.textContaining('Нечего повторять'), findsNothing);
        expect(find.text('עמד'), findsOneWidget);
        expect(find.text('to stand'), findsOneWidget);
        expect(find.text('Понятно'), findsOneWidget);

        await tester.tap(find.text('Понятно'));
        await tester.pumpAndSettle();

        // Queue exhausted normally -- same exit path as a mixed session
        // (SessionPage's Navigator.pop on SessionPhase.complete), no
        // special-cased "first day" handling. Both lexemes were introduced.
        expect(find.textContaining('Нечего повторять'), findsNothing);
        final progress = await userDb.select(userDb.lexemeProgressTable).get();
        expect(progress, hasLength(2));
        expect(progress.map((p) => p.entityId).toSet(), {50, 51});
      },
    );

    testWidgets(
      'cap reached with more candidates -> fork screen with exact copy and both actions',
      (tester) async {
        await _insertVerb(contentDb, id: 90, value: 'קם', translation: 'to rise');
        await _insertVerb(contentDb, id: 91, value: 'בא', translation: 'to come');

        await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 1)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Понятно'));
        await tester.pumpAndSettle();

        expect(
          find.text(newLimitForkCopy),
          findsOneWidget,
        );
        expect(find.text('Продолжить с новыми'), findsOneWidget);
        expect(find.text('Потренировать'), findsOneWidget);
      },
    );

    testWidgets('tapping "Продолжить с новыми" resumes the session with more new items', (tester) async {
      await _insertVerb(contentDb, id: 92, value: 'ראה', translation: 'to see');
      await _insertVerb(contentDb, id: 93, value: 'שמע', translation: 'to hear');

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Продолжить с новыми'));
      await tester.pumpAndSettle();

      expect(find.text('שמע'), findsOneWidget);
      expect(find.text('to hear'), findsOneWidget);
      expect(find.text('Понятно'), findsOneWidget);
    });

    testWidgets('tapping "Потренировать" navigates to the practice page', (tester) async {
      await _insertVerb(contentDb, id: 94, value: 'ידע', translation: 'to know');
      await _insertVerb(contentDb, id: 95, value: 'חשב', translation: 'to think');

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Потренировать'));
      await tester.pumpAndSettle();

      expect(find.byType(PracticePage), findsOneWidget);
    });

    testWidgets('due-only session (no new items at all) never shows the fork', (tester) async {
      await _insertVerb(contentDb, id: 96, value: 'שתה', translation: 'to drink');
      await _insertDueCard(userDb, verbId: 96, direction: directionProduction);

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 0)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'שתה');
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      expect(
        find.text(newLimitForkCopy),
        findsNothing,
      );
    });

    testWidgets('cap not reached (fewer candidates than the norm) -> completes normally, no fork', (tester) async {
      // newCardsPerDay=5 but only 1 candidate exists -> the cap is never
      // actually hit, so the fork must never show.
      await _insertVerb(contentDb, id: 97, value: 'גר', translation: 'to live');

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 5)));
      await tester.pumpAndSettle();

      expect(find.text('גר'), findsOneWidget);
      expect(find.text('to live'), findsOneWidget);

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      expect(find.text(newLimitForkCopy), findsNothing);

      final progress = await userDb.select(userDb.lexemeProgressTable).get();
      expect(progress, hasLength(1));
      expect(progress.single.entityId, 97);
    });

    testWidgets('backlog (>30 due) shows the welcome screen with no digits, then "Начать" starts the session', (tester) async {
      for (var i = 0; i < 35; i++) {
        await _insertVerb(contentDb, id: 400 + i, value: 'סגר', translation: 'to close $i');
        await _insertDueCard(userDb, verbId: 400 + i, direction: directionProduction);
      }

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 5)));
      await tester.pumpAndSettle();

      expect(find.text(backlogWelcomeCopy), findsOneWidget);
      expect(find.text('Начать'), findsOneWidget);
      // No raw numbers anywhere in the welcome copy.
      expect(RegExp(r'\d').hasMatch(backlogWelcomeCopy), isFalse);
      // No quiz content shown yet -- welcome precedes the first card.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();

      // Welcome screen is gone; a due-card quiz for the porция now renders.
      expect(find.text(backlogWelcomeCopy), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('no backlog (<=30 due) never shows the welcome screen', (tester) async {
      for (var i = 0; i < 10; i++) {
        await _insertVerb(contentDb, id: 500 + i, value: 'שבר', translation: 'to break $i');
        await _insertDueCard(userDb, verbId: 500 + i, direction: directionProduction);
      }

      await tester.pumpWidget(harness(settings: AppSettings.defaultSettings().copyWith(newCardsPerDay: 5)));
      await tester.pumpAndSettle();

      expect(find.text(backlogWelcomeCopy), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'pushed from HomePage: completing the queue pops back and refreshes home/progress status',
      (tester) async {
        await _insertVerb(contentDb, id: 40, value: 'רקד', translation: 'to dance');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userDbProvider.overrideWithValue(userDb),
              appDatabaseProvider.overrideWithValue(contentDb),
              settingsProvider.overrideWith(() => _SettingsNotifier(AppSettings.defaultSettings())),
            ],
            child: const MaterialApp(home: HomePage()),
          ),
        );
        await tester.pumpAndSettle();

        // Home shows the one new lexeme before the session runs.
        expect(find.text('0 к повторению · 1 новых'), findsOneWidget);
        expect(find.text('Начните заниматься, чтобы увидеть прогресс'), findsOneWidget);

        await tester.tap(find.text('Учиться'));
        await tester.pumpAndSettle();
        expect(find.byType(SessionPage), findsOneWidget);

        await tester.tap(find.text('Понятно'));
        await tester.pumpAndSettle();

        // Queue exhausted -> SessionPage popped itself; we're back on
        // HomePage with real Navigator.pop, and its existing
        // invalidation-on-return refreshed homeStatusProvider/progressStatusProvider.
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(SessionPage), findsNothing);
        // The freshly-introduced card is due immediately (fsrs.Card.create()
        // defaults `due` to now, and it hasn't been reviewed yet) -- real
        // app behavior, not a bug: 0 new remain, but 1 is now due.
        expect(find.text('1 к повторению · 0 новых'), findsOneWidget);
      },
    );
  });
}
