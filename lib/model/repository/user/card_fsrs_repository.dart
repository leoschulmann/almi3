import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cardFsrsRepositoryProvider =
    Provider((ref) => CardFsrsRepository(ref.watch(userDbProvider)));

/// CRUD-only access to card_fsrs. No FSRS/business logic here — memory
/// updates must go through Scheduler.reviewCard elsewhere.
class CardFsrsRepository {
  final UserDatabase database;

  CardFsrsRepository(this.database);

  // INSERT INTO card_fsrs (...) VALUES (...)
  Future<int> insertCard(CardFsrsTableCompanion companion) {
    return database.into(database.cardFsrsTable).insert(companion);
  }

  // SELECT * FROM card_fsrs WHERE id = ?
  Future<CardFsrsTableData?> getById(int id) {
    return (database.select(database.cardFsrsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // SELECT * FROM card_fsrs WHERE due <= ?
  Future<List<CardFsrsTableData>> getByDueBefore(int unixSec) {
    return (database.select(database.cardFsrsTable)..where((t) => t.due.isSmallerOrEqualValue(unixSec))).get();
  }

  // SELECT * FROM card_fsrs WHERE state = ?
  Future<List<CardFsrsTableData>> getByState(int state) {
    return (database.select(database.cardFsrsTable)..where((t) => t.state.equals(state))).get();
  }

  // UPDATE card_fsrs SET ... WHERE id = ?
  Future<bool> updateCard(CardFsrsTableCompanion companion) {
    return database.update(database.cardFsrsTable).replace(companion);
  }
}
