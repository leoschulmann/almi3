import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/true_retention.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _insertLog(
  UserDatabase db, {
  required int source,
  required int stateBefore,
  required bool wasCorrect,
  int answeredAt = 1000,
}) async {
  await db.into(db.answerLogTable).insert(
        AnswerLogTableCompanion.insert(
          cardId: 1,
          answeredAt: answeredAt,
          source: source,
          countedInFsrs: true,
          rating: const Value(3),
          wasCorrect: wasCorrect,
          quizType: 4,
          fsrsParamsVersion: 1,
          stateBefore: stateBefore,
        ),
      );
}

void main() {
  group('TrueRetentionService.trueRetention', () {
    late UserDatabase db;
    late ProviderContainer container;
    late TrueRetentionService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      container = ProviderContainer(overrides: [userDbProvider.overrideWithValue(db)]);
      service = container.read(trueRetentionServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('null when there are no qualifying rows', () async {
      expect(await service.trueRetention(), isNull);
    });

    test('excludes New/Learning (introduction) rows, counts only Review/Relearning', () async {
      // New->Learning introduction: correct, but must NOT count.
      await _insertLog(db, source: 0, stateBefore: 0, wasCorrect: true);
      // Learning-phase step: also must NOT count.
      await _insertLog(db, source: 0, stateBefore: 1, wasCorrect: false);
      // Two real matured reviews: one correct, one wrong.
      await _insertLog(db, source: 0, stateBefore: 2, wasCorrect: true);
      await _insertLog(db, source: 0, stateBefore: 3, wasCorrect: false);

      expect(await service.trueRetention(), 0.5);
    });

    test('excludes practice-source rows even if state_before qualifies', () async {
      await _insertLog(db, source: 1, stateBefore: 2, wasCorrect: true);
      await _insertLog(db, source: 1, stateBefore: 3, wasCorrect: true);

      expect(await service.trueRetention(), isNull);
    });

    test('respects since/until bounds', () async {
      await _insertLog(db, source: 0, stateBefore: 2, wasCorrect: false, answeredAt: 100);
      await _insertLog(db, source: 0, stateBefore: 2, wasCorrect: true, answeredAt: 5000);

      final retention = await service.trueRetention(
        since: DateTime.fromMillisecondsSinceEpoch(4000 * 1000, isUtc: true),
      );
      expect(retention, 1.0);
    });
  });
}
