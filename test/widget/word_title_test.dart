import 'package:almi3/core/enums.dart';
import 'package:almi3/view/widgets/fallback_warning_marker.dart';
import 'package:almi3/view/widgets/word_title.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordTitle fallback marker', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildHarness({required bool translationsIsFallback}) => ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: WordTitle(
                  translations: const ['test'],
                  translationsIsFallback: translationsIsFallback,
                  hebrewValue: 'בדיקה',
                  wordType: WordType.verb,
                ),
              ),
            ),
          ),
        );

    testWidgets('renders FallbackWarningMarker when translationsIsFallback is true', (tester) async {
      await tester.pumpWidget(buildHarness(translationsIsFallback: true));
      await tester.pumpAndSettle();

      expect(find.byType(FallbackWarningMarker), findsOneWidget);
    });

    testWidgets('does not render FallbackWarningMarker when translationsIsFallback is false', (tester) async {
      await tester.pumpWidget(buildHarness(translationsIsFallback: false));
      await tester.pumpAndSettle();

      expect(find.byType(FallbackWarningMarker), findsNothing);
    });
  });
}
