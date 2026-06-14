import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WordTitle extends StatelessWidget {
  final String translation;
  final String hebrewValue;
  final WordType wordType;

  const WordTitle({
    super.key,
    required this.translation,
    required this.hebrewValue,
    required this.wordType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (translation.isNotEmpty) ...[
          Expanded(
            child: AutoSizeText(
              translation,
              maxLines: 2,
              minFontSize: 18,
              style: GoogleFonts.rubik(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          fit: FlexFit.loose,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [wordType.gradientStart, wordType.gradientEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: AutoSizeText(
              hebrewValue,
              maxLines: 1,
              minFontSize: 18,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.rubik(
                fontSize: 174,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
