import 'package:almi3/core/app_colors.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Knowledge-introduction presentation for a new lexeme (§11, boundaries):
/// word/translation/root/binyan, "Понятно" advances -- no grading happens
/// here, ever.
class IntroductionCard extends StatefulWidget {
  final VerbDetailDto? verb;
  final VoidCallback onContinue;

  const IntroductionCard({super.key, required this.verb, required this.onContinue});

  @override
  State<IntroductionCard> createState() => _IntroductionCardState();
}

class _IntroductionCardState extends State<IntroductionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verb = widget.verb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: verb == null
              ? const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()))
              : Column(
                  children: [
                    Text(
                      verb.value,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      verb.translations.isNotEmpty ? verb.translations.join(', ') : '',
                      style: const TextStyle(fontSize: 18, color: AppColors.inkSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${verb.binyan} · ${verb.root}',
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        Semantics(
          button: true,
          label: 'Понятно',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _pulseController.forward(from: 0);
              widget.onContinue();
            },
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: AppColors.tekhelet, borderRadius: BorderRadius.circular(16)),
                child: const Center(
                  child: Text(
                    'Понятно',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
