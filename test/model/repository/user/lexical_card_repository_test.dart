import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _entityTypeVerb = 0;
const _statusActive = 0;
const _statusIgnored = 2;
const _directionRecognition = 0;

Future<void> _insertProgress(
  UserDatabase db, {
  required int entityId,
  required int due,
  int status = _statusActive,
  int direction = _directionRecognition,
  int reviewState = 2, // fsrs.State.review.value at call sites below
}) async {
  final progressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: _entityTypeVerb,
          entityId: entityId,
          status: status,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
  final cardId = await db.into(db.cardFsrsTable).insert(
        CardFsrsTableCompanion.insert(
          cardType: 0,
          due: due,
          state: reviewState,
          reps: const Value(3),
          lastReview: const Value(0),
          stability: const Value(10.0),
          difficulty: const Value(5.0),
          createdAt: 1000,
        ),
      );
  await db.into(db.lexicalCardTable).insert(
        LexicalCardTableCompanion.insert(
          cardId: Value(cardId),
          lexemeProgressId: progressId,
          direction: direction,
        ),
      );
}

void main() {
  group('LexicalCardRepository.getDueEntityIds', () {
    late UserDatabase db;
    late LexicalCardRepository repo;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      repo = LexicalCardRepository(db);
    });

    tearDown(() async => db.close());

    test('due<=now, active status -> included', () async {
      await _insertProgress(db, entityId: 1, due: 100);

      final result = await repo.getDueEntityIds(
        entityType: _entityTypeVerb,
        statuses: const [_statusActive],
        nowUnixSec: 100,
      );

      expect(result, {1});
    });

    test('due>now -> excluded', () async {
      await _insertProgress(db, entityId: 1, due: 200);

      final result = await repo.getDueEntityIds(
        entityType: _entityTypeVerb,
        statuses: const [_statusActive],
        nowUnixSec: 100,
      );

      expect(result, isEmpty);
    });

    test('due<=now but status not in the requested list -> excluded (e.g. ignored)', () async {
      await _insertProgress(db, entityId: 1, due: 100, status: _statusIgnored);

      final result = await repo.getDueEntityIds(
        entityType: _entityTypeVerb,
        statuses: const [_statusActive],
        nowUnixSec: 100,
      );

      expect(result, isEmpty);
    });

    test('any due card counts -- not restricted to a single direction (unlike getKnownEntityIds)', () async {
      // direction 1 = production, still due -- must still surface the entity.
      await _insertProgress(db, entityId: 1, due: 100, direction: 1);

      final result = await repo.getDueEntityIds(
        entityType: _entityTypeVerb,
        statuses: const [_statusActive],
        nowUnixSec: 100,
      );

      expect(result, {1});
    });

    test('no matching rows -> empty set, no throw', () async {
      final result = await repo.getDueEntityIds(
        entityType: _entityTypeVerb,
        statuses: const [_statusActive],
        nowUnixSec: 100,
      );

      expect(result, isEmpty);
    });
  });
}
