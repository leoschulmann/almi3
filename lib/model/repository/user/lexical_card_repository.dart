import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lexicalCardRepositoryProvider =
    Provider((ref) => LexicalCardRepository(ref.watch(userDbProvider)));

class LexicalCardRepository {
  final UserDatabase database;

  LexicalCardRepository(this.database);

  // INSERT INTO lexical_card (...) VALUES (...)
  Future<void> insert(LexicalCardTableCompanion companion) {
    return database.into(database.lexicalCardTable).insert(companion);
  }

  // SELECT * FROM lexical_card WHERE lexeme_progress_id = ?
  Future<List<LexicalCardTableData>> getByLexeme(int lexemeProgressId) {
    return (database.select(database.lexicalCardTable)
          ..where((t) => t.lexemeProgressId.equals(lexemeProgressId)))
        .get();
  }

  // SELECT * FROM lexical_card WHERE card_id = ?
  Future<LexicalCardTableData?> getByCardId(int cardId) {
    return (database.select(database.lexicalCardTable)..where((t) => t.cardId.equals(cardId)))
        .getSingleOrNull();
  }

  // SELECT lp.entity_id FROM lexeme_progress lp
  // JOIN lexical_card lc ON lc.lexeme_progress_id = lp.id AND lc.direction = ?
  // JOIN card_fsrs cf ON cf.id = lc.card_id
  // WHERE lp.entity_type = ? AND lp.status IN (?) AND cf.state = ?
  //
  // §7.3: only known lexemes may be substituted into a conjugation card's
  // verb pool — "known" = the word's recognition card has reached Review.
  Future<Set<int>> getKnownEntityIds({
    required int entityType,
    required int direction,
    required List<int> statuses,
    required int reviewState,
  }) async {
    final query = database.select(database.lexemeProgressTable).join([
      innerJoin(
        database.lexicalCardTable,
        database.lexicalCardTable.lexemeProgressId.equalsExp(database.lexemeProgressTable.id) &
            database.lexicalCardTable.direction.equals(direction),
      ),
      innerJoin(
        database.cardFsrsTable,
        database.cardFsrsTable.id.equalsExp(database.lexicalCardTable.cardId) &
            database.cardFsrsTable.state.equals(reviewState),
      ),
    ])
      ..where(
        database.lexemeProgressTable.entityType.equals(entityType) &
            database.lexemeProgressTable.status.isIn(statuses),
      );

    final rows = await query.get();
    return rows.map((r) => r.readTable(database.lexemeProgressTable).entityId).toSet();
  }
}
