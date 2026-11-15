import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/view/practice_page.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:almi3/l10n/app_localizations.dart';
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
        LexicalCardTableCompanion.insert(cardId: Value(cardId), lexemeProgressId: lexemeProgressId, direction: direction),
      );
  return cardId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PracticePage', () {
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
          child: MaterialApp(
            home: const PracticePage(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );

    testWidgets('no started words -> empty state, no quiz', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Пока нечего тренировать — начните учить слова в сессии'), findsOneWidget);
    });

    testWidgets('renders a quiz for a started word and shows a reaction after answering', (tester) async {
      await _insertVerb(contentDb, id: 1, value: 'כתב', translation: 'to write');
      await _insertStartedLexeme(
        userDb,
        verbId: 1,
        state: fsrs.State.learning.value,
        step: 0,
        stability: 1,
        difficulty: 5,
        lastReview: nowUtcSeconds() - 3600,
      );

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Learning + step 0 + recognition -> mc2Recognition narrowed to
      // mc4Recognition, but the content pool has only this one verb -- the
      // minimum-distractor guard falls it back to typedProduction, exactly
      // like the session's same guard.
      expect(find.text('to write'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'כתב');
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      // No Again/Hard/Good/Easy control -- only "Верно"/"Неверно" + continue.
      expect(find.text('Верно'), findsOneWidget);
      expect(find.text('Again'), findsNothing);
      expect(find.text('Hard'), findsNothing);
      expect(find.text('Good'), findsNothing);
      expect(find.text('Easy'), findsNothing);
    });

    testWidgets(
      'gated-out (too-fresh) answer shows an identical reaction to a counted one -- no "not counted" text',
      (tester) async {
        await _insertVerb(contentDb, id: 2, value: 'עמד', translation: 'to stand');
        final now = DateTime.now().toUtc();
        await _insertStartedLexeme(
          userDb,
          verbId: 2,
          state: fsrs.State.review.value,
          stability: 1000,
          difficulty: 5,
          lastReview: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          direction: directionProduction,
        );

        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();

        // Review + production -> a typedProduction-family format, narrowed to typedProduction.
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'עמד');
        await tester.tap(find.text('Ответить'));
        await tester.pumpAndSettle();

        expect(find.text('Верно'), findsOneWidget);
        expect(find.textContaining('не засчит'), findsNothing);
        expect(find.textContaining('не сохран'), findsNothing);
      },
    );
  });
}
