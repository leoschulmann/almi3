import 'dart:async';

import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/viewmodel/root_list_viewmodel.dart';
import 'package:almi3/viewmodel/state/root_list_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

// Far enough in the past/future that real wall-clock time never crosses it,
// so tests don't depend on when they happen to run.
const _pastDue = 1;
const _futureDue = 4102444800; // year 2100

const _statusActive = 0;
const _statusIgnored = 2;
const _directionRecognition = 0;

Future<void> _insertRoot(VocabularyDatabase db, int id) async {
  await db.into(db.rootTable).insert(
        RootTableCompanion.insert(id: Value(id), value: 'r$id', version: 1),
      );
}

Future<void> _insertVerb(VocabularyDatabase db, {required int id, required int rootId}) async {
  await db.into(db.verbTable).insert(
        VerbTableCompanion.insert(id: Value(id), value: 'v$id', version: 1, rootId: rootId, binyanId: 1),
      );
}

/// Gives verb [verbId] a lexeme_progress row (entityType=verb) plus one
/// recognition-direction card_fsrs row, so it participates in the
/// due/learned joins. `state`/`due` control both signals at once, matching
/// how a real recognition card carries both.
Future<void> _insertProgress(
  UserDatabase db, {
  required int verbId,
  required int due,
  required int reviewState,
  int status = _statusActive,
}) async {
  final progressId = await db.into(db.lexemeProgressTable).insert(
        LexemeProgressTableCompanion.insert(
          entityType: 0, // verb
          entityId: verbId,
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
          direction: _directionRecognition,
        ),
      );
}

/// Waits for the notifier's initial async load to finish. Unlike
/// practice_notifier_test.dart's `_settle`, RootListPageState's `isLoading`
/// defaults to `false` at rest (not an explicit "loading" initial phase),
/// so the synchronous state right after `build()` also reads
/// `isLoading == false` -- checking it before subscribing would return
/// immediately with pre-load empty data. Instead this only ever looks at
/// *changes* (no `fireImmediately`): the first is `_loadInit`'s own
/// `isLoading: true`, which is ignored; the next `isLoading == false`
/// change is the real, settled result.
Future<RootListPageState> _settle(ProviderContainer container) async {
  final completer = Completer<RootListPageState>();
  late final ProviderSubscription<RootListPageState> sub;
  sub = container.listen<RootListPageState>(rootListPageProvider, (previous, next) {
    if (!next.isLoading && !completer.isCompleted) completer.complete(next);
  });
  final result = await completer.future;
  sub.close();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RootListPageNotifier._computeRootData (via rootListPageProvider)', () {
    late VocabularyDatabase contentDb;
    late UserDatabase userDb;

    setUp(() {
      contentDb = VocabularyDatabase(NativeDatabase.memory());
      userDb = UserDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    ProviderContainer buildContainer() {
      return ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(contentDb),
          userDbProvider.overrideWithValue(userDb),
        ],
      );
    }

    test(
      'root with zero verbs has no rootStats entry and is never "to review"; '
      'a verb with no lexeme_progress row counts toward total but not learned/due; '
      'an ignored (status != active) verb is excluded from learned/due even though its card is due; '
      'learned and due can both be true for the same verb',
      () async {
        // Root 1: verb1 (active, Review, due -> learned+due), verb2 (no
        // lexeme_progress row at all), verb4 (ignored, Review, due --
        // must NOT count toward learned/due despite an overdue card).
        await _insertRoot(contentDb, 1);
        await _insertVerb(contentDb, id: 1, rootId: 1);
        await _insertVerb(contentDb, id: 2, rootId: 1);
        await _insertVerb(contentDb, id: 4, rootId: 1);
        await _insertProgress(userDb, verbId: 1, due: _pastDue, reviewState: fsrs.State.review.value);
        await _insertProgress(
          userDb,
          verbId: 4,
          due: _pastDue,
          reviewState: fsrs.State.review.value,
          status: _statusIgnored,
        );

        // Root 2: verb3 (active, Review, due in the future -> learned,
        // not due).
        await _insertRoot(contentDb, 2);
        await _insertVerb(contentDb, id: 3, rootId: 2);
        await _insertProgress(userDb, verbId: 3, due: _futureDue, reviewState: fsrs.State.review.value);

        // Root 3: no verbs at all.
        await _insertRoot(contentDb, 3);

        final container = buildContainer();
        addTearDown(container.dispose);

        final state = await _settle(container);

        expect(state.errMsg, isNull);
        expect(state.roots.map((r) => r.id).toSet(), {1, 2, 3});

        // Root 1: total=3 (verb1/2/4 all belong to the root), learned=1
        // (verb1 only -- verb2 has no progress, verb4 is ignored), due=1
        // (verb1 only -- verb4's due card is excluded by status).
        final root1Stats = state.rootStats[1];
        expect(root1Stats, isNotNull);
        expect(root1Stats!.verbs.total, 3);
        expect(root1Stats.verbs.learned, 1);
        expect(root1Stats.verbs.due, 1);
        expect(state.isToReview(1), isTrue);

        // Root 2: total=1, learned=1, due=0 (future due date).
        final root2Stats = state.rootStats[2];
        expect(root2Stats, isNotNull);
        expect(root2Stats!.verbs.total, 1);
        expect(root2Stats.verbs.learned, 1);
        expect(root2Stats.verbs.due, 0);
        expect(state.isToReview(2), isFalse);

        // Root 3: no verbs -> no rootStats entry, never "to review".
        expect(state.rootStats.containsKey(3), isFalse);
        expect(state.isToReview(3), isFalse);
      },
    );

    test('no verbs anywhere -> empty toReviewRootIds/rootStats, no crash', () async {
      await _insertRoot(contentDb, 1);

      final container = buildContainer();
      addTearDown(container.dispose);

      final state = await _settle(container);

      expect(state.errMsg, isNull);
      expect(state.toReviewRootIds, isEmpty);
      expect(state.rootStats, isEmpty);
    });
  });
}
