import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/conjugation_card_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// card_fsrs.card_type discriminator (§4).
const int cardTypeConjugation = 1;

final conjugationCardIntroductionServiceProvider = Provider(
  (Ref ref) => ConjugationCardIntroductionService(
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    conjugationCardRepository: ref.watch(conjugationCardRepositoryProvider),
  ),
);

/// The single legal entry point for introducing a conjugation-rule card
/// (§7). Unlike lexical cards, WHO decides to introduce a given
/// binyan/gizrah/cell slot is out of scope here (curriculum/admin decision,
/// not automatic) — this just makes the creation idempotent and correct
/// whenever it's called.
///
/// Not a review: no Scheduler.reviewCard call (nothing tested yet).
/// Idempotent on the (binyan, gizrah, tense, person, plurality, gender)
/// slot, which has no db-level UNIQUE constraint (§4's schema is frozen),
/// so idempotency is enforced here in code via a lookup-before-insert.
class ConjugationCardIntroductionService {
  final CardFsrsRepository cardFsrsRepository;
  final ConjugationCardRepository conjugationCardRepository;

  ConjugationCardIntroductionService({
    required this.cardFsrsRepository,
    required this.conjugationCardRepository,
  });

  Future<int> introduceConjugationCard({
    required int binyanId,
    required int? gizrahId,
    required int tense,
    required int person,
    required int plurality,
    required int gender,
  }) async {
    final existing = await conjugationCardRepository.findBySlot(
      binyanId: binyanId,
      gizrahId: gizrahId,
      tense: tense,
      person: person,
      plurality: plurality,
      gender: gender,
    );
    if (existing != null) {
      return existing.cardId;
    }

    final now = nowUtcSeconds();
    final card = await fsrs.Card.create();
    final cardId = await cardFsrsRepository.insertCard(
      libraryCardToCardFsrsCompanion(
        card,
        cardType: cardTypeConjugation,
        reps: 0,
        lapses: 0,
        createdAt: now,
      ),
    );

    await conjugationCardRepository.insert(
      ConjugationCardTableCompanion.insert(
        cardId: Value(cardId),
        binyanId: binyanId,
        gizrahId: Value(gizrahId),
        tense: tense,
        person: person,
        plurality: plurality,
        gender: gender,
      ),
    );

    return cardId;
  }
}
