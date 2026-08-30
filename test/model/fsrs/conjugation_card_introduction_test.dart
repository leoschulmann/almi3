import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/conjugation_card_introduction.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/conjugation_card_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConjugationCardIntroductionService.introduceConjugationCard', () {
    late UserDatabase db;
    late ConjugationCardIntroductionService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      service = ConjugationCardIntroductionService(
        cardFsrsRepository: CardFsrsRepository(db),
        conjugationCardRepository: ConjugationCardRepository(db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('creates a card_fsrs (cardType=1) + conjugation_card row', () async {
      final cardId = await service.introduceConjugationCard(
        binyanId: 1,
        gizrahId: null,
        tense: 0,
        person: 0,
        plurality: 0,
        gender: 0,
      );

      final cardRow = await CardFsrsRepository(db).getById(cardId);
      expect(cardRow, isNotNull);
      expect(cardRow!.cardType, cardTypeConjugation);
      expect(cardRow.reps, 0);
      expect(cardRow.lastReview, isNull);

      final conjRow = await ConjugationCardRepository(db).getByCardId(cardId);
      expect(conjRow, isNotNull);
      expect(conjRow!.binyanId, 1);
      expect(conjRow.gizrahId, isNull);
    });

    test('is idempotent for the same slot', () async {
      final firstId = await service.introduceConjugationCard(
        binyanId: 1,
        gizrahId: 2,
        tense: 0,
        person: 1,
        plurality: 0,
        gender: 1,
      );
      final secondId = await service.introduceConjugationCard(
        binyanId: 1,
        gizrahId: 2,
        tense: 0,
        person: 1,
        plurality: 0,
        gender: 1,
      );

      expect(secondId, firstId);
      final rows = await db.select(db.conjugationCardTable).get();
      expect(rows, hasLength(1));
    });

    test('a different slot creates a distinct card', () async {
      final firstId = await service.introduceConjugationCard(
        binyanId: 1,
        gizrahId: null,
        tense: 0,
        person: 0,
        plurality: 0,
        gender: 0,
      );
      final secondId = await service.introduceConjugationCard(
        binyanId: 1,
        gizrahId: null,
        tense: 0,
        person: 1, // different person -> different slot
        plurality: 0,
        gender: 0,
      );

      expect(secondId, isNot(firstId));
      final rows = await db.select(db.conjugationCardTable).get();
      expect(rows, hasLength(2));
    });
  });
}
