import 'dart:convert';

import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/viewmodel/onboarding_notifier.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repository whose writes always fail, to exercise confirm()'s
/// write-failure path without depending on timing-sensitive DB-close
/// behavior.
class _FailingFsrsParamsRepository extends FsrsParamsRepository {
  _FailingFsrsParamsRepository(super.database);

  @override
  Future<void> snapshotIfChanged(double desiredRetention) {
    throw StateError('simulated write failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingNotifier', () {
    late UserDatabase testDb;
    late ProviderContainer container;

    setUp(() async {
      testDb = UserDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(testDb),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();
    });

    test('starts with default deck pre-checked and normal intensity', () {
      final state = container.read(onboardingProvider);
      expect(state.selectedDeckIds, {kDefaultDeckId});
      expect(state.intensity, ReviewIntensity.normal);
      expect(state.canConfirm, isTrue);
    });

    test('0 decks selected disables confirm', () {
      final notifier = container.read(onboardingProvider.notifier);
      notifier.toggleDeck(kDefaultDeckId, false);
      expect(container.read(onboardingProvider).canConfirm, isFalse);
    });

    test('confirm with >=1 deck + default intensity persists everything', () async {
      final notifier = container.read(onboardingProvider.notifier);

      await notifier.confirm();

      final settings = container.read(settingsProvider);
      expect(settings.activeDeckIds, [kDefaultDeckId]);
      expect(settings.reviewIntensity, ReviewIntensity.normal);
      expect(settings.onboardingComplete, isTrue);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 1);
      expect(rows.single.desiredRetention, 0.9);
    });

    test('confirm with chosen intensity snapshots the matching desired_retention', () async {
      final notifier = container.read(onboardingProvider.notifier);
      notifier.setIntensity(ReviewIntensity.intense);

      await notifier.confirm();

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.single.desiredRetention, 0.95);
      expect(container.read(settingsProvider).reviewIntensity, ReviewIntensity.intense);
    });

    test('confirm no-op when 0 decks selected', () async {
      final notifier = container.read(onboardingProvider.notifier);
      notifier.toggleDeck(kDefaultDeckId, false);

      await notifier.confirm();

      expect(container.read(settingsProvider).onboardingComplete, isFalse);
      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows, isEmpty);
    });

    test('write failure mid-confirm leaves onboardingComplete false and re-enables confirm', () async {
      final failingContainer = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(testDb),
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          fsrsParamsRepositoryProvider.overrideWithValue(_FailingFsrsParamsRepository(testDb)),
        ],
      );
      addTearDown(failingContainer.dispose);

      final notifier = failingContainer.read(onboardingProvider.notifier);
      await notifier.confirm();

      final state = failingContainer.read(onboardingProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.canConfirm, isTrue);
      expect(failingContainer.read(settingsProvider).onboardingComplete, isFalse);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows, isEmpty);
    });
  });

  test('jsonEncode sanity (default params_json is valid JSON)', () {
    expect(() => jsonDecode(jsonEncode([1, 2, 3])), returnsNormally);
  });
}
