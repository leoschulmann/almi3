import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/model/fsrs/card_state.dart';
import 'package:almi3/model/fsrs/choose_format.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart' show entityTypeVerb;
import 'package:almi3/model/fsrs/practice_service.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/user/lexical_card_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:almi3/viewmodel/session_notifier.dart' show AnswerReactionData, contentLangProvider, narrowQuizType;
import 'package:almi3/viewmodel/sync_viewmodel.dart' show verbRepositoryProvider;
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One practiceable card in the free-practice pool (story 1.8): the
/// candidate set is every started lexeme's cards (`getStartedProgressIds`,
/// story 1.3), never filtered by `due` (spec Decided / §"Always"). A card
/// still New (chooseFormat -> null, §5.2) has nothing to quiz yet and is
/// left out of the pool entirely -- practice never shows a bare
/// introduction step, only quizzes.
class PracticeItem {
  final CardFsrsTableData cardRow;
  final int lexemeProgressId;
  final int entityId;
  final QuizType renderedQuizType;

  const PracticeItem({
    required this.cardRow,
    required this.lexemeProgressId,
    required this.entityId,
    required this.renderedQuizType,
  });
}

enum PracticePhase { loading, empty, ready, reacting, complete, error }

class PracticeState {
  final PracticePhase phase;
  final List<PracticeItem> queue;
  final int index;
  final AnswerReactionData? reaction;
  final VerbDetailDto? currentVerb;
  final List<String> quizOptions;
  final String? errorMessage;

  const PracticeState({
    required this.phase,
    required this.queue,
    required this.index,
    this.reaction,
    this.currentVerb,
    this.quizOptions = const [],
    this.errorMessage,
  });

  const PracticeState.initial() : this(phase: PracticePhase.loading, queue: const [], index: 0);

  PracticeItem? get currentItem => index >= 0 && index < queue.length ? queue[index] : null;

