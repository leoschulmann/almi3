import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsNotifier.setReviewIntensity', () {
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

    test('changed intensity inserts a new fsrs_params row with matching desired_retention', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setReviewIntensity(ReviewIntensity.intense);

      expect(container.read(settingsProvider).reviewIntensity, ReviewIntensity.intense);

      final rows = await testDb.select(testDb.fsrsParamsTable).get();
      expect(rows.length, 1);
      expect(rows.single.desiredRetention, desiredRetentionForIntensity(ReviewIntensity.intense));
    });
  });
}
