import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
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
}