  PracticeState copyWith({
    PracticePhase? phase,
    List<PracticeItem>? queue,
    int? index,
    AnswerReactionData? reaction,
    bool clearReaction = false,
    VerbDetailDto? currentVerb,
    bool clearCurrentVerb = false,
    List<String>? quizOptions,
    String? errorMessage,
  }) {
    return PracticeState(
      phase: phase ?? this.phase,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      currentVerb: clearCurrentVerb ? null : (currentVerb ?? this.currentVerb),
      quizOptions: quizOptions ?? (clearCurrentVerb ? const [] : this.quizOptions),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final practiceNotifierProvider = NotifierProvider<PracticeNotifier, PracticeState>(PracticeNotifier.new);

/// Free-practice screen state (spec 8-free-practice): candidates are ALL
/// started lexemes' cards (no `due` filter), format via `chooseFormat`
/// (narrowed the same way the unified session does), and every answer goes
/// through `PracticeService.submitPracticeAnswer` -- never
/// `Scheduler.reviewCard`/`ScheduledReviewService` directly. Health is read
/// once before and once after, exactly like the session, so the reaction UI
/// is visually identical whether the gate counted the answer into FSRS or
/// only logged it (spec "Always"/"Never").
class PracticeNotifier extends Notifier<PracticeState> {
  @override
  PracticeState build() {
    Future.microtask(_load);
    return const PracticeState.initial();
  }

  Future<void> _load() async {
    try {
      final queue = await _buildCandidates();

      if (queue.isEmpty) {
        state = state.copyWith(phase: PracticePhase.empty, queue: queue, index: 0);
        return;
      }

      await _enterReadyOrError(queue: queue, index: 0, clearReaction: false);
    } catch (e, st) {
      logger.e('PracticeNotifier._load: failed to build practice pool', error: e, stackTrace: st);
      state = state.copyWith(phase: PracticePhase.error, errorMessage: e.toString());
    }
  }

  /// Candidates = every started lexeme's cards (`getStartedProgressIds`,
  /// entityTypeVerb -- only verbs exist so far), narrowed through the same
  /// `chooseFormat` (frozen) the session uses. A card `chooseFormat` returns
  /// null for (still New, §5.2) is skipped -- practice has no introduction
  /// step, only quizzes.
  Future<List<PracticeItem>> _buildCandidates() async {
    final lexemeProgressRepository = ref.read(lexemeProgressRepositoryProvider);
    final lexicalCardRepository = ref.read(lexicalCardRepositoryProvider);
    final cardFsrsRepository = ref.read(cardFsrsRepositoryProvider);

    final progressIds = await lexemeProgressRepository.getStartedProgressIds(entityTypeVerb);
    final result = <PracticeItem>[];

    for (final progressId in progressIds) {
      final progress = await lexemeProgressRepository.getById(progressId);
      if (progress == null) continue; // orphaned row (shouldn't happen); skip defensively

      final lexicalCards = await lexicalCardRepository.getByLexeme(progressId);
      for (final lexicalCard in lexicalCards) {
        final row = await cardFsrsRepository.getById(lexicalCard.cardId);
        if (row == null) continue;

        final newFlag = isNew(
          row.reps,
          row.lastReview != null ? DateTime.fromMillisecondsSinceEpoch(row.lastReview! * 1000) : null,
        );
        final chosen = chooseFormat(
          isNew: newFlag,
          state: row.state,
          step: row.step,
          direction: lexicalCard.direction,
        );
        if (chosen == null) continue; // still New -- nothing to quiz yet

        result.add(PracticeItem(
          cardRow: row,
          lexemeProgressId: progressId,
          entityId: progress.entityId,
          renderedQuizType: narrowQuizType(chosen),
        ));
      }
    }
    return result;
  }

  /// Loads the content payload for [queue[index]], then commits it to state
  /// in one atomic update -- same atomicity reasoning as
  /// SessionNotifier._enterReadyOrError.
  Future<void> _enterReadyOrError({
    required List<PracticeItem> queue,
    required int index,
    required bool clearReaction,
  }) async {
    final item = queue[index];
    final payload = await _loadVerbPayload(item);

    if (payload.verb == null) {
      state = state.copyWith(
        phase: PracticePhase.error,
        queue: queue,
        index: index,
        clearReaction: clearReaction,
        clearCurrentVerb: true,
        errorMessage: 'Не удалось загрузить карточку',
      );
      return;
    }

    var effectiveQueue = queue;
    if (payload.overrideQuizType != null) {
      effectiveQueue = List<PracticeItem>.of(queue);
      effectiveQueue[index] = PracticeItem(
        cardRow: item.cardRow,
        lexemeProgressId: item.lexemeProgressId,
        entityId: item.entityId,
        renderedQuizType: payload.overrideQuizType!,
      );
    }

    state = state.copyWith(
      phase: PracticePhase.ready,
      queue: effectiveQueue,
      index: index,
      clearReaction: clearReaction,
      currentVerb: payload.verb,
      quizOptions: payload.options,
    );
  }

  Future<({VerbDetailDto? verb, List<String> options, QuizType? overrideQuizType})> _loadVerbPayload(
    PracticeItem item,
  ) async {
    try {
      final verbRepo = ref.read(verbRepositoryProvider);
      final lang = ref.read(contentLangProvider);
      final detail = await verbRepo.getVerbDetail(item.entityId, lang);

      var options = const <String>[];
      QuizType? overrideQuizType;
      if (item.renderedQuizType == QuizType.mc4Recognition && detail != null) {
        options = await _buildMc4Options(verbRepo, item.entityId, detail.translations);

        // Same minimum-distractor guard as the session (§ code map):
        // fall back to typedProduction rather than render a short quiz.
        if (options.length < 4) {
          overrideQuizType = QuizType.typedProduction;
          options = const <String>[];
        }
      }
      return (verb: detail, options: options, overrideQuizType: overrideQuizType);
    } catch (e, st) {
      logger.e('PracticeNotifier._loadVerbPayload: failed to load verb content', error: e, stackTrace: st);
      return (verb: null, options: const <String>[], overrideQuizType: null);
    }
  }

  Future<List<String>> _buildMc4Options(
    VerbRepository verbRepo,
    int excludeId,
    List<String> correctTranslations,
  ) async {
    final correct = correctTranslations.isNotEmpty ? correctTranslations.first : '';
    final candidates = await verbRepo.getNewCandidatesOrderedByFrequency([excludeId], 12);
    candidates.shuffle(Random());

    final lang = ref.read(contentLangProvider);
    final distractors = <String>[];
    for (final candidate in candidates) {
      if (distractors.length >= 3) break;
      final detail = await verbRepo.getVerbDetail(candidate.id, lang);
      final translation = detail != null && detail.translations.isNotEmpty ? detail.translations.first : null;
      if (translation != null &&
          !correctTranslations.contains(translation) &&
          !distractors.contains(translation)) {
        distractors.add(translation);
      }
    }

    final options = [correct, ...distractors];
    options.shuffle(Random());
    return options;
  }

  /// Reentrancy guard, same rationale as SessionNotifier._busy.
  bool _busy = false;

  /// The only path from a user's practice answer to FSRS: builds the
  /// QuizResult, calls PracticeService.submitPracticeAnswer (which itself
  /// runs shouldCountPractice and only then Scheduler.reviewCard, §6.3),
  /// and reads health before/after exactly like a scheduled answer -- the
  /// gated-out and gated-in cases are indistinguishable to this method and
  /// to the reaction it produces (spec "Always": no visual difference).
  Future<void> submitAnswer(QuizResult result) async {
    final item = state.currentItem;
    if (item == null) return;
    if (_busy) return;
    _busy = true;
    try {
      final healthService = ref.read(healthServiceProvider);
      final practiceService = ref.read(practiceServiceProvider);

      final healthBefore = await healthService.lexemeHealth(item.lexemeProgressId);
      await practiceService.submitPracticeAnswer(row: item.cardRow, quizResult: result);
      final healthAfter = await healthService.lexemeHealth(item.lexemeProgressId);

      state = state.copyWith(
        phase: PracticePhase.reacting,
        reaction: AnswerReactionData(
          wasCorrect: result.wasCorrect,
          healthBefore: healthBefore,
          healthAfter: healthAfter,
        ),
      );
    } catch (e, st) {
      logger.e('PracticeNotifier.submitAnswer: failed to submit practice answer', error: e, stackTrace: st);
      state = state.copyWith(phase: PracticePhase.error, errorMessage: e.toString());
    } finally {
      _busy = false;
    }
  }

  /// Dismisses the post-answer reaction and advances the queue.
  Future<void> dismissReaction() async {
    if (state.phase != PracticePhase.reacting) return;
    if (_busy) return;
    _busy = true;
    try {
      await _advance();
    } finally {
      _busy = false;
    }
  }

  Future<void> _advance() async {
    final nextIndex = state.index + 1;
    if (nextIndex >= state.queue.length) {
      state = state.copyWith(phase: PracticePhase.complete, index: nextIndex, clearReaction: true, clearCurrentVerb: true);
      return;
    }
    await _enterReadyOrError(queue: state.queue, index: nextIndex, clearReaction: true);
  }
}
