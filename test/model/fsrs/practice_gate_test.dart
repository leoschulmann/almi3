import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/practice_gate.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/drift.dart';
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

  group('shouldCountPractice', () {
    late UserDatabase db;
    late ProviderContainer container;
    late HealthService healthService;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(db),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
      healthService = container.read(healthServiceProvider);
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

    test('fresh card (retrievability > threshold) is rejected even for a strong format', () async {
      final now = DateTime.now().toUtc();
      final row = await insertCard(
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      );

      final result = await shouldCountPractice(
        row: row,
        quizType: QuizType.typedProduction,
        healthService: healthService,
      );
      expect(result, isFalse);
    });

    test('weak MC format is rejected even on a mature, due card', () async {
      final now = DateTime.now().toUtc();
      final row = await insertCard(
        state: fsrs.State.review.value,
        stability: 5,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
      );

      final result = await shouldCountPractice(
        row: row,
        quizType: QuizType.mc4Recognition,
        healthService: healthService,
      );
      expect(result, isFalse);
    });

    test('mature card with a strong format counts as a real review', () async {
      final now = DateTime.now().toUtc();
      final row = await insertCard(
        state: fsrs.State.review.value,
        stability: 5,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
      );

      final result = await shouldCountPractice(
        row: row,
        quizType: QuizType.typedProduction,
        healthService: healthService,
      );
      expect(result, isTrue);
    });

    test('never-reviewed card (retrievability 0) is not "fresh" and counts with a strong format', () async {
      final row = await insertCard(state: fsrs.State.learning.value, step: 0);

      final result = await shouldCountPractice(
        row: row,
        quizType: QuizType.listening,
        healthService: healthService,
      );
      expect(result, isTrue);
    });
  });
}
