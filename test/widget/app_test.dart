import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/view/app.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App', () {
    late VocabularyDatabase testDb;
    late UserDatabase testUserDb;
    late SharedPreferences prefs;

    setUp(() async {
      testDb = VocabularyDatabase(NativeDatabase.memory());
      testUserDb = UserDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await testDb.close();
      await testUserDb.close();
    });

    testWidgets('loads and shows bottom navigation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            userDbProvider.overrideWithValue(testUserDb),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const App(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Check for navigation icons instead of text (avoids duplicate text issues)
      expect(find.byIcon(Icons.book), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
      expect(find.byIcon(Icons.quiz), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('navigation tabs are tappable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            userDbProvider.overrideWithValue(testUserDb),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const App(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Sync tab
      await tester.tap(find.byIcon(Icons.sync));
      await tester.pumpAndSettle();

      // Tap on Learn tab
      await tester.tap(find.byIcon(Icons.school));
      await tester.pumpAndSettle();

      // Tap on Quiz tab
      await tester.tap(find.byIcon(Icons.quiz));
      await tester.pumpAndSettle();

      // Tap back to Reference
      await tester.tap(find.byIcon(Icons.book));
      await tester.pumpAndSettle();

      // If we got here without errors, navigation works
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('app has correct title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            userDbProvider.overrideWithValue(testUserDb),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const App(),
        ),
      );

      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'almi yaha');
    });
  });
}
