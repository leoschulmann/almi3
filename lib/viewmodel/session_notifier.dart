import 'dart:math';

import 'package:almi3/core/logger.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/model/fsrs/health.dart';
import 'package:almi3/model/fsrs/lexeme_introduction.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/model/fsrs/scheduled_review_service.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/model/repository/vocab/verb_repository.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show verbRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Language used to render verb content in the session -- matches
/// verb_page_viewmodel.dart's hardcoded choice (no i18n selection wired
/// into content yet).
const String sessionContentLang = 'EN';

/// Narrowing rule (spec §"Decided (MVP format scope)"): the UI ships
/// exactly two quiz widgets this story (mc4Recognition, typedProduction).
/// Any other format chooseFormat returns is narrowed deterministically by
/// ANSWER direction (quizTypeDirection, §5.1) -- recognition -> mc4Recognition,
/// production -> typedProduction. This covers all 7 non-MVP lexical formats:
/// the story's explicit examples (mc2Recognition/listening and
/// mc2Production/niqqud/cloze/preposition) plus mc4Production, which falls
/// under the same "production-direction formats render as typedProduction"
/// framing sentence though not spelled out by name in the example lists.
/// Conjugation formats never reach this function (no conjugation cards
/// exist yet -- out of scope this story per the frozen intent).
QuizType narrowQuizType(QuizType original) {
  if (original == QuizType.mc4Recognition || original == QuizType.typedProduction) {
    return original;
  }
  final direction = quizTypeDirection(original);
  return direction == directionRecognition ? QuizType.mc4Recognition : QuizType.typedProduction;
}

/// One item of the unified session queue (§11): either a not-yet-started
/// lexeme (introduction step, no grading) or a due lexical card (quiz step).
sealed class SessionItem {
  const SessionItem();
}

class SessionNewItem extends SessionItem {
  final int entityType;
  final int entityId;

  const SessionNewItem({required this.entityType, required this.entityId});
}

class SessionDueItem extends SessionItem {
  final DueLexicalCard due;
  final QuizType renderedQuizType;
  final int lexemeProgressId;
  final int entityId;

  const SessionDueItem({
    required this.due,
    required this.renderedQuizType,
    required this.lexemeProgressId,
    required this.entityId,
  });
}

/// Interleaves due and new items "вперемешку" (§11) -- round-robin merge,
/// one due item then one new item each round, preserving each input list's
/// own order. A mixed queue therefore alternates rather than fronting the
/// entire due queue before any new items (or vice versa).
List<SessionItem> interleaveSessionQueue(List<SessionItem> due, List<SessionItem> newItems) {
  final result = <SessionItem>[];
  final maxLen = max(due.length, newItems.length);
  for (var i = 0; i < maxLen; i++) {
    if (i < due.length) result.add(due[i]);
    if (i < newItems.length) result.add(newItems[i]);
  }
  return result;
}

enum SessionPhase { loading, empty, ready, reacting, complete, error }

/// Health read once before and once after a due-card answer (§11, boundaries)
/// -- the diff drives the visible reaction. Never a UI-side recompute.
class AnswerReactionData {
  final bool wasCorrect;
  final double? healthBefore;
  final double? healthAfter;

  const AnswerReactionData({
    required this.wasCorrect,
    required this.healthBefore,
    required this.healthAfter,
  });
}

class SessionState {
  final SessionPhase phase;
  final List<SessionItem> queue;
  final int index;
  final AnswerReactionData? reaction;
  final VerbDetailDto? currentVerb;
  final List<String> quizOptions;
  final String? errorMessage;

  const SessionState({
    required this.phase,
    required this.queue,
    required this.index,
    this.reaction,
    this.currentVerb,
    this.quizOptions = const [],
    this.errorMessage,
  });

  const SessionState.initial() : this(phase: SessionPhase.loading, queue: const [], index: 0);

  SessionItem? get currentItem => index >= 0 && index < queue.length ? queue[index] : null;

  SessionState copyWith({
    SessionPhase? phase,
    List<SessionItem>? queue,
    int? index,
    AnswerReactionData? reaction,
    bool clearReaction = false,
    VerbDetailDto? currentVerb,
    bool clearCurrentVerb = false,
    List<String>? quizOptions,
    String? errorMessage,
  }) {
    return SessionState(
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

final sessionNotifierProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Session queue state (§11): builds the mixed new+due queue on start, drives
/// per-item advance-on-answer/introduce logic. No manual session assembly or
/// format choice is ever exposed above this notifier (§11 boundaries).
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_load);
    return const SessionState.initial();
  }

