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

    test('gate true, graduating Learning->Review, spawns a production card (§3.3)', () async {
      final row = await insertCard(state: fsrs.State.learning.value, step: 0);
      final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
            LexemeProgressTableCompanion.insert(
              entityType: 0,
              entityId: 1,
              status: 0,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await db.into(db.lexicalCardTable).insert(
            LexicalCardTableCompanion.insert(
              cardId: Value(row.id),
              lexemeProgressId: lexemeProgressId,
              direction: directionRecognition,
            ),
          );

      final updated = await service.submitPracticeAnswer(
        row: row,
        quizResult: const QuizResult(quizType: QuizType.typedProduction, wasCorrect: true, responseTimeMs: 100),
      );
      expect(updated.state, fsrs.State.review.value);

      final lexicalCards = await db.select(db.lexicalCardTable).get();
      expect(lexicalCards.map((c) => c.direction).toSet(), {directionRecognition, directionProduction});
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
