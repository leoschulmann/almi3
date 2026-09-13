import 'package:almi3/core/clock.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/answer_log_codes.dart';
import 'package:almi3/model/fsrs/grade_answer.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/practice_gate.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/review_persistence.dart';
import 'package:almi3/model/fsrs/scheduler_provider.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final practiceServiceProvider = Provider(
  (ref) => PracticeService(
    ref: ref,
    cardFsrsRepository: ref.watch(cardFsrsRepositoryProvider),
    answerLogRepository: ref.watch(answerLogRepositoryProvider),
    fsrsParamsRepository: ref.watch(fsrsParamsRepositoryProvider),
    healthService: ref.watch(healthServiceProvider),
  ),
);

/// Free practice (§6.3): the user picks cards themselves, without regard to
/// `due`. Whether an answer becomes a real FSRS review is decided by the
/// gate in practice_gate.dart — a gated-out answer is still logged (for
/// analytics and the health bonus, §8.3) but never touches card_fsrs.
class PracticeService {
  final Ref ref;
  final CardFsrsRepository cardFsrsRepository;
  final AnswerLogRepository answerLogRepository;
  final FsrsParamsRepository fsrsParamsRepository;
  final HealthService healthService;

  PracticeService({
    required this.ref,
    required this.cardFsrsRepository,
    required this.answerLogRepository,
    required this.fsrsParamsRepository,
    required this.healthService,
  });

  /// Submits a practice answer for [row]. Returns the card_fsrs row as it
  /// stands afterward — unchanged if the gate rejected this answer.
  Future<CardFsrsTableData> submitPracticeAnswer({
    required CardFsrsTableData row,
    required QuizResult quizResult,
  }) async {
    final counted = await shouldCountPractice(
      row: row,
      quizType: quizResult.quizType,
      healthService: healthService,
    );

    final paramsVersion = (await fsrsParamsRepository.getLatest())!.version;

    if (!counted) {
      await answerLogRepository.insert(
        AnswerLogTableCompanion.insert(
          cardId: row.id,
          answeredAt: nowUtcSeconds(),
          source: answerSourcePractice,
          countedInFsrs: false,
          wasCorrect: quizResult.wasCorrect,
          quizType: quizResult.quizType.value,
          responseTimeMs: Value(quizResult.responseTimeMs),
          fsrsParamsVersion: paramsVersion,
        ),
      );
      return row;
    }

    final rating = gradeAnswer(quizResult);
    final scheduler = await ref.read(schedulerProvider.future);
    final persisted = await reviewAndPersistCard(
      scheduler: scheduler,
      cardFsrsRepository: cardFsrsRepository,
      fsrsParamsRepository: fsrsParamsRepository,
      row: row,
      rating: rating,
    );

    await answerLogRepository.insert(
      AnswerLogTableCompanion.insert(
        cardId: row.id,
        answeredAt: nowUtcSeconds(),
        source: answerSourcePractice,
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
}
