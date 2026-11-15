import 'dart:math';

import 'package:almi3/core/logger.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart';
import 'package:almi3/model/fsrs/lexeme_status_actions.dart' show lexemeStatusIgnored;
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/viewmodel/session_notifier.dart' show contentLangProvider;
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show verbRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home-screen status: due/new counts, read straight from the engine (CAP-2).
/// Never recomputed/estimated here -- N and M are exactly what the engine
/// services report.
class HomeStatus {
  final int dueCount;
  final int newCount;

  const HomeStatus({required this.dueCount, required this.newCount});
}

/// N = getDueQueue().length; M = selectNewLexemes(remaining).length, where
/// remaining = max(0, newCardsPerDay - countIntroducedToday(dayBoundaryHour))
/// (§9.3 soft limit already baked into M -- no separate limit UI needed).
final homeStatusProvider = FutureProvider<HomeStatus>((ref) async {
  final scheduledReviewService = ref.watch(scheduledReviewServiceProvider);
  final lexemeSelectionService = ref.watch(lexemeSelectionServiceProvider);
  final settings = ref.watch(settingsProvider);

  try {
    final dueQueue = await scheduledReviewService.getDueQueue();

    final introducedToday = await lexemeSelectionService.countIntroducedToday(
      settings.dayBoundaryHour,
    );
    final remaining = max(0, settings.newCardsPerDay - introducedToday);
    final newLexemes = await lexemeSelectionService.selectNewLexemes(remaining);

    return HomeStatus(dueCount: dueQueue.length, newCount: newLexemes.length);
  } catch (e, st) {
    logger.e('homeStatusProvider: failed to load due/new counts', error: e, stackTrace: st);
    rethrow;
  }
});

/// §10's "ненавязчивый счётчик убранных" -- N = COUNT(lexeme_progress WHERE
/// status=ignored), the single count CAP-8 requires literally (there's no
/// equivalent counter for "known" -- that door is a plain link, §"Decided").
final ignoredWordsCountProvider = FutureProvider<int>((ref) async {
  final lexemeProgressRepository = ref.watch(lexemeProgressRepositoryProvider);
  final rows = await lexemeProgressRepository.getByStatus(lexemeStatusIgnored);
  return rows.length;
});

// Distinct lexeme_progress rows with an assertKnown answer_log entry,
// entity_type = verb, AND a resolvable verb detail (vocab.db has no FK to
// user.db -- a stale/missing entity_id is possible). This repeats
// KnownWordsPage._load's exact filtering (including the getVerbDetail
// null-skip) row by row so the Settings counter never overstates what the
// list screen actually shows.
final knownWordsCountProvider = FutureProvider<int>((ref) async {
  final answerLogRepository = ref.watch(answerLogRepositoryProvider);
  final lexemeProgressRepository = ref.watch(lexemeProgressRepositoryProvider);
  final verbRepo = ref.watch(verbRepositoryProvider);
  final ids = await answerLogRepository.getLexemeProgressIdsWithAssertKnownLog();

  final lang = ref.read(contentLangProvider);
  var count = 0;
  for (final id in ids) {
    final progress = await lexemeProgressRepository.getById(id);
    if (progress == null || progress.entityType != entityTypeVerb) continue;
    final detail = await verbRepo.getVerbDetail(progress.entityId, lang);
    if (detail == null) continue;
    count++;
  }
  return count;
});
