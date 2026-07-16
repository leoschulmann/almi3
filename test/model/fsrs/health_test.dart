import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
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

Future<int> _insertLexicalCard(
  UserDatabase db, {
  required int direction,
  int state = 0,
  int? step,
  double? stability,
  double? difficulty,
  int? lastReview,
  int? lexemeProgressId,
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
  var progressId = lexemeProgressId;
  progressId ??= await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0,
          entityId: cardId,
          status: 0,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(
          cardId: Value(cardId),
          lexemeProgressId: progressId,
          direction: direction,
        ),
      );
  return progressId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthService', () {
    late UserDatabase db;
    late ProviderContainer container;
    late HealthService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(db),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
      service = container.read(healthServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('cardRetrievability is 0 for a never-reviewed card', () async {
      await _insertLexicalCard(db, direction: directionRecognition, state: fsrs.State.learning.value, step: 0);
      final row = (await db.select(db.cardFsrsTable).get()).single;

      final r = await service.cardRetrievability(row);
      expect(r, 0);
    });

    test('cardRetrievability matches an independently-computed scheduler value', () async {
      final now = DateTime.now().toUtc();
      final lastReview = now.subtract(const Duration(days: 3));
      await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 10,
        difficulty: 5,
        lastReview: lastReview.millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      final scheduler = await container.read(schedulerProvider.future);
      final expected = scheduler.getCardRetrievability(
        fsrs.Card(
          cardId: row.id,
          state: fsrs.State.review,
          stability: 10,
          difficulty: 5,
          due: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          lastReview: lastReview,
        ),
        currentDateTime: now,
      );

      final actual = await service.cardRetrievability(row, now: now);
      expect(actual, expected);
    });

    test('lexemeHealth returns the MIN retrievability across cards, not an average', () async {
      final now = DateTime.now().toUtc();

      // Recognition card: reviewed long ago with high stability -> strong retrievability.
      final lexemeProgressId = await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
      );

      // Production card for the SAME lexeme: never reviewed -> 0 retrievability.
      await _insertLexicalCard(
        db,
        direction: directionProduction,
        state: fsrs.State.learning.value,
        step: 0,
        lexemeProgressId: lexemeProgressId,
      );

      final health = await service.lexemeHealth(lexemeProgressId, now: now);
      expect(health, 0);
    });

    test('lexemeHealth with a single card equals that card\'s retrievability', () async {
      final now = DateTime.now().toUtc();
      final lastReview = now.subtract(const Duration(days: 1));
      final lexemeProgressId = await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 20,
        difficulty: 5,
        lastReview: lastReview.millisecondsSinceEpoch ~/ 1000,
      );

      final row = (await db.select(db.cardFsrsTable).get()).single;
      final cardR = await service.cardRetrievability(row, now: now);
      final health = await service.lexemeHealth(lexemeProgressId, now: now);

      expect(health, cardR * 100);
    });

    test('lexemeHealth returns null for a lexeme with no cards', () async {
      final health = await service.lexemeHealth(999999);
      expect(health, isNull);
    });
  });
}
