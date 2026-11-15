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
      // Fractional-day calc vs the library's whole-day calc: exact match at an
      // exact-day boundary, up to sub-second storage rounding (lastReview is
      // persisted as unix seconds) and floating-point rounding-order noise.
      expect(actual, closeTo(expected, 1e-6));
    });

    test('cardRetrievability decays within the first calendar day instead of plateauing at 100%', () async {
      final lastReview = DateTime.now().toUtc();
      await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1, // low stability, as after an "Again" streak
        difficulty: 8,
        lastReview: lastReview.millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      final atReview = await service.cardRetrievability(row, now: lastReview);
      final at12h = await service.cardRetrievability(row, now: lastReview.add(const Duration(hours: 12)));
      final at23h = await service.cardRetrievability(row, now: lastReview.add(const Duration(hours: 23)));

      // lastReview is persisted as unix seconds, so up to ~1s of sub-second
      // precision is lost on round-trip — allow for that rounding here.
      expect(atReview, closeTo(1.0, 1e-4));
      // Pinned value (not just monotonicity), so a formula regression that
      // stays monotonic (wrong exponent order, wrong day divisor, ...) still
      // fails: (1 + factor*0.5/1)^decay with the default fsrs weights.
      expect(at12h, closeTo(0.9421983079979164, 1e-4));
      expect(at12h, lessThan(atReview));
      expect(at23h, lessThan(at12h));
    });

    test('cardRetrievability clamps a future lastReview (clock skew) to elapsed=0, not negative', () async {
      final now = DateTime.now().toUtc();
      final lastReview = now.add(const Duration(hours: 2));
      await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 5,
        difficulty: 5,
        lastReview: lastReview.millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      final r = await service.cardRetrievability(row, now: now);
      expect(r, closeTo(1.0, 1e-4));
    });

    test('cardRetrievability stays a valid probability for a long-neglected low-stability card', () async {
      final now = DateTime.now().toUtc();
      final lastReview = now.subtract(const Duration(days: 400));
      await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1,
        difficulty: 8,
        lastReview: lastReview.millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      final r = await service.cardRetrievability(row, now: now);
      expect(r, greaterThanOrEqualTo(0));
      expect(r, lessThan(1.0));
      expect(r.isNaN, isFalse);
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

    test('lexemeHealthWithBonus adds a bonus on top of base from recent correct practice', () async {
      final now = DateTime.now().toUtc();
      final lexemeProgressId = await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      await db.into(db.answerLogTable).insert(
            AnswerLogTableCompanion.insert(
              cardId: row.id,
              answeredAt: now.millisecondsSinceEpoch ~/ 1000,
              source: 1, // practice
              countedInFsrs: false,
              rating: const Value(null),
              wasCorrect: true,
              quizType: QuizType.mc2Recognition.value,
              fsrsParamsVersion: 1,
              stateBefore: 2,
            ),
          );

      final base = await service.lexemeHealth(lexemeProgressId, now: now);
      final composite = await service.lexemeHealthWithBonus(lexemeProgressId, now: now);
      expect(composite, greaterThan(base!));
    });

    test('lexemeHealthWithBonus bonus decays to ~0 after several half-lives', () async {
      final now = DateTime.now().toUtc();
      final longAgo = now.subtract(const Duration(days: 30));
      final lexemeProgressId = await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      await db.into(db.answerLogTable).insert(
            AnswerLogTableCompanion.insert(
              cardId: row.id,
              answeredAt: longAgo.millisecondsSinceEpoch ~/ 1000,
              source: 1, // practice
              countedInFsrs: false,
              rating: const Value(null),
              wasCorrect: true,
              quizType: QuizType.mc2Recognition.value,
              fsrsParamsVersion: 1,
              stateBefore: 2,
            ),
          );

      final base = await service.lexemeHealth(lexemeProgressId, now: now);
      final composite = await service.lexemeHealthWithBonus(lexemeProgressId, now: now);
      expect(composite, closeTo(base!, 0.5));
    });

    test('lexemeHealthWithBonus ignores incorrect and non-practice answer_log rows', () async {
      final now = DateTime.now().toUtc();
      final lexemeProgressId = await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      await db.into(db.answerLogTable).insert(
            AnswerLogTableCompanion.insert(
              cardId: row.id,
              answeredAt: now.millisecondsSinceEpoch ~/ 1000,
              source: 1, // practice
              countedInFsrs: false,
              rating: const Value(null),
              wasCorrect: false, // incorrect -> no bonus
              quizType: QuizType.mc2Recognition.value,
              fsrsParamsVersion: 1,
              stateBefore: 2,
            ),
          );
      await db.into(db.answerLogTable).insert(
            AnswerLogTableCompanion.insert(
              cardId: row.id,
              answeredAt: now.millisecondsSinceEpoch ~/ 1000,
              source: 0, // scheduled, not practice -> no bonus
              countedInFsrs: true,
              rating: const Value(3),
              wasCorrect: true,
              quizType: QuizType.mc2Recognition.value,
              fsrsParamsVersion: 1,
              stateBefore: 2,
            ),
          );

      final base = await service.lexemeHealth(lexemeProgressId, now: now);
      final composite = await service.lexemeHealthWithBonus(lexemeProgressId, now: now);
      expect(composite, base);
    });

    test('lexemeHealthWithBonus saturates and can push health above 100', () async {
      final now = DateTime.now().toUtc();
      final lexemeProgressId = await _insertLexicalCard(
        db,
        direction: directionRecognition,
        state: fsrs.State.review.value,
        stability: 1000,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
      );
      final row = (await db.select(db.cardFsrsTable).get()).single;

      for (var i = 0; i < 20; i++) {
        await db.into(db.answerLogTable).insert(
              AnswerLogTableCompanion.insert(
                cardId: row.id,
                answeredAt: now.millisecondsSinceEpoch ~/ 1000,
                source: 1,
                countedInFsrs: false,
                rating: const Value(null),
                wasCorrect: true,
                quizType: QuizType.mc2Recognition.value,
                fsrsParamsVersion: 1,
                stateBefore: 2,
              ),
            );
      }

      final composite = await service.lexemeHealthWithBonus(lexemeProgressId, now: now);
      expect(composite, greaterThan(100));
      expect(composite, lessThanOrEqualTo(130.0001));
    });
  });
}
