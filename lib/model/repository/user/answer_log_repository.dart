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

  // DELETE FROM answer_log WHERE id = ?
  Future<void> deleteById(int id) {
    return (database.delete(database.answerLogTable)..where((t) => t.id.equals(id))).go();
  }

  // SELECT * FROM answer_log WHERE source = ? AND state_before IN (?)
  //   [AND answered_at >= ?] [AND answered_at <= ?]
  // NOTE: no index covers (source, state_before) yet — only (card_id,
  // answered_at) and (answered_at) exist. Fine for MVP analytics (not a hot
  // path); add one if this table grows large enough to matter.
  Future<List<AnswerLogTableData>> getBySourceAndStateBefore({
    required int source,
    required List<int> statesBefore,
    int? since,
    int? until,
  }) {
    final query = database.select(database.answerLogTable)
      ..where((t) => t.source.equals(source) & t.stateBefore.isIn(statesBefore));
    if (since != null) {
      query.where((t) => t.answeredAt.isBiggerOrEqualValue(since));
    }
    if (until != null) {
      query.where((t) => t.answeredAt.isSmallerOrEqualValue(until));
    }
    return query.get();
  }
}
