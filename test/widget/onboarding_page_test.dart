import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/view/onboarding_page.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingPage', () {
    late UserDatabase testUserDb;
    late SharedPreferences prefs;

    setUp(() async {
      testUserDb = UserDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await testUserDb.close();
    });

    Widget harness() => ProviderScope(
          overrides: [
            userDbProvider.overrideWithValue(testUserDb),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: const OnboardingPage(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );

    testWidgets('never shows "retention" or a raw retention number', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final allText = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' | ');

      expect(allText.toLowerCase().contains('retention'), isFalse);
      expect(allText.contains('0.8'), isFalse);
      expect(allText.contains('0.9'), isFalse);
      expect(allText.contains('0.95'), isFalse);
    });

    testWidgets('confirm disabled with 0 decks, enabled with default deck pre-checked', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final buttonAfter = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttonAfter.onPressed, isNull);
    });
  });
}
