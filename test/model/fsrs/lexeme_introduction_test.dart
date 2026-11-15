import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_state.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LexemeIntroductionService.introduceLexeme', () {
    late UserDatabase db;
    late LexemeIntroductionService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      service = LexemeIntroductionService(
        lexemeProgressRepository: LexemeProgressRepository(db),
        cardFsrsRepository: CardFsrsRepository(db),
        lexicalCardRepository: LexicalCardRepository(db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('creates exactly one lexeme_progress + card_fsrs + lexical_card (recognition)', () async {
      final lexemeProgressId = await service.introduceLexeme(0, 42);

      final progress = await LexemeProgressRepository(db).getByEntity(0, 42);
      expect(progress, isNotNull);
      expect(progress!.id, lexemeProgressId);
      expect(progress.status, lexemeStatusActive);
      expect(progress.firstSeenAt, isNotNull);

      final lexicalCards = await LexicalCardRepository(db).getByLexeme(lexemeProgressId);
      expect(lexicalCards, hasLength(1));
      expect(lexicalCards.single.direction, lexicalDirectionRecognition);

      final card = await CardFsrsRepository(db).getById(lexicalCards.single.cardId);
      expect(card, isNotNull);
      expect(card!.cardType, cardTypeLexical);
      expect(card.state, 1); // Learning
      expect(isNew(card.reps, card.lastReview != null ? DateTime.fromMillisecondsSinceEpoch(card.lastReview! * 1000) : null), isTrue);
    });

    test('is idempotent for an already-introduced entity', () async {
      final firstId = await service.introduceLexeme(0, 42);
      final secondId = await service.introduceLexeme(0, 42);

      expect(secondId, firstId);

      final lexicalCards = await LexicalCardRepository(db).getByLexeme(firstId);
      expect(lexicalCards, hasLength(1));
    });
  });
}
