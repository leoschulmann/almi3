import 'package:almi3/core/app_colors.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/viewmodel/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Post-answer response (§11: "верно/неверно + реакция здоровья"). Health
/// values are read once before and once after the answer by the session
/// layer (HealthService.lexemeHealth) -- this widget only presents that
/// diff, never recomputes the formula. Never shows raw FSRS internals
/// (stability/difficulty/retention decimals) -- only the bucketed % bar.
class AnswerReaction extends StatelessWidget {
  final AnswerReactionData reaction;
  final VoidCallback onContinue;

  const AnswerReaction({super.key, required this.reaction, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final before = reaction.healthBefore;
    final after = reaction.healthAfter;
    // Unknown (null) health is a distinct state from "0%" or "unchanged" --
    // shown as the app's existing '—' fallback (matches home_page.dart's
    // progress-showcase error text), never silently coerced to 0.
    final healthUnknown = before == null || after == null;
    final grew = !healthUnknown && after > before;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: reaction.wasCorrect ? AppColors.fieldFill : AppColors.pillBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                reaction.wasCorrect ? l10n.correctAnswer : l10n.incorrectAnswer,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: reaction.wasCorrect ? AppColors.ink : AppColors.pillText,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: healthUnknown ? 0 : (after.clamp(0, 100)) / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.progressTrack,
                  color: AppColors.tekhelet,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                healthUnknown
                    ? l10n.wordHealthUnknown
                    : (grew ? l10n.wordHealthGrew : l10n.wordHealthPercent(after.round())),
                style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          button: true,
          label: l10n.next,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onContinue();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppColors.tekhelet, borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: Text(
                  l10n.next,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
