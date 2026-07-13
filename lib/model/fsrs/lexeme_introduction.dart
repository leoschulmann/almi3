import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// card_fsrs.card_type discriminator (§4).
const int cardTypeLexical = 0;

/// lexical_card.direction (§4). Only recognition is created at introduction
/// (§3.3) — production is deferred to a later trigger (recognition -> Review).
const int lexicalDirectionRecognition = 0;

/// lexeme_progress.status (§4).
const int lexemeStatusActive = 0;

final lexemeIntroductionServiceProvider = Provider(
  (Ref ref) => LexemeIntroductionService(
    lexemeProgressRepository: ref.watch(lexemeProgressRepositoryProvider),
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
  ),
);

/// The single legal entry point for introducing a new lexeme to the learner.
///
/// Creates lexeme_progress + one recognition card_fsrs/lexical_card row.
/// This is NOT a review: no Scheduler.reviewCard call happens here (nothing
/// has been tested yet) — invariant #1 only governs *memory* changes.
/// Idempotent: introducing an already-known (entityType, entityId) is a
/// no-op that returns the existing lexeme_progress id.
class LexemeIntroductionService {
  final LexemeProgressRepository lexemeProgressRepository;
  final CardFsrsRepository cardFsrsRepository;
  final LexicalCardRepository lexicalCardRepository;

  LexemeIntroductionService({
    required this.lexemeProgressRepository,
    required this.cardFsrsRepository,
    required this.lexicalCardRepository,
  });

  Future<int> introduceLexeme(int entityType, int entityId) async {
    final existing = await lexemeProgressRepository.getByEntity(entityType, entityId);
    if (existing != null) {
      return existing.id;
    }

    final now = nowUtcSeconds();
    final lexemeProgressId = await lexemeProgressRepository.insert(
      LexemeProgressTableCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        status: lexemeStatusActive,
        firstSeenAt: Value(now),
        createdAt: now,
        updatedAt: now,
      ),
    );

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
        direction: lexicalDirectionRecognition,
      ),
    );

    return lexemeProgressId;
  }
}
