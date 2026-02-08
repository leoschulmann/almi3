import 'package:almi3/model/db/db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('creates all tables on initialization', () async {
      // Query sqlite_master to check tables exist
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      ).get();

      final tableNames = result.map((row) => row.read<String>('name')).toSet();

      expect(tableNames, contains('root_table'));
      expect(tableNames, contains('binyan_table'));
      expect(tableNames, contains('verb_table'));
      expect(tableNames, contains('gizrah_table'));
      expect(tableNames, contains('preposition_table'));
    });

    test('schemaVersion is 1', () {
      expect(db.schemaVersion, 1);
    });
  });
}
