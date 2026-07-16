import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final healthServiceProvider = Provider(
  (ref) => HealthService(
    ref: ref,
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
  ),
);

/// Health (§8.1/§8.2): base = retrievability, NOT stability. A lexeme's
/// health is the MIN retrievability across its cards — it's only "healthy"
/// when every facet (recognition, production, ...) is strong. No practice
/// bonus here yet (§8.3) — that's added once free practice/gate (step 11)
/// gives it something to read from.
class HealthService {
  final Ref ref;
  final CardFsrsRepository cardFsrsRepository;
  final LexicalCardRepository lexicalCardRepository;

  HealthService({
    required this.ref,
    required this.cardFsrsRepository,
    required this.lexicalCardRepository,
  });

  /// Retrievability of a single card (0..1). The library already returns 0
  /// for a never-reviewed card (lastReview == null), which happens to match
  /// a "New" card showing 0% health with no special-casing needed.
  Future<double> cardRetrievability(CardFsrsTableData row, {DateTime? now}) async {
    final scheduler = await ref.read(schedulerProvider.future);
    return scheduler.getCardRetrievability(cardFsrsRowToLibraryCard(row), currentDateTime: now);
  }

  /// health(lexeme) = min retrievability over its cards, as 0..100. Null if
  /// the lexeme has no cards (shouldn't happen post-introduction).
  Future<double?> lexemeHealth(int lexemeProgressId, {DateTime? now}) async {
    final lexicalCards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
    if (lexicalCards.isEmpty) return null;

    double? minRetrievability;
    for (final lexicalCard in lexicalCards) {
      final cardRow = await cardFsrsRepository.getById(lexicalCard.cardId);
      if (cardRow == null) continue;
      final r = await cardRetrievability(cardRow, now: now);
      if (minRetrievability == null || r < minRetrievability) {
        minRetrievability = r;
      }
    }
    return minRetrievability != null ? minRetrievability * 100 : null;
  }
}
