import 'package:almi3/core/logger.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Progress-showcase status (CAP-9): a health-bucket breakdown over started
/// lexemes. Threshold (UI-presentation choice, not an engine-contract
/// change, per story 3): health >= 50% = "крепкое", < 50% = "слабое".
class ProgressStatus {
  final int strongCount;
  final int weakCount;

  const ProgressStatus({required this.strongCount, required this.weakCount});
}

/// strongCount/weakCount = bucket counts of `HealthService.lexemeHealth`
/// (base = retrievability, §8) over all started lexemes
/// (`LexemeProgressRepository.getStartedProgressIds`). No batch health
/// method exists, so lexemes are looped one by one. Never recomputes health
/// itself -- values come only from [HealthService].
final progressStatusProvider = FutureProvider<ProgressStatus>((ref) async {
  final lexemeProgressRepository = ref.watch(lexemeProgressRepositoryProvider);
  final healthService = ref.watch(healthServiceProvider);

  try {
    final progressIds = await lexemeProgressRepository.getStartedProgressIds(entityTypeVerb);

    int strongCount = 0;
    int weakCount = 0;
    for (final progressId in progressIds) {
      final health = await healthService.lexemeHealth(progressId);
      if (health == null) continue;
      if (health >= 50) {
        strongCount++;
      } else {
        weakCount++;
      }
    }

    return ProgressStatus(strongCount: strongCount, weakCount: weakCount);
  } catch (e, st) {
    logger.e('progressStatusProvider: failed to compute health buckets', error: e, stackTrace: st);
    rethrow;
  }
});
