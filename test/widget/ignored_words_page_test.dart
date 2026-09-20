import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/lexeme_status_actions.dart' show lexemeStatusIgnored;
import 'package:almi3/view/ignored_words_page.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

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

/// Inserts an ignored lexeme_progress row plus a New card_fsrs/lexical_card
/// row -- mirrors what completeIgnore() actually produces (introduceLexeme
/// always runs first, §10).
Future<int> _insertIgnoredLexeme(UserDatabase db, {required int verbId}) async {
  final now = nowUtcSeconds();
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(cardType: 0, due: now, state: fsrs.State.learning.value, createdAt: now),
      );
  final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0,
          entityId: verbId,
          status: lexemeStatusIgnored,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(cardId: Value(cardId), lexemeProgressId: lexemeProgressId, direction: 0),
      );
  return lexemeProgressId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IgnoredWordsPage', () {
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

    Widget harness() => ProviderScope(
          overrides: [
            userDbProvider.overrideWithValue(userDb),
            appDatabaseProvider.overrideWithValue(contentDb),
          ],
          child: const MaterialApp(home: IgnoredWordsPage()),
        );

    testWidgets('empty list shows the empty-state message (matrix: "Список пуст")', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Нет убранных слов'), findsOneWidget);
    });

    testWidgets('"Вернуть в изучение" unignores the lexeme and removes it from the list (matrix: "Вернуть" на "Убранные слова")', (tester) async {
      await _insertVerb(contentDb, id: 1, value: 'כתב', translation: 'to write');
      await _insertIgnoredLexeme(userDb, verbId: 1);

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.textContaining('כתב'), findsOneWidget);

      await tester.tap(find.text('Вернуть в изучение'));
      await tester.pumpAndSettle();

      final progress = await userDb.select(userDb.lexemeProgressTable).get();
      expect(progress.single.status, 0); // active
      expect(find.text('Нет убранных слов'), findsOneWidget);
    });
  });
}
