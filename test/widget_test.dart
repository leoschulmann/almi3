import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/repository/binyan_repository.dart';
import 'package:almi3/model/repository/gizrah_repo.dart';
import 'package:almi3/model/repository/prep_repo.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/viewmodel/reference_viewmodel.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Providers sanity check', () {
    late ProviderContainer container;
    late AppDatabase testDb;

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();
    });

    test('appDatabaseProvider provides AppDatabase', () {
      final db = container.read(appDatabaseProvider);
      expect(db, isA<AppDatabase>());
    });

    test('rootRepositoryProvider provides RootRepository', () {
      final repo = container.read(rootRepositoryProvider);
      expect(repo, isA<RootRepository>());
    });

    test('binyanRepositoryProvider provides BinyanRepository', () {
      final repo = container.read(binyanRepositoryProvider);
      expect(repo, isA<BinyanRepository>());
    });

    test('prepositionRepositoryProvider provides PrepositionRepository', () {
      final repo = container.read(prepositionRepositoryProvider);
      expect(repo, isA<PrepositionRepository>());
    });

    test('gizrahRepositoryProvider provides GizrahRepository', () {
      final repo = container.read(gizrahRepositoryProvider);
      expect(repo, isA<GizrahRepository>());
    });

    test('rootViewmodelProvider provides SyncViewmodelNotifier', () {
      final notifier = container.read(rootViewmodelProvider.notifier);
      expect(notifier, isA<SyncViewmodelNotifier>());
    });

    test('referencePageProvider provides ReferencePageNotifier', () async {
      final notifier = container.read(referencePageProvider.notifier);
      expect(notifier, isA<ReferencePageNotifier>());
      // Allow async init to complete before tearDown disposes the container
      await Future.delayed(Duration.zero);
    });

    test('SyncViewmodelState has correct initial values', () {
      final state = container.read(rootViewmodelProvider);
      expect(state.isLoading, false);
      expect(state.inserted, 0);
      expect(state.updated, 0);
      expect(state.skipped, 0);
      expect(state.errMsg, isNull);
    });
  });
}
