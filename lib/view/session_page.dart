import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/view/practice_stub_page.dart';
import 'package:almi3/view/widgets/answer_reaction.dart';
import 'package:almi3/view/widgets/introduction_card.dart';
import 'package:almi3/view/widgets/quiz_mc4_recognition.dart';
import 'package:almi3/view/widgets/quiz_typed_production.dart';
import 'package:almi3/viewmodel/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The unified session screen (§11): a single mixed queue of new-lexeme
/// introductions and due-card quizzes, driven card-by-card by
/// [sessionNotifierProvider]. Replaces SessionStubPage. No manual session
/// assembly or format picker is ever exposed here, and no
/// Again/Hard/Good/Easy control ever renders.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key});

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionNotifierProvider);

    ref.listen<SessionState>(sessionNotifierProvider, (previous, next) {
      // Queue exhaustion (§11, boundaries): pop back to HomePage, whose
      // existing invalidation-on-return already refreshes due/new counts
      // and the progress showcase -- no new wiring needed there.
      if (next.phase == SessionPhase.complete && !_popped) {
        _popped = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        title: const Text('Сессия'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SessionState state) {
    switch (state.phase) {
      case SessionPhase.loading:
        return const Center(child: CircularProgressIndicator());

      case SessionPhase.complete:
        // Transitional frame only -- the listener above pops back to
        // HomePage on the same tick. No indeterminate spinner here (it
        // would keep scheduling animation frames past the pop).
        return const SizedBox.shrink();

      case SessionPhase.empty:
        return _EmptyState(onExit: () => Navigator.of(context).pop());

      case SessionPhase.newLimitFork:
        return _NewLimitForkState(
          onContinueWithNew: () => ref.read(sessionNotifierProvider.notifier).continueWithMoreNew(),
          onPractice: () {
            Navigator.of(context).push(adaptivePageRoute(builder: (_) => const PracticeStubPage()));
          },
        );

      case SessionPhase.backlogWelcome:
        return _BacklogWelcomeState(
          onStart: () => ref.read(sessionNotifierProvider.notifier).dismissBacklogWelcome(),
        );

      case SessionPhase.error:
        return _ErrorState(onExit: () => Navigator.of(context).pop());

      case SessionPhase.reacting:
        final reaction = state.reaction;
        if (reaction == null) return const SizedBox.shrink();
        return AnswerReaction(
          reaction: reaction,
          onContinue: () => ref.read(sessionNotifierProvider.notifier).dismissReaction(),
        );

      case SessionPhase.ready:
        final item = state.currentItem;
        if (item == null) return const SizedBox.shrink();

        if (item is SessionNewItem) {
          return IntroductionCard(
            verb: state.currentVerb,
            onContinue: () => ref.read(sessionNotifierProvider.notifier).completeIntroduction(),
          );
        }

        final dueItem = item as SessionDueItem;
        final verb = state.currentVerb;
        if (verb == null) return const Center(child: CircularProgressIndicator());

        if (dueItem.renderedQuizType == QuizType.mc4Recognition) {
          return QuizMc4Recognition(
            verb: verb,
            options: state.quizOptions,
            onSubmit: (result) => ref.read(sessionNotifierProvider.notifier).submitDueAnswer(result),
          );
        }
        return QuizTypedProduction(
          verb: verb,
          onSubmit: (result) => ref.read(sessionNotifierProvider.notifier).submitDueAnswer(result),
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onExit;
  const _EmptyState({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Нечего повторять — всё выучено на сегодня',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: onExit, child: const Text('Назад')),
        ],
      ),
    );
  }
}

/// The soft-limit fork (§9.3): shown at natural queue exhaustion when the
/// daily new-cards norm was actually the limiting factor and more
/// candidates exist beyond it. Copy is the spec's exact wording, verbatim.
class _NewLimitForkState extends StatelessWidget {
  final VoidCallback onContinueWithNew;
  final VoidCallback onPractice;

  const _NewLimitForkState({required this.onContinueWithNew, required this.onPractice});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            newLimitForkCopy,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onContinueWithNew, child: const Text('Продолжить с новыми')),
          const SizedBox(height: 12),
          TextButton(onPressed: onPractice, child: const Text('Потренировать')),
        ],
      ),
    );
  }
}

/// The one-time debt-backlog welcome screen (story 7, §"Always"): shown
/// before the first card when the due queue is a "naves". No raw numbers
/// (due-count, backlog size, batch size) ever appear in this copy.
class _BacklogWelcomeState extends StatelessWidget {
  final VoidCallback onStart;
  const _BacklogWelcomeState({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            backlogWelcomeCopy,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onStart, child: const Text('Начать')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onExit;
  const _ErrorState({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Что-то пошло не так. Попробуйте ещё раз позже.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: onExit, child: const Text('Назад')),
        ],
      ),
    );
  }
}
