import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/view/known_words_page.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:almi3/l10n/app_localizations.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _seedRootAndBinyan(VocabularyDatabase db) async {
  await db.into(db.rootTable).insert(RootTableCompanion.insert(id: const Value(1), value: 'כתב', version: 1));
  await db.into(db.binyanTable).insert(BinyanTableCompanion.insert(id: const Value(1), value: 'פעל', version: 1));
}

Future<void> _insertVerb(VocabularyDatabase db, {required int id, required String value, required String translation}) async {
  await db.into(db.verbTable).insert(VerbTableCompanion.insert(id: Value(id), value: value, version: 1, rootId: 1, binyanId: 1));
  await db.into(db.verbTranslationTable).insert(
        VerbTranslationTableCompanion.insert(id: Value(id * 100), value: translation, version: 1, lang: 'EN', verbId: id),
      );
}

/// Inserts a lexeme with a reviewed (Review-state) card and one assertKnown
/// log row -- mirrors what markLexemeKnown actually produces (§10).
Future<void> _insertKnownLexeme(UserDatabase db, {required int verbId}) async {
  final now = nowUtcSeconds();
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: now + 100000,
          state: fsrs.State.review.value,
          reps: const Value(1),
          lastReview: Value(now),
          stability: const Value(5.0),
          difficulty: const Value(5.0),
          createdAt: now,
        ),
      );
  final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(entityType: 0, entityId: verbId, status: 0, createdAt: now, updatedAt: now),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(cardId: Value(cardId), lexemeProgressId: lexemeProgressId, direction: 0),
      );
  await db.into(db.answerLogTable).insert(
        AnswerLogTableCompanion.insert(
          cardId: cardId,
          answeredAt: now,
          source: answerSourceAssertKnown,
          countedInFsrs: true,
          rating: const Value(4),
          wasCorrect: true,
          quizType: quizTypeNoOp,
          fsrsParamsVersion: 1,
          stateBefore: 0,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KnownWordsPage', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;
    late SharedPreferences prefs;

    setUp(() async {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());
      await _seedRootAndBinyan(contentDb);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    Widget harness() => ProviderScope(
          overrides: [
            userDbProvider.overrideWithValue(userDb),
            appDatabaseProvider.overrideWithValue(contentDb),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: const KnownWordsPage(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );

    testWidgets('empty list shows the empty-state message (matrix: "Список пуст")', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Нет известных слов'), findsOneWidget);
    });

    testWidgets(
      '"Вернуть в изучение" deletes the assertKnown log, resets the card to New, removes it from the list (matrix: "Вернуть" на "Известные слова")',
      (tester) async {
        await _insertVerb(contentDb, id: 2, value: 'קרא', translation: 'to read');
        await _insertKnownLexeme(userDb, verbId: 2);

        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();

        expect(find.textContaining('קרא'), findsOneWidget);

        await tester.tap(find.text('Вернуть в изучение'));
        await tester.pumpAndSettle();

        final logs = await userDb.select(userDb.answerLogTable).get();
        expect(logs, isEmpty);
        final cardRow = (await userDb.select(userDb.cardFsrsTable).get()).single;
        expect(cardRow.reps, 0);
        expect(cardRow.lastReview, null);

        expect(find.text('Нет известных слов'), findsOneWidget);
      },
    );
  });
}
