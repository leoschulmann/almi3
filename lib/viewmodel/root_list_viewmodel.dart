import 'package:almi3/core/logger.dart';
import 'package:almi3/model/repository/bookmark_repository.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/viewmodel/state/root_list_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';

final rootListPageProvider =
    NotifierProvider<RootListPageNotifier, RootListPageState>(RootListPageNotifier.new);

class RootListPageNotifier extends Notifier<RootListPageState> {
  late RootRepository _rootRepo;
  late BookmarkRepository _bookmarkRepo;
  late VerbRepository _verbRepo;
  int _page = 0;
  static const int _size = 20;

  @override
  RootListPageState build() {
    _rootRepo = ref.watch(rootRepositoryProvider);
    _bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    _verbRepo = ref.watch(verbRepositoryProvider);
    ref.watch(syncCounterProvider);
    Future.microtask(() => _loadInit());
    return const RootListPageState();
  }

  Future<void> _loadInit() async {
    try {
      state = state.copyWith(isLoading: true, errMsg: null);
      final roots = await _rootRepo.getRootsPaged(_page, _size);
      final bookmarks = await _bookmarkRepo.getBookmarkedIds(BookmarkType.root);
      final rootIds = roots.map((r) => r.id).toList();
      final verbCounts = await _verbRepo.getVerbCountsByRootIds(rootIds);
      state = state.copyWith(
        roots: roots,
        bookmarkedRootIds: bookmarks,
        verbCounts: verbCounts,
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
      state = state.copyWith(
        roots: [...state.roots, ...roots],
        verbCounts: {...state.verbCounts, ...newCounts},
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
