import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/fsrs/card_state.dart';
import 'package:almi3/model/fsrs/choose_format.dart';
import 'package:almi3/model/fsrs/grade_answer.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/conjugation_card_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// A due card_fsrs row joined with its lexical_card row.
class DueLexicalCard {
  final CardFsrsTableData cardFsrsRow;
  final LexicalCardTableData lexicalCardRow;

  const DueLexicalCard({required this.cardFsrsRow, required this.lexicalCardRow});
}

/// A due card_fsrs row joined with its conjugation_card row (§7).
class DueConjugationCard {
  final CardFsrsTableData cardFsrsRow;
  final ConjugationCardTableData conjugationCardRow;

  const DueConjugationCard({required this.cardFsrsRow, required this.conjugationCardRow});
}

final scheduledReviewServiceProvider = Provider(
  (ref) => ScheduledReviewService(
    ref: ref,
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
    conjugationCardRepository: ref.watch(conjugationCardRepositoryProvider),
    answerLogRepository: ref.watch(answerLogRepositoryProvider),
    fsrsParamsRepository: ref.watch(fsrsParamsRepositoryProvider),
  ),
);

/// Orchestrates one scheduled-review cycle (§6.2): due queue -> format
/// selection -> grading -> the single legal Scheduler.reviewCard call ->
/// persistence. No UI here.
class ScheduledReviewService {
  final Ref ref;
  final CardFsrsRepository cardFsrsRepository;
  final LexicalCardRepository lexicalCardRepository;
  final ConjugationCardRepository conjugationCardRepository;
  final AnswerLogRepository answerLogRepository;
  final FsrsParamsRepository fsrsParamsRepository;

  ScheduledReviewService({
    required this.ref,
    required this.cardFsrsRepository,
    required this.lexicalCardRepository,
    required this.conjugationCardRepository,
    required this.answerLogRepository,
    required this.fsrsParamsRepository,
  });

  /// Due card_fsrs rows (state != none by construction — the library has no
  /// New state, §14) joined with their lexical_card row, ordered by due asc.
  /// Rows without a lexical_card (i.e. conjugation_card) are skipped.
  Future<List<DueLexicalCard>> getDueQueue({int? limit}) async {
    final dueRows = await cardFsrsRepository.getByDueBefore(nowUtcSeconds(), limit: limit);
    final result = <DueLexicalCard>[];
    for (final row in dueRows) {
      final lexicalCard = await lexicalCardRepository.getByCardId(row.id);
      if (lexicalCard != null) {
        result.add(DueLexicalCard(cardFsrsRow: row, lexicalCardRow: lexicalCard));
      }
    }
    return result;
  }

  /// Same as [getDueQueue] but for conjugation_card cards (§7).
  Future<List<DueConjugationCard>> getDueConjugationQueue({int? limit}) async {
    final dueRows = await cardFsrsRepository.getByDueBefore(nowUtcSeconds(), limit: limit);
    final result = <DueConjugationCard>[];
    for (final row in dueRows) {
      final conjugationCard = await conjugationCardRepository.getByCardId(row.id);
      if (conjugationCard != null) {
        result.add(DueConjugationCard(cardFsrsRow: row, conjugationCardRow: conjugationCard));
      }
    }
    return result;
  }

  bool _isNewRow(CardFsrsTableData row) =>
      isNew(row.reps, row.lastReview != null ? DateTime.fromMillisecondsSinceEpoch(row.lastReview! * 1000) : null);

  /// Picks a quiz format for a due lexical card (§5.2).
  QuizType? prepareQuiz(DueLexicalCard due) {
    final row = due.cardFsrsRow;
    return chooseFormat(
      isNew: _isNewRow(row),
      state: row.state,
      step: row.step,
      direction: due.lexicalCardRow.direction,
    );
  }

  /// Picks a quiz format for a due conjugation card (§5.2/§7).
  QuizType? prepareConjugationQuiz(DueConjugationCard due) {
    final row = due.cardFsrsRow;
    return chooseConjugationFormat(isNew: _isNewRow(row), state: row.state);
  }

  /// Runs the single legal Scheduler.reviewCard call and persists the
  /// updated card_fsrs row. Shared by both the lexical and conjugation
  /// paths — only the answer_log row differs (conjugation logs shownVerbId).
  Future<({CardFsrsTableCompanion companion, int paramsVersion})> _reviewAndPersist(
    CardFsrsTableData row,
    int rating,
  ) async {
    final scheduler = await ref.read(schedulerProvider.future);
    final paramsVersion = (await fsrsParamsRepository.getLatest())!.version;

    final beforeCard = cardFsrsRowToLibraryCard(row);
    final result = scheduler.reviewCard(beforeCard, fsrs.Rating.fromValue(rating));
    final afterCard = result.card;

    final wasReview = row.state == fsrs.State.review.value;
    final isLapse = wasReview && rating == ratingAgain;

    final updatedCompanion = libraryCardToCardFsrsCompanion(
      afterCard,
      cardType: row.cardType,
      id: row.id,
      reps: row.reps + 1,
      lapses: isLapse ? row.lapses + 1 : row.lapses,
      createdAt: row.createdAt,
    );
    await cardFsrsRepository.updateCard(updatedCompanion);

    return (companion: updatedCompanion, paramsVersion: paramsVersion);
  }

  /// Grades the answer, runs the single legal Scheduler.reviewCard call,
  /// and persists both the updated card_fsrs row and the answer_log entry.
  Future<CardFsrsTableData> submitAnswer({
    required DueLexicalCard due,
    required QuizResult quizResult,
  }) async {
    final row = due.cardFsrsRow;
    final rating = gradeAnswer(quizResult);
    final persisted = await _reviewAndPersist(row, rating);

    await answerLogRepository.insert(
      AnswerLogTableCompanion.insert(
        cardId: row.id,
        answeredAt: nowUtcSeconds(),
        source: answerSourceScheduled,
        countedInFsrs: true,
        rating: Value(rating),
        wasCorrect: quizResult.wasCorrect,
        quizType: quizResult.quizType.value,
        responseTimeMs: Value(quizResult.responseTimeMs),
        fsrsParamsVersion: persisted.paramsVersion,
      ),
    );

    return (await cardFsrsRepository.getById(row.id))!;
  }

  /// Same as [submitAnswer] but for a conjugation card (§7.5): [shownVerbId]
  /// is the verb substituted into the quiz (from [ConjugationPoolService]),
  /// logged into answer_log.shown_verb_id for later "which gizrah is weak"
  /// analysis.
  Future<CardFsrsTableData> submitConjugationAnswer({
    required DueConjugationCard due,
    required QuizResult quizResult,
    required int shownVerbId,
  }) async {
    final row = due.cardFsrsRow;
    final rating = gradeAnswer(quizResult);
    final persisted = await _reviewAndPersist(row, rating);

    await answerLogRepository.insert(
      AnswerLogTableCompanion.insert(
        cardId: row.id,
        answeredAt: nowUtcSeconds(),
        source: answerSourceScheduled,
        countedInFsrs: true,
        rating: Value(rating),
        wasCorrect: quizResult.wasCorrect,
        quizType: quizResult.quizType.value,
        responseTimeMs: Value(quizResult.responseTimeMs),
        shownVerbId: Value(shownVerbId),
        fsrsParamsVersion: persisted.paramsVersion,
      ),
    );

    return (await cardFsrsRepository.getById(row.id))!;
  }
}
