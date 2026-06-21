import 'package:almi3/core/enums.dart';
import 'package:almi3/core/icon_assets.dart';
import 'package:almi3/model/dto/example_display_dto.dart';
import 'package:almi3/view/widgets/example_bubble.dart';
import 'package:flutter/material.dart';

class ExampleFormSection extends StatefulWidget {
  final VerbFormExampleGroupDto group;
  final bool focused;

  const ExampleFormSection({super.key, required this.group, required this.focused});

  @override
  State<ExampleFormSection> createState() => _ExampleFormSectionState();
}

class _ExampleFormSectionState extends State<ExampleFormSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scale;
  bool _outlined = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    if (widget.focused) {
      // Wait for route transition (~300ms) + scroll (~400ms) to finish.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _pulseController.forward(from: 0);
        setState(() => _outlined = true);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) setState(() => _outlined = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    // Present/imperative forms store person=none in DB; use second for the icon.
    final isPresentLike = g.tense == Tense.present || g.tense == Tense.imperative;
    final iconPerson = isPresentLike ? GrammaticalPerson.second : g.person;
    final iconPath = grammaticIconAsset(iconPerson, g.plurality, g.gender);

    return ScaleTransition(
      scale: _scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ex in g.examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExampleBubble(
                example: ex,
                formValue: g.formValue,
                iconPath: iconPath,
                outlined: _outlined,
              ),
            ),
        ],
      ),
    );
  }
}
