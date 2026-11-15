import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart' show cardTypeLexical;
import 'package:almi3/model/fsrs/production_card_introduction.dart';
import 'package:almi3/model/fsrs/quiz_type.dart' show directionProduction, directionRecognition;
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

CardFsrsTableData _row({required int state, int reps = 0, int? lastReview, int cardType = cardTypeLexical}) =>
    CardFsrsTableData(
      id: 1,
      cardType: cardType,
      due: 0,
      state: state,
      reps: reps,
      lapses: 0,
      lastReview: lastReview,
      createdAt: 0,
    );

void main() {
  group('ProductionCardIntroductionService.introduceProductionCard', () {
    late UserDatabase db;
    late ProductionCardIntroductionService service;
    late LexicalCardRepository lexicalCardRepository;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      lexicalCardRepository = LexicalCardRepository(db);
      service = ProductionCardIntroductionService(
        cardFsrsRepository: CardFsrsRepository(db),
        lexicalCardRepository: lexicalCardRepository,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertLexemeWithRecognitionCard() async {
      final lexemeProgressId = await db.into(db.lexemeProgressTable).insert(
            LexemeProgressTableCompanion.insert(
              entityType: 0,
              entityId: 1,
              status: 0,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      final cardId = await db.into(db.cardFsrsTable).insert(
            CardFsrsTableCompanion.insert(
              cardType: cardTypeLexical,
              due: 0,
              state: fsrs.State.review.value,
              stability: const Value(10),
              difficulty: const Value(5),
              lastReview: const Value(500),
              reps: const Value(3),
              createdAt: 1000,
            ),
          );
      await db.into(db.lexicalCardTable).insert(
            LexicalCardTableCompanion.insert(
              cardId: Value(cardId),
              lexemeProgressId: lexemeProgressId,
              direction: directionRecognition,
            ),
          );
      return lexemeProgressId;
    }

    test('creates a New card_fsrs + lexical_card(direction=production)', () async {
      final lexemeProgressId = await insertLexemeWithRecognitionCard();

      final cardId = await service.introduceProductionCard(lexemeProgressId);

      final cardRow = await CardFsrsRepository(db).getById(cardId);
      expect(cardRow, isNotNull);
      expect(cardRow!.cardType, cardTypeLexical);
      expect(cardRow.reps, 0);
      expect(cardRow.lastReview, isNull);

      final lexicalCard = await lexicalCardRepository.getByCardId(cardId);
      expect(lexicalCard, isNotNull);
      expect(lexicalCard!.direction, directionProduction);
      expect(lexicalCard.lexemeProgressId, lexemeProgressId);
    });

    test('is idempotent: a second call returns the existing production card, no duplicate row', () async {
      final lexemeProgressId = await insertLexemeWithRecognitionCard();

      final firstId = await service.introduceProductionCard(lexemeProgressId);
      final secondId = await service.introduceProductionCard(lexemeProgressId);

      expect(secondId, firstId);
      final allCards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
      expect(allCards.where((c) => c.direction == directionProduction), hasLength(1));
    });
  });

  group('maybeTriggerProductionIntroduction', () {
    late UserDatabase db;
    late LexicalCardRepository lexicalCardRepository;
    late ProductionCardIntroductionService productionService;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      lexicalCardRepository = LexicalCardRepository(db);
      productionService = ProductionCardIntroductionService(
        cardFsrsRepository: CardFsrsRepository(db),
        lexicalCardRepository: lexicalCardRepository,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertRecognitionCard({required int lexemeProgressId, int cardId = 1}) async {
      await db.into(db.cardFsrsTable).insert(
            CardFsrsTableCompanion.insert(
              cardType: cardTypeLexical,
              due: 0,
              state: fsrs.State.review.value,
              createdAt: 1000,
            ),
          );
      await db.into(db.lexicalCardTable).insert(
            LexicalCardTableCompanion.insert(
              cardId: const Value(1),
              lexemeProgressId: lexemeProgressId,
              direction: directionRecognition,
            ),
          );
      return 1;
    }

    Future<int> insertLexemeProgress() => db.into(db.lexemeProgressTable).insert(
          LexemeProgressTableCompanion.insert(
            entityType: 0,
            entityId: 1,
            status: 0,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

    test('fires on Learning->Review transition of a recognition card', () async {
      final lexemeProgressId = await insertLexemeProgress();
      await insertRecognitionCard(lexemeProgressId: lexemeProgressId);

      await maybeTriggerProductionIntroduction(
        beforeRow: _row(state: fsrs.State.learning.value, reps: 0, lastReview: null),
        afterRow: _row(state: fsrs.State.review.value, reps: 1, lastReview: 1000),
        lexicalCardRepository: lexicalCardRepository,
        productionCardIntroductionService: productionService,
      );

      final cards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
      expect(cards.map((c) => c.direction).toSet(), {directionRecognition, directionProduction});
    });

    test('does not fire when the card was already Review before (no fresh graduation)', () async {
      final lexemeProgressId = await insertLexemeProgress();
      await insertRecognitionCard(lexemeProgressId: lexemeProgressId);

      await maybeTriggerProductionIntroduction(
        beforeRow: _row(state: fsrs.State.review.value, reps: 3, lastReview: 500),
        afterRow: _row(state: fsrs.State.review.value, reps: 4, lastReview: 1000),
        lexicalCardRepository: lexicalCardRepository,
        productionCardIntroductionService: productionService,
      );

      final cards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
      expect(cards, hasLength(1));
    });

    test('does not fire when the transition does not reach Review', () async {
      final lexemeProgressId = await insertLexemeProgress();
      await insertRecognitionCard(lexemeProgressId: lexemeProgressId);

      await maybeTriggerProductionIntroduction(
        beforeRow: _row(state: fsrs.State.learning.value, reps: 0, lastReview: null),
        afterRow: _row(state: fsrs.State.learning.value, reps: 1, lastReview: 1000),
        lexicalCardRepository: lexicalCardRepository,
        productionCardIntroductionService: productionService,
      );

      final cards = await lexicalCardRepository.getByLexeme(lexemeProgressId);
      expect(cards, hasLength(1));
    });

    test('does not fire for a conjugation card (cardType != lexical), even on graduation', () async {
      await maybeTriggerProductionIntroduction(
        beforeRow: _row(state: fsrs.State.learning.value, reps: 0, lastReview: null, cardType: 1),
        afterRow: _row(state: fsrs.State.review.value, reps: 1, lastReview: 1000, cardType: 1),
        lexicalCardRepository: lexicalCardRepository,
        productionCardIntroductionService: productionService,
      );

      // No lexical_card lookup should have happened at all; nothing to assert
      // via the db beyond "no exception, no rows created" — confirmed by an
      // empty lexical_card table.
      final allCards = await db.select(db.lexicalCardTable).get();
      expect(allCards, isEmpty);
    });
  });
}
