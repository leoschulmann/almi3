import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/enums.dart';
import 'peek_bookmark.dart';

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

class _WordChipState extends State<WordChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseScale = TweenSequence([
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
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _pulseController.forward(from: 0);
        widget.onBookmarkToggle?.call();
      },
      child: ScaleTransition(
        scale: _pulseScale,
        child: PeekBookmark(
          isBookmarked: widget.isBookmarked,
          peekColor: widget.type.textColor,
          peekWidth: 12,
          borderRadius: 23,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.type.gradientStart, widget.type.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(23),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  widget.hebrewText,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.notoSansHebrew(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: widget.type.textColor,
                    height: 1.2,
                  ),
                ),
                if (widget.translation.isNotEmpty) ...[
                  const SizedBox(width: 9),
                  Text(
                    widget.translation,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: widget.type.textColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
