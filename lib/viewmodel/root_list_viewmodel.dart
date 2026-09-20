import 'package:almi3/core/clock.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/dto/root_card_stats.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart' show lexemeStatusActive;
import 'package:almi3/model/fsrs/lexeme_selection.dart' show entityTypeVerb;
import 'package:almi3/model/fsrs/quiz_type.dart' show directionRecognition;
import 'package:almi3/model/repository/user/bookmark_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/model/repository/vocab/root_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:almi3/viewmodel/state/root_list_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

import '../core/enums.dart';

final rootListPageProvider =
    NotifierProvider<RootListPageNotifier, RootListPageState>(RootListPageNotifier.new);

class RootListPageNotifier extends Notifier<RootListPageState> {
  late RootRepository _rootRepo;
  late BookmarkRepository _bookmarkRepo;
  late VerbRepository _verbRepo;
  late LexicalCardRepository _lexicalCardRepo;
  int _page = 0;
  static const int _size = 20;

  @override
  RootListPageState build() {
    _rootRepo = ref.watch(rootRepositoryProvider);
    _bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    _verbRepo = ref.watch(verbRepositoryProvider);
    _lexicalCardRepo = ref.watch(lexicalCardRepositoryProvider);
    ref.watch(syncCounterProvider);
    Future.microtask(() => _loadInit());
    return const RootListPageState();
  }

  // For each root id (from rootIds): which roots have at least one due
  // verb ("to review" filter), and each root's verb WordTypeStats (root
  // card progress bar + status lines) -- total from vocab.db's verb_table,
  // learned/due from user.db's lexeme_progress, joined in application code
  // by soft-ref entity id (no FK between the two databases, and this
  // assumes each verb id belongs to exactly one root -- verb_table.root_id
  // is not reassigned at runtime). "Learned" = recognition card reached
  // fsrs.State.review, the same "known" criterion conjugation_pool.dart
  // already uses; "due" (getDueEntityIds) does NOT filter by direction, so
  // it can flag an entity via its production card even though "learned"
  // only ever looks at recognition -- the two counts are drawn from
  // overlapping but not identical card populations, by design (CAP-4's
  // "due" is a lightweight any-card signal, not the recognition-specific
  // "known" gate). Nouns/adjs are intentionally left at WordTypeStats()
  // defaults -- no progress tracking exists for them yet (SPEC non-goal).
  Future<({Set<int> toReviewRootIds, Map<int, RootCardStats> rootStats})> _computeRootData(
    List<int> rootIds,
  ) async {
    final verbIdsByRoot = await _verbRepo.getVerbIdsByRootIds(rootIds);
    final dueVerbIds = await _lexicalCardRepo.getDueEntityIds(
      entityType: entityTypeVerb,
      statuses: const [lexemeStatusActive],
      nowUnixSec: nowUtcSeconds(),
    );
    final learnedVerbIds = await _lexicalCardRepo.getKnownEntityIds(
      entityType: entityTypeVerb,
      direction: directionRecognition,
      statuses: const [lexemeStatusActive],
      reviewState: fsrs.State.review.value,
    );

    final toReviewRootIds = <int>{};
    final rootStats = <int, RootCardStats>{};
    for (final entry in verbIdsByRoot.entries) {
      final verbIds = entry.value;
      if (verbIds.any(dueVerbIds.contains)) toReviewRootIds.add(entry.key);
      rootStats[entry.key] = RootCardStats(
        // nouns/adjs omitted -- see comment above.
        verbs: WordTypeStats(
          total: verbIds.length,
          learned: verbIds.where(learnedVerbIds.contains).length,
          due: verbIds.where(dueVerbIds.contains).length,
        ),
      );
    }
    return (toReviewRootIds: toReviewRootIds, rootStats: rootStats);
  }

  Future<void> _loadInit() async {
    try {
      state = state.copyWith(isLoading: true, errMsg: null);
      final roots = await _rootRepo.getRootsPaged(_page, _size);
      final bookmarks = await _bookmarkRepo.getBookmarkedIds(BookmarkType.root);
      final rootIds = roots.map((r) => r.id).toList();
      final verbCounts = await _verbRepo.getVerbCountsByRootIds(rootIds);
      final rootData = await _computeRootData(rootIds);
      state = state.copyWith(
        roots: roots,
        bookmarkedRootIds: bookmarks,
        verbCounts: verbCounts,
        toReviewRootIds: rootData.toReviewRootIds,
        rootStats: rootData.rootStats,
        isLoading: false,
        hasMore: roots.length == _size,
      );
    } catch (e, st) {
      logger.e('_loadInit() error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    _page++;
    try {
      final roots = await _rootRepo.getRootsPaged(_page, _size);
      final rootIds = roots.map((r) => r.id).toList();
      final newCounts = await _verbRepo.getVerbCountsByRootIds(rootIds);
      final newRootData = await _computeRootData(rootIds);
      state = state.copyWith(
        roots: [...state.roots, ...roots],
        verbCounts: {...state.verbCounts, ...newCounts},
        toReviewRootIds: {...state.toReviewRootIds, ...newRootData.toReviewRootIds},
        rootStats: {...state.rootStats, ...newRootData.rootStats},
        isLoading: false,
        hasMore: roots.length == _size,
      );
    } catch (e, st) {
      _page--;
      logger.e('loadMore: error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  Future<void> refresh() async {
    _page = 0;
    await _loadInit();
  }

  Future<void> toggleBookmark(int rootId) async {
    final updated = Set<int>.from(state.bookmarkedRootIds);
    final willBeBookmarked = !updated.contains(rootId);
    if (willBeBookmarked) {
      updated.add(rootId);
    } else {
      updated.remove(rootId);
    }
    state = state.copyWith(bookmarkedRootIds: updated);

    try {
      await _bookmarkRepo.toggleBookmark(rootId, BookmarkType.root);
    } catch (e, st) {
      logger.e('toggleBookmark: error', error: e, stackTrace: st);
      state = state.copyWith(
        bookmarkedRootIds: Set<int>.from(state.bookmarkedRootIds)..toggle(rootId, willBeBookmarked),
      );
    }
  }
}

extension on Set<int> {
  void toggle(int value, bool add) => add ? this.add(value) : remove(value);
}
