import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RootRepository', () {
    late AppDatabase db;
    late RootRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = RootRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('insertRoot adds a root to database', () async {
      final dto = RootDto(id: 1, value: 'שלם', version: 1);

      await repository.insertRoot(dto);

      final roots = await repository.getRootsPaged(0, 10);
      expect(roots.length, 1);
      expect(roots.first.id, 1);
      expect(roots.first.value, 'שלם');
    });

    test('upsertRoots inserts new roots', () async {
      final batch = [
        RootDto(id: 1, value: 'כתב', version: 1),
        RootDto(id: 2, value: 'שמר', version: 1),
      ];

      final result = await repository.upsertRoots(batch);

      expect(result.inserted, 2);
      expect(result.updated, 0);
      expect(result.skipped, 0);
    });

    test('upsertRoots updates when version is higher', () async {
      await repository.insertRoot(RootDto(id: 1, value: 'כתב', version: 1));

      final result = await repository.upsertRoots([
        RootDto(id: 1, value: 'כתב-updated', version: 2),
      ]);

      expect(result.updated, 1);
      expect(result.inserted, 0);

      final roots = await repository.getRootsPaged(0, 10);
      expect(roots.first.value, 'כתב-updated');
      expect(roots.first.version, 2);
    });

    test('upsertRoots skips when version is same or lower', () async {
      await repository.insertRoot(RootDto(id: 1, value: 'כתב', version: 5));

      final result = await repository.upsertRoots([
        RootDto(id: 1, value: 'כתב-old', version: 3),
      ]);

      expect(result.skipped, 1);
      expect(result.updated, 0);

      final roots = await repository.getRootsPaged(0, 10);
      expect(roots.first.value, 'כתב'); // unchanged
      expect(roots.first.version, 5);
    });

    test('getRootsPaged returns paginated results', () async {
      for (int i = 1; i <= 25; i++) {
        await repository.insertRoot(RootDto(id: i, value: 'root$i', version: 1));
      }

      final page0 = await repository.getRootsPaged(0, 10);
      final page1 = await repository.getRootsPaged(1, 10);
      final page2 = await repository.getRootsPaged(2, 10);

      expect(page0.length, 10);
      expect(page1.length, 10);
      expect(page2.length, 5);
    });
  });
}
