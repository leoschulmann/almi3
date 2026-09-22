import 'package:almi3/core/app_colors.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/view/widgets/fallback_warning_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Knowledge-introduction presentation for a new lexeme (§11, boundaries):
/// word/translation/root/binyan, "Понятно" advances -- no grading happens
/// here, ever.
class IntroductionCard extends StatefulWidget {
  final VerbDetailDto? verb;
  final VoidCallback onContinue;
  final VoidCallback onKnown;
  final VoidCallback onIgnore;

  const IntroductionCard({
    super.key,
    required this.verb,
    required this.onContinue,
    required this.onKnown,
    required this.onIgnore,
  });

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
    final l10n = AppLocalizations.of(context)!;
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (verb.translations.isNotEmpty && verb.translationsIsFallback) ...[
                          const FallbackWarningMarker(),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            verb.translations.isNotEmpty ? verb.translations.join(', ') : '',
                            style: const TextStyle(fontSize: 18, color: AppColors.inkSecondary),
                          ),
                        ),
                      ],
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
          label: l10n.gotIt,
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
                child: Center(
                  child: Text(
                    l10n.gotIt,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SecondaryAction(label: l10n.iKnowIt, onTap: widget.onKnown)),
            const SizedBox(width: 12),
            Expanded(child: _SecondaryAction(label: l10n.ignoreAction, onTap: widget.onIgnore)),
          ],
        ),
      ],
    );
  }
}

/// "Я знаю"/"Игнорировать" -- secondary status actions on the introduction
/// screen (§10). Plain tap (not long-press), haptic only, no scale-pulse:
/// these are one-shot decisions on a screen the user leaves immediately
/// after, not a toggle worth the extra flourish.
class _SecondaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
