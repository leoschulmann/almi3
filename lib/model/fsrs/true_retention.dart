import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/card_state.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trueRetentionServiceProvider = Provider(
  (ref) => TrueRetentionService(
    answerLogRepository: ref.watch(answerLogRepositoryProvider),
  ),
);

/// True retention (§12): the honesty gauge for the FSRS mapping. Compare
/// against the active fsrs_params.desired_retention — if true retention is
/// far below it, the mapping is too generous (intervals inflated).
class TrueRetentionService {
  final AnswerLogRepository answerLogRepository;

  TrueRetentionService({required this.answerLogRepository});

  /// Fraction of correct scheduled answers on already-matured cards
  /// (state_before = Review or Relearning) — i.e. real recall tests, not
  /// the New->Learning introduction. Null if there are no qualifying rows.
  Future<double?> trueRetention({DateTime? since, DateTime? until}) async {
    final logs = await answerLogRepository.getBySourceAndStateBefore(
      source: answerSourceScheduled,
      statesBefore: const [stateBeforeReview, stateBeforeRelearning],
      since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
    );
    if (logs.isEmpty) return null;

    final correct = logs.where((l) => l.wasCorrect).length;
    return correct / logs.length;
  }
}
