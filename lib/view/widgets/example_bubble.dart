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
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          begin: Colors.transparent,
          end: outlined ? AppColors.verbMain : Colors.transparent,
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        builder: (context, borderColor, child) => CustomPaint(
          painter: _BubblePainter(
            fillColor: AppColors.bubbleBackground,
            borderColor: borderColor ?? Colors.transparent,
          ),
          child: child,
        ),
        child: Padding(
          // left = tailWidth(5) + inner(12); others unchanged
          padding: const EdgeInsets.fromLTRB(17, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.volume_up_outlined,
                    size: 20, color: AppColors.textSecondary),
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
              const SizedBox(width: 12),
              SvgPicture.asset(iconPath, width: 24, height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Paints the chat-bubble shape: rounded rect with a bottom-left tail.
// The tail is 5px wide and ~16px tall; all other dimensions scale with widget size.
class _BubblePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _BubblePainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawPath(path, Paint()..color = fillColor);
    if (borderColor.a > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    const r = 16.0;
    const tw = 5.0;
    const tailH = 21.0;

    final rectPath = Path()
      ..addRRect(RRect.fromLTRBR(tw, 0, w, h, const Radius.circular(r)));

    // Tail shape in its own 18×21 coordinate space, translated to bottom-left of rect.
    final dy = h - tailH;
    final tailPath = Path()
      ..moveTo(5, dy + 13.3171)
      ..lineTo(5, dy)
      ..lineTo(18, dy + 5.77156)
      ..cubicTo(16.3333, dy + 9.26948, 12.6106, dy + 15.866,  11,  dy + 17.3147)
      ..cubicTo(7.5,     dy + 20.4628, 6.5,     dy + 21,       0,   dy + 21)
      ..cubicTo(2,       dy + 19.4634, 5,       dy + 17.5146,  5,   dy + 13.3171)
      ..close();

    return Path.combine(PathOperation.union, rectPath, tailPath);
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
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
