import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// lexeme_progress.status values eligible for conjugation-pool inclusion
/// (§7.3: "known" — active or already marked known; ignored is excluded).
const List<int> _knownLexemeStatuses = [0, 1]; // active, known

/// How many of the card's most-recently-shown verbs are excluded when
/// picking the next one, for root interleaving (§7.3.3).
const int conjugationInterleaveWindow = 1;

final conjugationPoolServiceProvider = Provider(
  (ref) => ConjugationPoolService(
    verbRepository: VerbRepository(ref.watch(contentDbProvider)),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
    answerLogRepository: ref.watch(answerLogRepositoryProvider),
  ),
);

/// Computes the verb pool for a conjugation-rule card (§7.2/§7.3) and picks
/// a verb from it with simple root interleaving. No cross-db joins: the
/// "known lexeme" gate is computed in user.db, then used to filter a
/// content.db verb query — two queries composed in Dart (§2.3).
class ConjugationPoolService {
  final VerbRepository verbRepository;
  final LexicalCardRepository lexicalCardRepository;
  final AnswerLogRepository answerLogRepository;

  ConjugationPoolService({
    required this.verbRepository,
    required this.lexicalCardRepository,
    required this.answerLogRepository,
  });

  /// Verbs matching the card's binyan (and gizrah, or "regular" if
  /// gizrahId is null), restricted to lexemes already known (§7.3.1).
  Future<List<int>> getPool(ConjugationCardTableData card) async {
    final knownVerbIds = await lexicalCardRepository.getKnownEntityIds(
      entityType: 0, // verb
      direction: directionRecognition,
      statuses: _knownLexemeStatuses,
      reviewState: fsrs.State.review.value,
    );
    if (knownVerbIds.isEmpty) return [];

    final binyanMatches = await verbRepository.getVerbIdsByBinyan(card.binyanId, knownVerbIds.toList());
    if (binyanMatches.isEmpty) return [];

    if (card.gizrahId != null) {
      final withGizrah = await verbRepository.getVerbIdsWithGizrah(card.gizrahId!, binyanMatches);
      return binyanMatches.where(withGizrah.contains).toList();
    }

    // gizrahId == null: "general pool" of regular verbs (§7.2) — verbs with
    // NO row in verb_gizrah_jointable at all.
    final withAnyGizrah = await verbRepository.getVerbIdsWithAnyGizrah(binyanMatches);
    return binyanMatches.where((id) => !withAnyGizrah.contains(id)).toList();
  }

  /// Picks a verb from [pool], excluding the card's most recently shown
  /// verb(s) (interleaving, §7.3.3). Returns null if the pool is empty.
  Future<int?> pickVerb(int conjugationCardId, List<int> pool) async {
    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.single;

    final recentLogs = await answerLogRepository.getByCard(conjugationCardId);
    final recentVerbIds = recentLogs.reversed
        .map((l) => l.shownVerbId)
        .whereType<int>()
        .take(conjugationInterleaveWindow)
        .toSet();

    final eligible = pool.where((id) => !recentVerbIds.contains(id)).toList();
    return (eligible.isNotEmpty ? eligible : pool).first;
  }
}
