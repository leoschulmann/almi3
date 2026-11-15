import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conjugationCardRepositoryProvider =
    Provider((ref) => ConjugationCardRepository(ref.watch(userDbProvider)));

/// CRUD-only access to conjugation_card. No business logic here.
class ConjugationCardRepository {
  final UserDatabase database;

  ConjugationCardRepository(this.database);

  // INSERT INTO conjugation_card (...) VALUES (...)
  Future<void> insert(ConjugationCardTableCompanion companion) {
    return database.into(database.conjugationCardTable).insert(companion);
  }

  // SELECT * FROM conjugation_card WHERE card_id = ?
  Future<ConjugationCardTableData?> getByCardId(int cardId) {
    return (database.select(database.conjugationCardTable)..where((t) => t.cardId.equals(cardId)))
        .getSingleOrNull();
  }

  // SELECT * FROM conjugation_card
  // WHERE binyan_id = ? AND (gizrah_id = ? OR (gizrah_id IS NULL AND ? IS NULL))
  //   AND tense = ? AND person = ? AND plurality = ? AND gender = ?
  Future<ConjugationCardTableData?> findBySlot({
    required int binyanId,
    required int? gizrahId,
    required int tense,
    required int person,
    required int plurality,
    required int gender,
  }) {
    final query = database.select(database.conjugationCardTable)
      ..where((t) {
        final Expression<bool> gizrahExpr =
            gizrahId != null ? t.gizrahId.equals(gizrahId) : t.gizrahId.isNull();
        return t.binyanId.equals(binyanId) &
            gizrahExpr &
            t.tense.equals(tense) &
            t.person.equals(person) &
            t.plurality.equals(plurality) &
            t.gender.equals(gender);
      });
    return query.getSingleOrNull();
  }
}
