import 'dart:math';

import 'package:almi3/core/logger.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart';
import 'package:almi3/model/fsrs/lexeme_status_actions.dart' show lexemeStatusIgnored;
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
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
