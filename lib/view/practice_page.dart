import 'package:almi3/core/app_colors.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:almi3/view/widgets/answer_reaction.dart';
import 'package:almi3/view/widgets/quiz_mc4_recognition.dart';
import 'package:almi3/view/widgets/quiz_typed_production.dart';
import 'package:almi3/viewmodel/practice_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Free-practice screen (spec 8-free-practice, CAP-7): a plain, unbounded
/// pool of the user's already-started words, driven card-by-card by
/// [practiceNotifierProvider]. Reuses the session's quiz widgets and
/// [AnswerReaction] as-is -- the reaction looks identical whether or not
/// the gate (practice_gate.dart, untouched) actually counted the answer
/// into FSRS. No format picker, no deck picker, no Again/Hard/Good/Easy
/// control ever renders here.
class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceNotifierProvider);

    ref.listen<PracticeState>(practiceNotifierProvider, (previous, next) {
      // Pool exhaustion: pop back, same pattern as SessionPage.
      if (next.phase == PracticePhase.complete && !_popped) {
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
        title: Text(AppLocalizations.of(context)!.practiceTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PracticeState state) {
    switch (state.phase) {
      case PracticePhase.loading:
        return const Center(child: CircularProgressIndicator());

      case PracticePhase.complete:
        // Transitional frame only -- the listener above pops on the same tick.
        return const SizedBox.shrink();

      case PracticePhase.empty:
        return _EmptyState(onExit: () => Navigator.of(context).pop());

      case PracticePhase.error:
        return _ErrorState(onExit: () => Navigator.of(context).pop());

      case PracticePhase.reacting:
        final reaction = state.reaction;
        if (reaction == null) return const SizedBox.shrink();
        return AnswerReaction(
          reaction: reaction,
          onContinue: () => ref.read(practiceNotifierProvider.notifier).dismissReaction(),
        );

      case PracticePhase.ready:
        final item = state.currentItem;
        final verb = state.currentVerb;
        if (item == null || verb == null) return const Center(child: CircularProgressIndicator());

        if (item.renderedQuizType == QuizType.mc4Recognition) {
          return QuizMc4Recognition(
            verb: verb,
            options: state.quizOptions,
            onSubmit: (result) => ref.read(practiceNotifierProvider.notifier).submitAnswer(result),
          );
        }
        return QuizTypedProduction(
          verb: verb,
          onSubmit: (result) => ref.read(practiceNotifierProvider.notifier).submitAnswer(result),
        );
    }
  }
}

/// Empty pool (no started words yet) -- same style as SessionPage's
/// `_EmptyState`.
class _EmptyState extends StatelessWidget {
  final VoidCallback onExit;
  const _EmptyState({required this.onExit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.emptyPracticePool,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: onExit, child: Text(l10n.back)),
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.genericErrorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: onExit, child: Text(l10n.back)),
        ],
      ),
    );
  }
}
