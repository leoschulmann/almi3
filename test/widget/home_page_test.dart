import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/production_card_introduction.dart';
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/conjugation_card_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/view/home_page.dart';
import 'package:almi3/view/practice_stub_page.dart';
import 'package:almi3/view/session_stub_page.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings.defaultSettings();
}

/// A due-queue lookup that always fails, to exercise HomePage's error-state
/// fallback text without depending on timing-sensitive DB-close behavior.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage', () {
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

    Widget harness() => ProviderScope(
          overrides: [
            userDbProvider.overrideWithValue(userDb),
            appDatabaseProvider.overrideWithValue(contentDb),
            settingsProvider.overrideWith(() => _SettingsNotifier()),
          ],
          child: const MaterialApp(home: HomePage()),
        );

    testWidgets('renders zero-state status text sourced from the engine', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('0 к повторению · 0 новых'), findsOneWidget);
    });

    testWidgets('tapping "Учиться" navigates to the session stub', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Учиться'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionStubPage), findsOneWidget);
    });

    testWidgets('tapping "Тренировка" navigates to the practice stub', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Тренировка'));
      await tester.pumpAndSettle();

      expect(find.byType(PracticeStubPage), findsOneWidget);
    });

    testWidgets('progress-showcase placeholder is present', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Витрина прогресса — скоро'), findsOneWidget);
    });

    testWidgets('no FSRS internals (retention/stability/interval) appear on screen', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final allText = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' | ')
          .toLowerCase();

      expect(allText.contains('retention'), isFalse);
      expect(allText.contains('stability'), isFalse);
      expect(allText.contains('interval'), isFalse);
    });

    testWidgets('renders the em-dash fallback status text when homeStatusProvider errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDbProvider.overrideWithValue(userDb),
            appDatabaseProvider.overrideWithValue(contentDb),
            settingsProvider.overrideWith(() => _SettingsNotifier()),
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
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('— к повторению · — новых'), findsOneWidget);
    });
  });
}
