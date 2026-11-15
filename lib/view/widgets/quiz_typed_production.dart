import 'package:almi3/core/app_colors.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/model/fsrs/quiz_result.dart';
import 'package:almi3/model/fsrs/quiz_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// typedProduction quiz (§5.1): translation shown, user types the Hebrew
/// word. Produces a raw [QuizResult] on submit -- grading (gradeAnswer)
/// happens under the hood in the session layer, never here. No
/// Again/Hard/Good/Easy control anywhere in this widget.
class QuizTypedProduction extends StatefulWidget {
  final VerbDetailDto verb;
  final ValueChanged<QuizResult> onSubmit;

  const QuizTypedProduction({super.key, required this.verb, required this.onSubmit});

  @override
  State<QuizTypedProduction> createState() => _QuizTypedProductionState();
}

class _QuizTypedProductionState extends State<QuizTypedProduction> {
  final _controller = TextEditingController();
  late final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A near-miss (single-character edit away) is graded as "correct but
  /// typo" (§5.3: typed_production -> Hard), not wrong. Simple positional
  /// diff-count, adequate for MVP -- not a full edit-distance algorithm.
  bool _isCloseTypo(String input, String correct) {
    if (input.isEmpty) return false;
    if ((input.length - correct.length).abs() > 1) return false;
    final len = input.length < correct.length ? input.length : correct.length;
    var diff = (input.length - correct.length).abs();
    for (var i = 0; i < len; i++) {
      if (input[i] != correct[i]) diff++;
    }
    return diff <= 1;
  }

  void _submit() {
    final input = _controller.text.trim();
    final correct = widget.verb.value.trim();
    final exact = input == correct;
    final hadTypo = !exact && _isCloseTypo(input, correct);

    HapticFeedback.mediumImpact();
    widget.onSubmit(QuizResult(
      quizType: QuizType.typedProduction,
      wasCorrect: exact || hadTypo,
      responseTimeMs: _stopwatch.elapsedMilliseconds,
      hadTypo: hadTypo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final translation = widget.verb.translations.isNotEmpty ? widget.verb.translations.first : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Center(
            child: Text(
              translation,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.fieldFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: l10n.submitAnswer,
          child: GestureDetector(
            onTap: _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppColors.tekhelet, borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: Text(
                  l10n.submitAnswer,
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
