import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/enums.dart';




class WordChip extends StatefulWidget {
  final String hebrewText;
  final String translation;
  final WordType type;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onTap;

  const WordChip({
    super.key,
    required this.hebrewText,
    required this.translation,
    required this.type,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.onTap,
  });

  @override
  State<WordChip> createState() => _WordChipState();
}

class _WordChipState extends State<WordChip> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _bookmarkController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _bookmarkScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _bookmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bookmarkScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bookmarkController, curve: Curves.easeOut));

    _bookmarkController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) setState(() {});
    });

    if (widget.isBookmarked) _bookmarkController.value = 1.0;
  }

  @override
  void didUpdateWidget(WordChip old) {
    super.didUpdateWidget(old);
    if (widget.isBookmarked != old.isBookmarked) {
      if (widget.isBookmarked) {
        _bookmarkController.forward(from: 0);
      } else {
        _bookmarkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bookmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.type.textColor;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _pulseController.forward(from: 0);
        widget.onBookmarkToggle?.call();
      },
      child: ScaleTransition(
        scale: _pulseScale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: LinearGradient(
              colors: [widget.type.gradientStart, widget.type.gradientEnd],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.hebrewText,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.rubik(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
              ),
              if (widget.translation.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  widget.translation,
                  style: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: color,
                    height: 1.2,
                  ),
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: widget.isBookmarked || _bookmarkController.isAnimating
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ScaleTransition(
                          scale: _bookmarkScale,
                          child: _BookmarkIcon(color: color),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkIcon extends StatelessWidget {
  final Color color;
  const _BookmarkIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 16),
      painter: _BookmarkPainter(color: color),
    );
  }
}

class _BookmarkPainter extends CustomPainter {
  final Color color;
  const _BookmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 13.75;
    final sy = size.height / 15.6303;
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 14.7664 * sy)
      ..lineTo(0, 1 * sy)
      ..cubicTo(0, 0.4477 * sy, 0.4477 * sx, 0, 1 * sx, 0)
      ..lineTo(12.75 * sx, 0)
      ..cubicTo(13.3023 * sx, 0, 13.75 * sx, 0.4477 * sy, 13.75 * sx, 1 * sy)
      ..lineTo(13.75 * sx, 14.7664 * sy)
      ..cubicTo(13.75 * sx, 15.6303 * sy, 12.7284 * sx, 16.0877 * sy, 12.084 * sx, 15.5123 * sy)
      ..lineTo(7.541 * sx, 11.4558 * sy)
      ..cubicTo(7.162 * sx, 11.1171 * sy, 6.588 * sx, 11.1171 * sy, 6.209 * sx, 11.4558 * sy)
      ..lineTo(1.666 * sx, 15.5123 * sy)
      ..cubicTo(1.022 * sx, 16.0877 * sy, 0, 15.6303 * sy, 0, 14.7664 * sy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BookmarkPainter old) => old.color != color;
}
