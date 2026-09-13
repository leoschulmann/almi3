import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart' show cardTypeLexical;
import 'package:almi3/model/fsrs/quiz_type.dart' show directionProduction, directionRecognition;
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

final productionCardIntroductionServiceProvider = Provider(
  (Ref ref) => ProductionCardIntroductionService(
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
  ),
);

/// The deferred second card on a lemma (§3.3, phase 2): a production card
/// is born once the lexeme's recognition card first reaches Review — not
/// at introduction time. Doesn't create lexeme_progress (the lexeme
/// already exists), so this never counts against the new-lexeme quota
/// (§3.4).
///
/// Not a review: no Scheduler.reviewCard call (nothing tested yet).
/// Idempotent: a lexeme already holding a production card is a no-op.
class ProductionCardIntroductionService {
  final CardFsrsRepository cardFsrsRepository;
  final LexicalCardRepository lexicalCardRepository;

  ProductionCardIntroductionService({
    required this.cardFsrsRepository,
    required this.lexicalCardRepository,
  });

  Future<int> introduceProductionCard(int lexemeProgressId) async {
    final existingCards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
    for (final card in existingCards) {
      if (card.direction == directionProduction) return card.cardId;
    }

    final now = nowUtcSeconds();
    final card = await fsrs.Card.create();
    final cardId = await cardFsrsRepository.insertCard(
      libraryCardToCardFsrsCompanion(
        card,
        cardType: cardTypeLexical,
        reps: 0,
        lapses: 0,
        createdAt: now,
      ),
    );

    await lexicalCardRepository.insert(
      LexicalCardTableCompanion.insert(
        cardId: Value(cardId),
        lexemeProgressId: lexemeProgressId,
        direction: directionProduction,
      ),
    );

    return cardId;
  }
}

/// Called after any real reviewCard on a lexical card (§3.3): if it was
/// the RECOGNITION card and it just graduated into Review for the first
/// time (wasn't Review before, is Review now), spawns the production card.
/// A no-op for conjugation cards (checked cheaply via cardType before any
/// lexical_card lookup) and for anything but a fresh Learning->Review
/// transition.
Future<void> maybeTriggerProductionIntroduction({
  required CardFsrsTableData beforeRow,
  required CardFsrsTableData afterRow,
  required LexicalCardRepository lexicalCardRepository,
  required ProductionCardIntroductionService productionCardIntroductionService,
}) async {
  if (afterRow.cardType != cardTypeLexical) return;
  if (beforeRow.state == fsrs.State.review.value || afterRow.state != fsrs.State.review.value) return;

  final lexicalCard = await lexicalCardRepository.getByCardId(afterRow.id);
  if (lexicalCard == null || lexicalCard.direction != directionRecognition) return;

  await productionCardIntroductionService.introduceProductionCard(lexicalCard.lexemeProgressId);
}
