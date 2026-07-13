import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final answerLogRepositoryProvider =
    Provider((ref) => AnswerLogRepository(ref.watch(userDbProvider)));

/// CRUD-only access to answer_log. No business logic here.
class AnswerLogRepository {
  final UserDatabase database;

  AnswerLogRepository(this.database);

  // INSERT INTO answer_log (...) VALUES (...)
  Future<int> insert(AnswerLogTableCompanion companion) {
    return database.into(database.answerLogTable).insert(companion);
  }

  // SELECT * FROM answer_log WHERE card_id = ? ORDER BY answered_at
  Future<List<AnswerLogTableData>> getByCard(int cardId) {
    return (database.select(database.answerLogTable)
          ..where((t) => t.cardId.equals(cardId))
          ..orderBy([(t) => OrderingTerm.asc(t.answeredAt)]))
        .get();
  }
}
