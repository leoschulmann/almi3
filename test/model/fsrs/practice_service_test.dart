import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/practice_service.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _FixedSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings.defaultSettings();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PracticeService', () {
    late UserDatabase db;
    late ProviderContainer container;
    late PracticeService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(db),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
      service = container.read(practiceServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<CardFsrsTableData> insertCard({
      required int state,
      int? step,
      double? stability,
      double? difficulty,
      int? lastReview,
    }) async {
      final cardId = await db.into(db.cardFsrsTable).insert(
            CardFsrsTableCompanion.insert(
              cardType: 0,
              due: 0,
              state: state,
              step: Value(step),
              stability: Value(stability),
              difficulty: Value(difficulty),
              lastReview: Value(lastReview),
              createdAt: 1000,
            ),
          );
      return (await db.select(db.cardFsrsTable).get()).firstWhere((r) => r.id == cardId);
    }

    test('gate true: runs a real reviewCard and logs counted_in_fsrs=true with a rating', () async {
      final now = DateTime.now().toUtc();
      final row = await insertCard(
        state: fsrs.State.review.value,
        stability: 5,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
      );

      final updated = await service.submitPracticeAnswer(
        row: row,
        quizResult: const QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 5000),
      );

      expect(updated.reps, 1);
      expect(updated.lastReview, isNotNull);

      final log = (await db.select(db.answerLogTable).get()).single;
      expect(log.source, 1); // answerSourcePractice
      expect(log.countedInFsrs, isTrue);
      expect(log.rating, isNotNull);
      expect(log.wasCorrect, isTrue);
    });

    test('gate false (fresh card): leaves card_fsrs untouched and logs counted_in_fsrs=false, rating null',
        () async {
      final now = DateTime.now().toUtc();
      final row = await insertCard(
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      );

      final updated = await service.submitPracticeAnswer(
        row: row,
        quizResult: const QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 5000),
      );

      expect(updated.reps, row.reps);
      expect(updated.lastReview, row.lastReview);

      final log = (await db.select(db.answerLogTable).get()).single;
      expect(log.source, 1); // answerSourcePractice
      expect(log.countedInFsrs, isFalse);
      expect(log.rating, isNull);
      expect(log.wasCorrect, isTrue);
      expect(log.fsrsParamsVersion, isNotNull);
    });

    test('gate false (weak format): leaves card_fsrs untouched even on a mature due card', () async {
      final now = DateTime.now().toUtc();
      final row = await insertCard(
        state: fsrs.State.review.value,
        stability: 5,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
      );

      final updated = await service.submitPracticeAnswer(
        row: row,
        quizResult: const QuizResult(quizType: QuizType.mc2Recognition, wasCorrect: true, responseTimeMs: 500),
      );

      expect(updated.reps, row.reps);
      final log = (await db.select(db.answerLogTable).get()).single;
      expect(log.countedInFsrs, isFalse);
    });
  });
}
