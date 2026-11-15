import 'package:almi3/core/enums.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart' show entityTypeVerb;
import 'package:almi3/model/repository/user/bookmark_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:almi3/viewmodel/session_notifier.dart' show contentLangProvider;
import 'package:almi3/viewmodel/state/verb_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final verbPageProvider =
    NotifierProvider.family<VerbPageNotifier, VerbPageState, int>((verbId) => VerbPageNotifier(verbId));

class VerbPageNotifier extends Notifier<VerbPageState> {
  VerbPageNotifier(this._verbId);

  final int _verbId;
  late VerbRepository _verbRepo;
  late BookmarkRepository _bookmarkRepo;
  late LexemeProgressRepository _lexemeProgressRepo;
  late HealthService _healthService;
  late String _lang;

  @override
  VerbPageState build() {
    _verbRepo = ref.watch(verbRepositoryProvider);
    _bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    _lexemeProgressRepo = ref.watch(lexemeProgressRepositoryProvider);
    _healthService = ref.watch(healthServiceProvider);
    _lang = ref.watch(contentLangProvider);
    Future.microtask(_load);
    return const VerbPageState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final detail = await _verbRepo.getVerbDetail(_verbId, _lang);
      final bookmarkedFormIds = await _bookmarkRepo.getBookmarkedIds(BookmarkType.verbForm);
      // Health is a display-only overlay on top of the core verb page --
      // a failure computing it (e.g. transient DB error) must not take
      // down the whole page, so it's isolated from the outer try/catch.
      double? health;
      try {
        health = await _loadHealth();
      } catch (e, st) {
        logger.e('VerbPageNotifier._loadHealth error', error: e, stackTrace: st);
      }
      state = state.copyWith(verb: detail, isLoading: false, bookmarkedFormIds: bookmarkedFormIds, health: health);
    } catch (e, st) {
      logger.e('VerbPageNotifier._load error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  // No FK between vocab.db and user.db -- join by soft-ref entity id, same
  // pattern as home_notifier.dart's progressStatusProvider.
  Future<double?> _loadHealth() async {
    final progress = await _lexemeProgressRepo.getByEntity(entityTypeVerb, _verbId);
    if (progress == null) return null;
    return _healthService.lexemeHealthWithBonus(progress.id);
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
