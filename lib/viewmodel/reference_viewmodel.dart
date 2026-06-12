import 'package:almi3/core/logger.dart';
import 'package:almi3/model/repository/bookmark_repository.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/viewmodel/state/reference_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';

final referencePageProvider =
    NotifierProvider<ReferencePageNotifier, ReferencePageState>(ReferencePageNotifier.new);

final bookmarkRepositoryProvider =
    Provider((ref) => BookmarkRepository(ref.watch(appDatabaseProvider)));

class ReferencePageNotifier extends Notifier<ReferencePageState> {
  late RootRepository _rootRepo;
  late BookmarkRepository _bookmarkRepo;
  int _page = 0;
  static const int _size = 20;

  @override
  ReferencePageState build() {
    _rootRepo = ref.watch(rootRepositoryProvider);
    _bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    ref.watch(syncCounterProvider);
    Future.microtask(() => _loadInit());
    return const ReferencePageState();
  }

  Future<void> _loadInit() async {
    try {
      state = state.copyWith(isLoading: true, errMsg: null);
      final results = await Future.wait([
        _rootRepo.getRootsPaged(_page, _size),
        _bookmarkRepo.getBookmarkedIds(BookmarkType.root),
      ]);
      final roots = results[0] as dynamic;
      final bookmarks = results[1] as Set<int>;
      state = state.copyWith(
        roots: roots,
        bookmarkedRootIds: bookmarks,
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
      state = state.copyWith(
        roots: [...state.roots, ...roots],
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
