import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/fsrs/card_state.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart' show lexemeStatusActive;
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// lexeme_progress.status (§4).
const int lexemeStatusIgnored = 2;

/// Everything needed to undo a [LexemeStatusActionsService.markLexemeKnown]
/// call: an exact pre-review card_fsrs snapshot plus the id of the single
/// answer_log row it wrote, so undo can delete that row rather than write a
/// compensating Again (§10, invariant #9).
class MarkKnownResult {
  final int cardId;
  final CardFsrsTableData previousCardRow;
  final int answerLogId;

  const MarkKnownResult({
    required this.cardId,
    required this.previousCardRow,
    required this.answerLogId,
  });
}

final lexemeStatusActionsServiceProvider = Provider(
  (ref) => LexemeStatusActionsService(
    ref: ref,
    lexemeProgressRepository: ref.watch(lexemeProgressRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    answerLogRepository: ref.watch(answerLogRepositoryProvider),
    fsrsParamsRepository: ref.watch(fsrsParamsRepositoryProvider),
  ),
);

/// The three status actions from the introduction screen (§10). "Понятно /
/// учить" needs no code here — it's already what introduceLexeme produces
/// (status stays active, no review).
class LexemeStatusActionsService {
  final Ref ref;
  final LexemeProgressRepository lexemeProgressRepository;
  final LexicalCardRepository lexicalCardRepository;
  final CardFsrsRepository cardFsrsRepository;
  final AnswerLogRepository answerLogRepository;
  final FsrsParamsRepository fsrsParamsRepository;

  LexemeStatusActionsService({
    required this.ref,
    required this.lexemeProgressRepository,
    required this.lexicalCardRepository,
    required this.cardFsrsRepository,
    required this.answerLogRepository,
    required this.fsrsParamsRepository,
  });

  /// "Я знаю" (§10): exactly one Easy review on the lexeme's currently-New
  /// card. MVP has exactly one lexical card per lexeme (recognition only,
  /// §3.3), so invariant #9 ("ровно одним ревью") holds by construction.
  /// TODO(spec §3.3 phase 2): once production cards exist, decide which
  /// card gets the Easy review if more than one is New at once — for now
  /// only the first New card found is reviewed.
  Future<MarkKnownResult?> markLexemeKnown(int lexemeProgressId) async {
    final lexicalCards = await lexicalCardRepository.getByLexeme(lexemeProgressId);

    CardFsrsTableData? newCardRow;
    for (final lexicalCard in lexicalCards) {
      final row = await cardFsrsRepository.getById(lexicalCard.cardId);
      if (row != null && isNew(row.reps, row.lastReview != null ? DateTime.fromMillisecondsSinceEpoch(row.lastReview! * 1000) : null)) {
        newCardRow = row;
        break;
      }
    }
    if (newCardRow == null) return null;

    final previousCardRow = newCardRow;
    final scheduler = await ref.read(schedulerProvider.future);
    final result = scheduler.reviewCard(cardFsrsRowToLibraryCard(previousCardRow), fsrs.Rating.easy);

    final updatedCompanion = libraryCardToCardFsrsCompanion(
      result.card,
      cardType: previousCardRow.cardType,
      id: previousCardRow.id,
      reps: previousCardRow.reps + 1,
      lapses: previousCardRow.lapses,
      createdAt: previousCardRow.createdAt,
    );
    await cardFsrsRepository.updateCard(updatedCompanion);

    // schedulerProvider always builds from the latest fsrs_params row, so
    // re-reading "latest" here is consistent with the scheduler just used.
    final paramsVersion = (await fsrsParamsRepository.getLatest())!.version;

    final answerLogId = await answerLogRepository.insert(
      AnswerLogTableCompanion.insert(
        cardId: previousCardRow.id,
        answeredAt: nowUtcSeconds(),
        source: answerSourceAssertKnown,
        countedInFsrs: true,
        rating: const Value(4), // Easy
        wasCorrect: true,
        quizType: quizTypeNoOp,
        fsrsParamsVersion: paramsVersion,
      ),
    );

    return MarkKnownResult(
      cardId: previousCardRow.id,
      previousCardRow: previousCardRow,
      answerLogId: answerLogId,
    );
  }

  /// Restores card_fsrs to the exact pre-review snapshot and deletes the
  /// one answer_log row — NOT a compensating Again (invariant #9).
  Future<void> undoMarkKnown(MarkKnownResult result) async {
    await cardFsrsRepository.updateCard(cardFsrsRowToFullCompanion(result.previousCardRow));
    await answerLogRepository.deleteById(result.answerLogId);
  }

  /// "Игнорировать" (§10): flag only, never touches FSRS.
  Future<void> ignoreLexeme(int lexemeProgressId) {
    return lexemeProgressRepository.updateStatus(lexemeProgressId, lexemeStatusIgnored, nowUtcSeconds());
  }

  /// Undo for "Игнорировать": trivial, just flips the flag back.
  Future<void> unignoreLexeme(int lexemeProgressId) {
    return lexemeProgressRepository.updateStatus(lexemeProgressId, lexemeStatusActive, nowUtcSeconds());
  }
}
