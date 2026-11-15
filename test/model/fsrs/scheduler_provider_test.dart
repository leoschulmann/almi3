import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
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

  group('schedulerProvider', () {
    late ProviderContainer container;
    late UserDatabase testDb;

    setUp(() {
      testDb = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(testDb),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();
    });

    test('first call with empty fsrs_params inserts a default row and returns a Scheduler', () async {
      final scheduler = await container.read(schedulerProvider.future);
      expect(scheduler, isA<fsrs.Scheduler>());

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 1);
      expect(rows.single.note, 'default');
    });

    test('second read reuses the existing row rather than inserting another one', () async {
      await container.read(schedulerProvider.future);

      // Force a fresh evaluation of the provider logic against the same DB.
      final container2 = ProviderContainer(
        overrides: [
          userDbProvider.overrideWithValue(testDb),
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
      );
      addTearDown(container2.dispose);

      await container2.read(schedulerProvider.future);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 1);
    });
  });

  group('desiredRetentionForIntensity', () {
    test('maps relaxed/normal/intense to 0.8/0.9/0.95 (§4.1/§9.1)', () {
      expect(desiredRetentionForIntensity(ReviewIntensity.relaxed), 0.8);
      expect(desiredRetentionForIntensity(ReviewIntensity.normal), 0.9);
      expect(desiredRetentionForIntensity(ReviewIntensity.intense), 0.95);
    });
  });

  group('FsrsParamsRepository.snapshotIfChanged', () {
    late UserDatabase testDb;
    late FsrsParamsRepository repo;

    setUp(() {
      testDb = UserDatabase(NativeDatabase.memory());
      repo = FsrsParamsRepository(testDb);
    });

    tearDown(() async => testDb.close());

    test('inserts with default params_json when getLatest() is null', () async {
      await repo.snapshotIfChanged(0.9);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 1);
      expect(rows.single.desiredRetention, 0.9);
      expect(rows.single.note, 'default');
    });

    test('inserts a new row when desired_retention changes', () async {
      await repo.snapshotIfChanged(0.9);
      await repo.snapshotIfChanged(0.95);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 2);
      expect(rows.last.desiredRetention, 0.95);
    });

    test('no-op when desired_retention is unchanged', () async {
      await repo.snapshotIfChanged(0.9);
      await repo.snapshotIfChanged(0.9);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 1);
    });
  });
}
