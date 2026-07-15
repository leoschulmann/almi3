import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/db_providers.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// lexeme_progress.entity_type (§4). Only verbs exist so far.
const int entityTypeVerb = 0;

final lexemeSelectionServiceProvider = Provider(
  (ref) => LexemeSelectionService(
    lexemeProgressRepository: ref.watch(lexemeProgressRepositoryProvider),
    verbRepository: VerbRepository(ref.watch(contentDbProvider)),
  ),
);

/// Selection of new lexemes to introduce (§9.2) and the soft daily-limit
/// read (§9.3). Pure queries — does not call [LexemeIntroductionService]
/// itself, and does not enforce/block anything (the soft limit is a UI
/// decision: show the "goal met" fork, but let the user push past it).
class LexemeSelectionService {
  final LexemeProgressRepository lexemeProgressRepository;
  final VerbRepository verbRepository;

  LexemeSelectionService({
    required this.lexemeProgressRepository,
    required this.verbRepository,
  });

  /// Candidate verbs not yet started (no lexeme_progress row), ordered by
  /// frequency_rank ascending (unranked verbs sort last), capped at [limit].
  ///
  /// TODO(spec §9.1/§9.2): deck filtering (`activeDeckIds`) is not applied
  /// yet — semantic decks (deck/deck_verb tables) don't exist in content.db
  /// yet, so there's nothing to filter by. Once they do, restrict candidates
  /// to verbs belonging to an active deck before ordering.
  Future<List<VerbTableData>> selectNewLexemes(int limit) async {
    if (limit <= 0) return [];
    final startedIds = await lexemeProgressRepository.getStartedEntityIds(entityTypeVerb);
    return verbRepository.getNewCandidatesOrderedByFrequency(startedIds, limit);
  }

  /// How many lexemes were introduced during the current logical day
  /// (day boundary per [boundaryHour], §9.3). Read-only signal for the
  /// soft new-cards-per-day limit; callers decide what to do with it.
  Future<int> countIntroducedToday(int boundaryHour) {
    final boundary = dayBoundary(nowUtcSeconds(), boundaryHour);
    return lexemeProgressRepository.countIntroducedSince(boundary);
  }
}
