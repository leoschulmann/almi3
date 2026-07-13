import 'package:almi3/core/app_settings.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
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
}
