import 'package:almi3/core/enums.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguage.locale', () {
    test('maps each value to its matching ISO Locale, not dbCode', () {
      expect(AppLanguage.en.locale, const Locale('en'));
      expect(AppLanguage.ru.locale, const Locale('ru'));
    });
  });
}
