import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart';
import 'package:almi3/model/fsrs/lexeme_status_actions.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings.defaultSettings();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LexemeStatusActionsService', () {
    late UserDatabase db;
    late ProviderContainer container;
    late LexemeStatusActionsService service;
    late LexemeIntroductionService introductionService;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(db),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
      service = container.read(lexemeStatusActionsServiceProvider);
      introductionService = container.read(lexemeIntroductionServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('markLexemeKnown runs exactly one Easy review and logs exactly one row', () async {
      final lexemeProgressId = await introductionService.introduceLexeme(0, 1);

      final result = await service.markLexemeKnown(lexemeProgressId);
      expect(result, isNotNull);

      final cardRow = (await db.select(db.cardFsrsTable).get()).single;
      expect(cardRow.reps, 1);
      expect(cardRow.stability, isNotNull);
      expect(cardRow.difficulty, isNotNull);
      expect(cardRow.lastReview, isNotNull);

      final logs = await db.select(db.answerLogTable).get();
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.source, answerSourceAssertKnown);
      expect(log.quizType, quizTypeNoOp);
      expect(log.rating, 4);
      expect(log.wasCorrect, isTrue);
      expect(log.countedInFsrs, isTrue);
    });

    test('undoMarkKnown restores the card to New and deletes the log row (not a compensating Again)', () async {
      final lexemeProgressId = await introductionService.introduceLexeme(0, 1);
      final beforeRow = (await db.select(db.cardFsrsTable).get()).single;

      final result = await service.markLexemeKnown(lexemeProgressId);
      await service.undoMarkKnown(result!);

      final afterRow = (await db.select(db.cardFsrsTable).get()).single;
      expect(afterRow.reps, beforeRow.reps);
      expect(afterRow.stability, beforeRow.stability);
      expect(afterRow.difficulty, beforeRow.difficulty);
      expect(afterRow.lastReview, beforeRow.lastReview);
      expect(afterRow.state, beforeRow.state);

      final logs = await db.select(db.answerLogTable).get();
      expect(logs, isEmpty);
    });

    test('markLexemeKnown returns null when the lexeme has no New card', () async {
      final lexemeProgressId = await introductionService.introduceLexeme(0, 1);
      await service.markLexemeKnown(lexemeProgressId); // card is no longer New

      final second = await service.markLexemeKnown(lexemeProgressId);
      expect(second, isNull);
    });

    test('ignoreLexeme/unignoreLexeme only flip the status flag, no card_fsrs/answer_log writes', () async {
      final lexemeProgressId = await introductionService.introduceLexeme(0, 1);

      await service.ignoreLexeme(lexemeProgressId);
      var progress = await db.select(db.lexemeProgressTable).get();
      expect(progress.single.status, lexemeStatusIgnored);

      await service.unignoreLexeme(lexemeProgressId);
      progress = await db.select(db.lexemeProgressTable).get();
      expect(progress.single.status, lexemeStatusActive);

      final logs = await db.select(db.answerLogTable).get();
      expect(logs, isEmpty);
      final cardRow = (await db.select(db.cardFsrsTable).get()).single;
      expect(cardRow.reps, 0);
    });
  });
}
