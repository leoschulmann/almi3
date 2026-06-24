import 'package:almi3/core/logger.dart';
import 'package:almi3/model/repository/bookmark_repository.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/viewmodel/state/word_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';

final wordPageProvider =
    NotifierProvider.family<WordPageNotifier, WordPageState, int>((rootId) => WordPageNotifier(rootId));

class WordPageNotifier extends Notifier<WordPageState> {
  WordPageNotifier(this._rootId);

  final int _rootId;
  late VerbRepository _verbRepo;
  late BookmarkRepository _bookmarkRepo;

  static const String _lang = 'EN';

  @override
  WordPageState build() {
    _verbRepo = ref.watch(verbRepositoryProvider);
    _bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    Future.microtask(_load);
    return const WordPageState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _verbRepo.getVerbsByRootId(_rootId, _lang),
        _bookmarkRepo.getBookmarkedIds(BookmarkType.verb),
      ]);
      state = state.copyWith(
        words: results[0] as dynamic,
        bookmarkedIds: results[1] as Set<int>,
        isLoading: false,
      );
    } catch (e, st) {
      logger.e('WordPageNotifier._load error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  Future<void> toggleBookmark(int wordId) async {
    final updated = Set<int>.from(state.bookmarkedIds);
    final willBeBookmarked = !updated.contains(wordId);
    if (willBeBookmarked) {
      updated.add(wordId);
    } else {
      updated.remove(wordId);
    }
    state = state.copyWith(bookmarkedIds: updated);

    try {
      await _bookmarkRepo.toggleBookmark(wordId, BookmarkType.verb);
    } catch (e, st) {
      logger.e('WordPageNotifier.toggleBookmark error', error: e, stackTrace: st);
      state = state.copyWith(
        bookmarkedIds: Set<int>.from(state.bookmarkedIds)
          ..toggle(wordId, willBeBookmarked),
      );
    }
  }
}

extension on Set<int> {
  void toggle(int value, bool add) => add ? this.add(value) : remove(value);
}
