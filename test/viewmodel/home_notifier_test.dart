import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/conjugation_card_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/production_card_introduction.dart';
import 'package:almi3/viewmodel/home_notifier.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _SettingsNotifier extends SettingsNotifier {
  final AppSettings _settings;
  _SettingsNotifier(this._settings);

  @override
  AppSettings build() => _settings;
}

/// A due-queue lookup that always fails, to exercise homeStatusProvider's
/// error path without depending on timing-sensitive DB-close behavior.
class _FailingScheduledReviewService extends ScheduledReviewService {
  _FailingScheduledReviewService({
    required super.ref,
    required super.cardFsrsRepository,
    required super.lexicalCardRepository,
    required super.conjugationCardRepository,
    required super.answerLogRepository,
    required super.fsrsParamsRepository,
    required super.healthService,
    required super.productionCardIntroductionService,
  });

  @override
  Future<List<DueLexicalCard>> getDueQueue({int? limit}) {
    throw StateError('simulated due-queue failure');
  }
}

Future<void> _insertDueLexicalCard(UserDatabase db, {required int due}) async {
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: due,
          state: fsrs.State.review.value,
          reps: Value(3),
          lastReview: Value(due - 86400),
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

Future<void> _insertVerb(VocabularyDatabase contentDb, {required int id, required int frequencyRank}) async {
  await contentDb.into(contentDb.verbTable).insert(
        VerbTableCompanion.insert(
          id: Value(id),
          value: 'v$id',
          version: 1,
          rootId: 1,
          binyanId: 1,
          frequencyRank: Value(frequencyRank),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('homeStatusProvider', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;

    setUp(() async {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());

      await contentDb.into(contentDb.rootTable).insert(
            RootTableCompanion.insert(id: const Value(1), value: 'כתב', version: 1),
          );
      await contentDb.into(contentDb.binyanTable).insert(
            BinyanTableCompanion.insert(id: const Value(1), value: 'פעל', version: 1),
          );
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    ProviderContainer buildContainer(AppSettings settings) {
      return ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(userDb),
          appDatabaseProvider.overrideWithValue(contentDb),
          settingsProvider.overrideWith(() => _SettingsNotifier(settings)),
        ],
      );
    }

    test('normal state: N due cards, M capped-new-available', () async {
      final now = nowUtcSeconds();
      await _insertDueLexicalCard(userDb, due: now - 100);
      await _insertDueLexicalCard(userDb, due: now - 200);
      await _insertVerb(contentDb, id: 10, frequencyRank: 1);
      await _insertVerb(contentDb, id: 20, frequencyRank: 2);
      await _insertVerb(contentDb, id: 30, frequencyRank: 3);

      final container = buildContainer(
        AppSettings.defaultSettings().copyWith(newCardsPerDay: 2),
      );
      addTearDown(container.dispose);

      final status = await container.read(homeStatusProvider.future);
      expect(status.dueCount, 2);
      expect(status.newCount, 2);
    });

    test('nothing due, nothing new -> zero state', () async {
      final container = buildContainer(
        AppSettings.defaultSettings().copyWith(newCardsPerDay: 5),
      );
      addTearDown(container.dispose);

      final status = await container.read(homeStatusProvider.future);
      expect(status.dueCount, 0);
      expect(status.newCount, 0);
    });

    test('daily new-card limit already reached -> M=0 regardless of candidates', () async {
      await _insertVerb(contentDb, id: 10, frequencyRank: 1);
      await _insertVerb(contentDb, id: 20, frequencyRank: 2);

      // introducedToday == newCardsPerDay -> remaining = 0.
      final boundary = dayBoundary(nowUtcSeconds(), 4);
      await userDb.into(userDb.lexemeProgressTable).insert(
            LexemeProgressTableCompanion.insert(
              entityType: 0,
              entityId: 99,
              status: 0,
              firstSeenAt: Value(boundary + 10),
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final container = buildContainer(
        AppSettings.defaultSettings().copyWith(newCardsPerDay: 1),
      );
      addTearDown(container.dispose);

      final status = await container.read(homeStatusProvider.future);
      expect(status.newCount, 0);
    });

    test('remaining caps new count below total candidates', () async {
      await _insertVerb(contentDb, id: 10, frequencyRank: 1);
      await _insertVerb(contentDb, id: 20, frequencyRank: 2);
      await _insertVerb(contentDb, id: 30, frequencyRank: 3);

      final container = buildContainer(
        AppSettings.defaultSettings().copyWith(newCardsPerDay: 1),
      );
      addTearDown(container.dispose);

      final status = await container.read(homeStatusProvider.future);
      expect(status.newCount, 1);
    });

    test('underlying failure surfaces as AsyncError, not a silent default', () async {
      final container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(userDb),
          appDatabaseProvider.overrideWithValue(contentDb),
          settingsProvider.overrideWith(
            () => _SettingsNotifier(AppSettings.defaultSettings().copyWith(newCardsPerDay: 2)),
          ),
          scheduledReviewServiceProvider.overrideWith(
            (ref) => _FailingScheduledReviewService(
              ref: ref,
              cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
              lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
              conjugationCardRepository: ref.watch(conjugationCardRepositoryProvider),
              answerLogRepository: ref.watch(answerLogRepositoryProvider),
              fsrsParamsRepository: ref.watch(fsrsParamsRepositoryProvider),
              healthService: ref.watch(healthServiceProvider),
              productionCardIntroductionService: ref.watch(productionCardIntroductionServiceProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(container.read(homeStatusProvider.future), throwsA(isA<StateError>()));

      final state = container.read(homeStatusProvider);
      expect(state, isA<AsyncError>());
    });
  });
}
