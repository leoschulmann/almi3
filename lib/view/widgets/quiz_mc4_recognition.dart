import 'package:almi3/core/app_colors.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// mc4Recognition quiz (§5.1): Hebrew word shown, user picks the correct
/// translation from 4 options. Produces a raw [QuizResult] on tap -- grading
/// (gradeAnswer) happens under the hood in the session layer, never here.
/// No Again/Hard/Good/Easy control anywhere in this widget.
class QuizMc4Recognition extends StatefulWidget {
  final VerbDetailDto verb;
  final List<String> options;
  final ValueChanged<QuizResult> onSubmit;

  const QuizMc4Recognition({
    super.key,
    required this.verb,
    required this.options,
    required this.onSubmit,
  });

  @override
  State<QuizMc4Recognition> createState() => _QuizMc4RecognitionState();
}

class _QuizMc4RecognitionState extends State<QuizMc4Recognition> {
  late final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  Widget build(BuildContext context) {
    // A verb can have multiple valid translations (§ VerbDetailDto.translations);
    // only one of them is the option rendered as "the" correct choice, but
    // correctness is checked against the FULL list so a distractor that
    // happens to collide with a non-first valid translation is never
    // possible (see the matching guard in SessionNotifier._buildMc4Options).
    final correctTranslations = widget.verb.translations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Center(
            child: Text(
              widget.verb.value,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (final option in widget.options) ...[
          _OptionButton(
            label: option,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onSubmit(QuizResult(
                quizType: QuizType.mc4Recognition,
                wasCorrect: correctTranslations.contains(option),
                responseTimeMs: _stopwatch.elapsedMilliseconds,
              ));
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OptionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(14)),
          child: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
        ),
      ),
    );
  }
}
