import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/viewmodel/progress_notifier.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _SettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings.defaultSettings();
}

/// A health service stubbed to return a fixed health value for every
/// lexeme, used to exercise the >=50 bucket boundary precisely (real FSRS
/// retrievability can't be coaxed to land on exactly 50.0).
class _FixedHealthService extends HealthService {
  final double fixedHealth;

  _FixedHealthService({
    required this.fixedHealth,
    required super.ref,
    required super.cardFsrsRepository,
    required super.lexicalCardRepository,
    required super.answerLogRepository,
  });

  @override
  Future<double?> lexemeHealth(int lexemeProgressId, {DateTime? now}) async => fixedHealth;
}

/// Inserts a lexeme_progress row plus a card_fsrs + lexical_card row so
/// HealthService.lexemeHealth has something to compute over.
Future<void> _insertLexemeWithCard(UserDatabase db, {required int due, required int lastReview}) async {
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: due,
          state: fsrs.State.review.value,
          reps: Value(3),
          lastReview: Value(lastReview),
          stability: const Value(10.0),
          difficulty: const Value(5.0),
          createdAt: 1000,
        ),
      );
  final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
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
          lexemeProgressId: lexemeProgressId,
          direction: 0,
        ),
      );
}

/// A repository whose lookup always fails, to exercise
/// progressStatusProvider's error path.
class _FailingLexemeProgressRepository extends LexemeProgressRepository {
  _FailingLexemeProgressRepository(super.database);

  @override
  Future<List<int>> getStartedProgressIds(int entityType) {
    throw StateError('simulated progress-lookup failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('progressStatusProvider', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;

    setUp(() async {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    ProviderContainer buildContainer({List<dynamic> extraOverrides = const []}) {
      return ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(userDb),
          appDatabaseProvider.overrideWithValue(contentDb),
          settingsProvider.overrideWith(() => _SettingsNotifier()),
          ...extraOverrides,
        ],
      );
    }

    test('zero-state: no started lexemes -> 0/0, no error', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final status = await container.read(progressStatusProvider.future);
      expect(status.strongCount, 0);
      expect(status.weakCount, 0);
    });

    test('all-strong: fresh reviews bucket as strong (>=50%)', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await _insertLexemeWithCard(userDb, due: now + 100000, lastReview: now - 100);
      await _insertLexemeWithCard(userDb, due: now + 200000, lastReview: now - 200);

      final container = buildContainer();
      addTearDown(container.dispose);

      final status = await container.read(progressStatusProvider.future);
      expect(status.strongCount, 2);
      expect(status.weakCount, 0);
    });

    test('boundary: health exactly 50 buckets as strong (>= semantics)', () async {
      final progressId = await userDb.into(userDb.lexemeProgressTable).insert(
            LexemeProgressTableCompanion.insert(
              entityType: 0,
              entityId: 1,
              status: 0,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final container = buildContainer(
        extraOverrides: [
          healthServiceProvider.overrideWith(
            (ref) => _FixedHealthService(
              fixedHealth: 50.0,
              ref: ref,
              cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
              lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
              answerLogRepository: ref.watch(answerLogRepositoryProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(progressStatusProvider.future);
      expect(status.strongCount, 1);
      expect(status.weakCount, 0);
      // Sanity: the row exists and was actually looped over.
      expect(progressId, greaterThan(0));
    });

    test('all-weak: long-overdue reviews bucket as weak (<50%)', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await _insertLexemeWithCard(userDb, due: now - 100, lastReview: now - 2000 * 86400);
      await _insertLexemeWithCard(userDb, due: now - 200, lastReview: now - 3000 * 86400);

      final container = buildContainer();
      addTearDown(container.dispose);

      final status = await container.read(progressStatusProvider.future);
      expect(status.strongCount, 0);
      expect(status.weakCount, 2);
    });

    test('mixed: one strong, one weak', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await _insertLexemeWithCard(userDb, due: now + 100000, lastReview: now - 100);
      await _insertLexemeWithCard(userDb, due: now - 100, lastReview: now - 2000 * 86400);

      final container = buildContainer();
      addTearDown(container.dispose);

      final status = await container.read(progressStatusProvider.future);
      expect(status.strongCount, 1);
      expect(status.weakCount, 1);
    });

    test('error path: repository failure surfaces as AsyncError, is caught not thrown raw', () async {
      final container = buildContainer(
        extraOverrides: [
          lexemeProgressRepositoryProvider.overrideWith(
            (ref) => _FailingLexemeProgressRepository(ref.watch(userDbProvider)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(container.read(progressStatusProvider.future), throwsA(isA<StateError>()));

      final state = container.read(progressStatusProvider);
      expect(state, isA<AsyncError>());
    });
  });
}
