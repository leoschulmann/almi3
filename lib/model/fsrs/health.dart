import 'dart:math';

import 'package:almi3/core/engine_config.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/retrievability.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final healthServiceProvider = Provider(
  (ref) => HealthService(
    ref: ref,
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
    answerLogRepository: ref.watch(answerLogRepositoryProvider),
  ),
);

/// Health (§8.1/§8.2/§8.3): base = retrievability, NOT stability. A
/// lexeme's base health is the MIN retrievability across its cards — it's
/// only "healthy" when every facet (recognition, production, ...) is
/// strong. [lexemeHealthWithBonus] adds a decaying, saturating bonus from
/// recent correct practice answers (read-only — never writes into FSRS).
class HealthService {
  final Ref ref;
  final CardFsrsRepository cardFsrsRepository;
  final LexicalCardRepository lexicalCardRepository;
  final AnswerLogRepository answerLogRepository;

  HealthService({
    required this.ref,
    required this.cardFsrsRepository,
    required this.lexicalCardRepository,
    required this.answerLogRepository,
  });

  /// Retrievability of a single card (0..1), via [fractionalDayRetrievability]
  /// (§8.1: decays continuously between reviews, not a whole-day plateau).
  /// Returns 0 for a never-reviewed card (lastReview == null), matching a
  /// "New" card showing 0% health with no special-casing needed.
  Future<double> cardRetrievability(CardFsrsTableData row, {DateTime? now}) async {
    // Always resolve the scheduler first, even when about to return 0 below:
    // this lazily inserts the default fsrs_params row on first use (see
    // schedulerProvider), a side effect other services rely on having run.
    final scheduler = await ref.read(schedulerProvider.future);
    if (row.lastReview == null || row.stability == null) return 0;
    final derived = deriveFsrsFactorAndDecay(scheduler.parameters);
    return fractionalDayRetrievability(
      stability: row.stability!,
      lastReview: DateTime.fromMillisecondsSinceEpoch(row.lastReview! * 1000, isUtc: true),
      currentDateTime: now ?? DateTime.now().toUtc(),
      factor: derived.factor,
      decay: derived.decay,
    );
  }

  /// Base = min retrievability (0..1) over the lexeme's cards. Null if the
  /// lexeme has no cards (shouldn't happen post-introduction). Also returns
  /// the card ids visited, so callers can pool practice logs over the same
  /// set without a second cards lookup.
  Future<({double? base, List<int> cardIds})> _baseAndCardIds(
    int lexemeProgressId, {
    DateTime? now,
  }) async {
    final lexicalCards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
    if (lexicalCards.isEmpty) return (base: null, cardIds: <int>[]);

    double? minRetrievability;
    final cardIds = <int>[];
    for (final lexicalCard in lexicalCards) {
      final cardRow = await cardFsrsRepository.getById(lexicalCard.cardId);
      if (cardRow == null) continue;
      cardIds.add(lexicalCard.cardId);
      final r = await cardRetrievability(cardRow, now: now);
      if (minRetrievability == null || r < minRetrievability) {
        minRetrievability = r;
      }
    }
    return (base: minRetrievability, cardIds: cardIds);
  }

  /// health(lexeme) = min retrievability over its cards, as 0..100. Null if
  /// the lexeme has no cards (shouldn't happen post-introduction).
  Future<double?> lexemeHealth(int lexemeProgressId, {DateTime? now}) async {
    final result = await _baseAndCardIds(lexemeProgressId, now: now);
    return result.base != null ? result.base! * 100 : null;
  }

  /// Practice bonus (§8.3): a decaying, saturating credit from recent
  /// correct practice answers on any of the lexeme's cards, whether or not
  /// they were gated into a real FSRS review. Pure display layer — never
  /// written back into FSRS.
  Future<double> _practiceBonus(List<int> cardIds, {DateTime? now}) async {
    final nowTime = now ?? DateTime.now().toUtc();
    double raw = 0;
    for (final cardId in cardIds) {
      final logs = await answerLogRepository.getByCard(cardId);
      for (final log in logs) {
        if (log.source != answerSourcePractice || !log.wasCorrect) continue;
        final answeredAt = DateTime.fromMillisecondsSinceEpoch(log.answeredAt * 1000, isUtc: true);
        final daysSince = nowTime.difference(answeredAt).inSeconds / 86400;
        if (daysSince < 0) continue;
        raw += exp(-daysSince / practiceBonusHalflifeDays);
      }
    }
    return practiceBonusSaturationCap * (1 - exp(-raw / practiceBonusK));
  }

  /// health(lexeme) = (base + bonus) * 100 (§8.3) — may exceed 100, meaning
  /// "learned with a buffer". Null if the lexeme has no cards.
  Future<double?> lexemeHealthWithBonus(int lexemeProgressId, {DateTime? now}) async {
    final result = await _baseAndCardIds(lexemeProgressId, now: now);
    if (result.base == null) return null;
    final bonus = await _practiceBonus(result.cardIds, now: now);
    logger.d("Health for lexeme id=$lexemeProgressId: ${result.base}; bonus: $bonus");
    return (result.base! + bonus) * 100;
  }
}
