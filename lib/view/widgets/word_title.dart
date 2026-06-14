import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Hebrew always steals this fraction of translation's natural share.
// 0.0 = pure natural ratio, 1.0 = Hebrew gets everything.
const _hebrewBias = 0.25;

// Font size used only for measuring the natural width ratio — not for rendering.
const _measureFontSize = 48.0;

class WordTitle extends StatelessWidget {
  final List<String> translations;
  final String hebrewValue;
  final WordType wordType;

  const WordTitle({super.key, required this.translations, required this.hebrewValue, required this.wordType});

  @override
  Widget build(BuildContext context) {
    final hasTranslation = translations.isNotEmpty;
    final primaryTranslation = hasTranslation ? translations.first : '🔤 missing translation';
    final extraTranslations = hasTranslation ? translations.skip(1).toList() : <String>[];

    final baseStyle = GoogleFonts.rubik(fontSize: _measureFontSize);

    final hebrewPainter = TextPainter(
      text: TextSpan(text: hebrewValue, style: baseStyle),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);

    final translationPainter = TextPainter(
      text: TextSpan(text: primaryTranslation, style: baseStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);

    final totalNatural = hebrewPainter.width + translationPainter.width;
    final rHebrew = totalNatural == 0 ? 0.5 : hebrewPainter.width / totalNatural;

    // f(r) = r + bias × (1 - r)
    final adjustedHebrew = rHebrew + _hebrewBias * (1 - rHebrew);
    final adjustedTranslation = 1.0 - adjustedHebrew;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = w * 0.05;
        final budget = w - gap;

        final hebrewWidth = budget * adjustedHebrew;
        final translationWidth = budget * adjustedTranslation;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: translationWidth,
              // decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 1)),
              child: AutoSizeText(
                primaryTranslation,
                maxLines: 1,
                minFontSize: 18,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: hasTranslation ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              width: gap,
              // decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 1)),
            ),
            Container(
              width: hebrewWidth,
              // decoration: BoxDecoration(border: Border.all(color: Colors.blue, width: 1)),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [wordType.gradientStart, wordType.gradientEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: AutoSizeText(
                  hebrewValue,
                  maxLines: 1,
                  minFontSize: 30,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.rubik(
                    fontSize: 120,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ],
            ),
            if (extraTranslations.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '(${extraTranslations.join(', ')})',
                style: GoogleFonts.rubik(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
