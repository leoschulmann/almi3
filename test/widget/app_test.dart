import 'package:almi3/model/db/db.dart';
import 'package:almi3/view/app.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App', () {
    late AppDatabase testDb;

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('loads and shows bottom navigation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
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
