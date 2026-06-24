import 'package:almi3/core/enums.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/repository/bookmark_repository.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/viewmodel/reference_viewmodel.dart';
import 'package:almi3/viewmodel/state/verb_screen_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final verbScreenProvider =
    NotifierProvider.family<VerbScreenNotifier, VerbScreenState, int>((verbId) => VerbScreenNotifier(verbId));

class VerbScreenNotifier extends Notifier<VerbScreenState> {
  VerbScreenNotifier(this._verbId);

  final int _verbId;
  late VerbRepository _verbRepo;
  late BookmarkRepository _bookmarkRepo;

  static const String _lang = 'EN';

  @override
  VerbScreenState build() {
    _verbRepo = ref.watch(verbRepositoryProvider);
    _bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    Future.microtask(_load);
    return const VerbScreenState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final detail = await _verbRepo.getVerbDetail(_verbId, _lang);
      final bookmarkedFormIds = await _bookmarkRepo.getBookmarkedIds(BookmarkType.verbForm);
      state = state.copyWith(verb: detail, isLoading: false, bookmarkedFormIds: bookmarkedFormIds);
    } catch (e, st) {
      logger.e('VerbScreenNotifier._load error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  Future<void> toggleFormBookmark(int formId) async {
    final updated = Set<int>.from(state.bookmarkedFormIds);
    final willBeBookmarked = !updated.contains(formId);
    if (willBeBookmarked) {
      updated.add(formId);
    } else {
      updated.remove(formId);
    }
    state = state.copyWith(bookmarkedFormIds: updated);

    try {
      await _bookmarkRepo.toggleBookmark(formId, BookmarkType.verbForm);
    } catch (e, st) {
      logger.e('toggleFormBookmark error', error: e, stackTrace: st);
      final rollback = Set<int>.from(state.bookmarkedFormIds);
      if (willBeBookmarked) {
        rollback.remove(formId);
      } else {
        rollback.add(formId);
      }
      state = state.copyWith(bookmarkedFormIds: rollback);
    }
  }
}