  Future<void> _load() async {
    try {
      final scheduledReviewService = ref.read(scheduledReviewServiceProvider);
      final lexemeSelectionService = ref.read(lexemeSelectionServiceProvider);
      final settings = ref.read(settingsProvider);
      final lexemeProgressRepository = ref.read(lexemeProgressRepositoryProvider);

      // Session queue = getDueQueuePrioritized() interleaved with
      // selectNewLexemes(remaining), remaining computed exactly as
      // homeStatusProvider does (§"Always").
      final dueCards = await scheduledReviewService.getDueQueuePrioritized();

      final introducedToday = await lexemeSelectionService.countIntroducedToday(settings.dayBoundaryHour);
      final remaining = max(0, settings.newCardsPerDay - introducedToday);
      final newVerbs = await lexemeSelectionService.selectNewLexemes(remaining);

      final dueItems = <SessionItem>[];
      for (final due in dueCards) {
        final progress = await lexemeProgressRepository.getById(due.lexicalCardRow.lexemeProgressId);
        if (progress == null) continue; // orphaned row (shouldn't happen); skip defensively

        // chooseFormat (frozen) is called as-is, then narrowed in this
        // session layer -- never inside choose_format.dart.
        final chosen = scheduledReviewService.prepareQuiz(due) ??
            (due.lexicalCardRow.direction == directionRecognition
                ? QuizType.mc4Recognition
                : QuizType.typedProduction);

        dueItems.add(SessionDueItem(
          due: due,
          renderedQuizType: narrowQuizType(chosen),
          lexemeProgressId: progress.id,
          entityId: progress.entityId,
        ));
      }

      final newItems = newVerbs.map((v) => SessionNewItem(entityType: entityTypeVerb, entityId: v.id)).toList();

      final queue = interleaveSessionQueue(dueItems, newItems);

      if (queue.isEmpty) {
        state = state.copyWith(phase: SessionPhase.empty, queue: queue, index: 0);
        return;
      }

      // Load the first item's content BEFORE flipping to `ready`, so the
      // state transition to `ready` and its verb payload land in one
      // atomic update -- a widget (or test) that reacts to leaving
      // `loading` never observes a `ready` frame with stale/empty content,
      // and no further async work touches `state` after this method
      // returns (matters once the notifier/container is torn down).
      await _enterReadyOrError(queue: queue, index: 0, clearReaction: false);
    } catch (e, st) {
      logger.e('SessionNotifier._load: failed to build session queue', error: e, stackTrace: st);
      state = state.copyWith(phase: SessionPhase.error, errorMessage: e.toString());
    }
  }

  /// Loads the content payload for [queue[index]], then commits it to
  /// state in one atomic update: `error` if the verb couldn't be loaded (no
  /// indefinite spinner left dangling), otherwise `ready` -- with the item
  /// itself swapped for an mc4Recognition->typedProduction fallback copy
  /// when [_loadVerbPayload] couldn't find enough distractors.
  Future<void> _enterReadyOrError({
    required List<SessionItem> queue,
    required int index,
    required bool clearReaction,
  }) async {
    final item = queue[index];
    final payload = await _loadVerbPayload(item);

    if (payload.verb == null) {
      state = state.copyWith(
        phase: SessionPhase.error,
        queue: queue,
        index: index,
        clearReaction: clearReaction,
        clearCurrentVerb: true,
        errorMessage: 'Не удалось загрузить карточку',
      );
      return;
    }

    var effectiveQueue = queue;
    if (payload.overrideQuizType != null && item is SessionDueItem) {
      effectiveQueue = List<SessionItem>.of(queue);
      effectiveQueue[index] = SessionDueItem(
        due: item.due,
        renderedQuizType: payload.overrideQuizType!,
        lexemeProgressId: item.lexemeProgressId,
        entityId: item.entityId,
      );
    }

    state = state.copyWith(
      phase: SessionPhase.ready,
      queue: effectiveQueue,
      index: index,
      clearReaction: clearReaction,
      currentVerb: payload.verb,
      quizOptions: payload.options,
    );
  }

  Future<({VerbDetailDto? verb, List<String> options, QuizType? overrideQuizType})> _loadVerbPayload(
    SessionItem item,
  ) async {
    try {
      final verbRepo = ref.read(verbRepositoryProvider);
      final entityId = switch (item) {
        SessionNewItem(:final entityId) => entityId,
        SessionDueItem(:final entityId) => entityId,
      };
      final detail = await verbRepo.getVerbDetail(entityId, sessionContentLang);

      var options = const <String>[];
      QuizType? overrideQuizType;
      if (item is SessionDueItem && item.renderedQuizType == QuizType.mc4Recognition && detail != null) {
        options = await _buildMc4Options(verbRepo, entityId, detail.translations);

        // Minimum-distractor guard: mc4Recognition needs 4 real options
        // (correct + >=3 unique distractors). If the content pool can't
        // supply enough, don't silently render a quiz with fewer choices
        // -- fall back to typedProduction for this item instead.
        if (options.length < 4) {
          overrideQuizType = QuizType.typedProduction;
          options = const <String>[];
        }
      }
      return (verb: detail, options: options, overrideQuizType: overrideQuizType);
    } catch (e, st) {
      logger.e('SessionNotifier._loadVerbPayload: failed to load verb content', error: e, stackTrace: st);
      return (verb: null, options: const <String>[], overrideQuizType: null);
    }
  }

