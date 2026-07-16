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
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// A due card_fsrs row joined with its lexical_card row. Only the lexical
/// subtype is handled here — conjugation_card cards (§7) are a later step.
class DueLexicalCard {
  final CardFsrsTableData cardFsrsRow;
  final LexicalCardTableData lexicalCardRow;

  const DueLexicalCard({required this.cardFsrsRow, required this.lexicalCardRow});
}

final scheduledReviewServiceProvider = Provider(
  (ref) => ScheduledReviewService(
    ref: ref,
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    lexicalCardRepository: ref.watch(lexicalCardRepositoryProvider),
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
  final AnswerLogRepository answerLogRepository;
  final FsrsParamsRepository fsrsParamsRepository;

  ScheduledReviewService({
    required this.ref,
    required this.cardFsrsRepository,
    required this.lexicalCardRepository,
    required this.answerLogRepository,
    required this.fsrsParamsRepository,
  });

  /// Due card_fsrs rows (state != none by construction — the library has no
  /// New state, §14) joined with their lexical_card row, ordered by due asc.
  /// Rows without a lexical_card (i.e. conjugation_card) are skipped for now.
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

  /// Picks a quiz format for a due card (§5.2).
  QuizType? prepareQuiz(DueLexicalCard due) {
    final row = due.cardFsrsRow;
    return chooseFormat(
      isNew: isNew(row.reps, row.lastReview != null ? DateTime.fromMillisecondsSinceEpoch(row.lastReview! * 1000) : null),
      state: row.state,
      step: row.step,
      direction: due.lexicalCardRow.direction,
    );
  }

  /// Grades the answer, runs the single legal Scheduler.reviewCard call,
  /// and persists both the updated card_fsrs row and the answer_log entry.
  Future<CardFsrsTableData> submitAnswer({
    required DueLexicalCard due,
    required QuizResult quizResult,
  }) async {
    final row = due.cardFsrsRow;
    final rating = gradeAnswer(quizResult);

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
        fsrsParamsVersion: paramsVersion,
      ),
    );

    return (await cardFsrsRepository.getById(row.id))!;
  }
}
