import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/hebrew_sentence_util.dart';
import 'package:almi3/model/dto/example_display_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class ExampleBubble extends StatelessWidget {
  final ExampleDisplayDto example;
  final String formValue;
  final String iconPath;
  final bool outlined;

  const ExampleBubble({
    super.key,
    required this.example,
    required this.formValue,
    required this.iconPath,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 40, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppColors.bubbleBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: outlined ? AppColors.verbMain : Colors.transparent,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.volume_up_outlined,
                  size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _HighlightedSentence(
                      sentence: example.sentence, formValue: formValue),
                  const SizedBox(height: 4),
                  Text(
                    example.translation,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.rubik(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SvgPicture.asset(iconPath, width: 24, height: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedSentence extends StatelessWidget {
  final String sentence;
  final String formValue;

  const _HighlightedSentence(
      {required this.sentence, required this.formValue});

  @override
  Widget build(BuildContext context) {
    final tokens = sentence.split(' ');
    final matchIdx = findFormTokenIndex(sentence, formValue);

    final normalStyle = GoogleFonts.rubik(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    );
    final highlightStyle = normalStyle.copyWith(color: AppColors.verbMain);

    final spans = <TextSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(
        text: tokens[i],
        style: i == matchIdx ? highlightStyle : normalStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    );
  }
}