  /// Builds mc4Recognition's 4 options: the correct translation plus up to 3
  /// distractor translations drawn from other verbs (reuses the existing
  /// "not this id" content query -- no new distractor infra this story).
  /// May return fewer than 4 options if the content pool can't supply
  /// enough unique distractors -- callers (see [_loadVerbPayload]) must
  /// guard against that rather than rendering a short quiz.
  Future<List<String>> _buildMc4Options(
    VerbRepository verbRepo,
    int excludeId,
    List<String> correctTranslations,
  ) async {
    final correct = correctTranslations.isNotEmpty ? correctTranslations.first : '';
    final candidates = await verbRepo.getNewCandidatesOrderedByFrequency([excludeId], 12);
    candidates.shuffle(Random());

    final distractors = <String>[];
    for (final candidate in candidates) {
      if (distractors.length >= 3) break;
      final detail = await verbRepo.getVerbDetail(candidate.id, sessionContentLang);
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

  /// Reentrancy guard: one in-flight introduce/submit/dismiss at a time.
  /// Without it, a double-tap before the in-flight `await` resolves could
  /// double-submit the same answer or introduction (e.g. two answer_log
  /// rows / two reviewCard calls for one tap).
  bool _busy = false;

  /// New-item path (§11, boundaries): "Понятно" creates the DB rows via
  /// LexemeIntroductionService; this notifier never calls reviewCard/grades
  /// anything for an introduction step.
  Future<void> completeIntroduction() async {
    final item = state.currentItem;
    if (item is! SessionNewItem) return;
    if (_busy) return;
    _busy = true;
    try {
      final introductionService = ref.read(lexemeIntroductionServiceProvider);
      await introductionService.introduceLexeme(item.entityType, item.entityId);
      await _advance();
    } catch (e, st) {
      logger.e('SessionNotifier.completeIntroduction: failed to introduce lexeme', error: e, stackTrace: st);
      state = state.copyWith(phase: SessionPhase.error, errorMessage: e.toString());
    } finally {
      _busy = false;
    }
  }

  /// Due-item path (§11, boundaries): builds a QuizResult from the user's
  /// actual input and the rendered (narrowed) quizType, then calls
  /// ScheduledReviewService.submitAnswer -- the sole path to
  /// Scheduler.reviewCard, never touched directly. Health is read once
  /// before and once after; the diff drives the reaction shown next.
  Future<void> submitDueAnswer(QuizResult result) async {
    final item = state.currentItem;
    if (item is! SessionDueItem) return;
    if (_busy) return;
    _busy = true;
    try {
      final healthService = ref.read(healthServiceProvider);
      final reviewService = ref.read(scheduledReviewServiceProvider);

      final healthBefore = await healthService.lexemeHealth(item.lexemeProgressId);
      await reviewService.submitAnswer(due: item.due, quizResult: result);
      final healthAfter = await healthService.lexemeHealth(item.lexemeProgressId);

      state = state.copyWith(
        phase: SessionPhase.reacting,
        reaction: AnswerReactionData(
          wasCorrect: result.wasCorrect,
          healthBefore: healthBefore,
          healthAfter: healthAfter,
        ),
      );
    } catch (e, st) {
      logger.e('SessionNotifier.submitDueAnswer: failed to submit answer', error: e, stackTrace: st);
      state = state.copyWith(phase: SessionPhase.error, errorMessage: e.toString());
    } finally {
      _busy = false;
    }
  }

  /// Dismisses the post-answer reaction and advances the queue.
  Future<void> dismissReaction() async {
    if (state.phase != SessionPhase.reacting) return;
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
      state = state.copyWith(
        phase: SessionPhase.complete,
        index: nextIndex,
        clearReaction: true,
        clearCurrentVerb: true,
      );
      return;
    }

    // Same atomicity reasoning as _load: compute the next item's content
    // first, then flip phase/index/content together in one update.
    await _enterReadyOrError(queue: state.queue, index: nextIndex, clearReaction: true);
  }
}
