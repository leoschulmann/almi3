import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/enums.dart';
import 'bookmark_ribbon.dart';




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
  late final Animation<Offset> _bookmarkSlide;

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
    _bookmarkSlide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _bookmarkController, curve: Curves.easeOut));

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
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: LinearGradient(
              colors: [widget.type.gradientStart, widget.type.gradientEnd],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: widget.isBookmarked || _bookmarkController.isAnimating
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: SlideTransition(
                          position: _bookmarkSlide,
                          child: BookmarkRibbon(size: const Size(16, 23), color: color),
                          // child: BookmarkRibbon(size: const Size(18, 27), color: color),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding:
                widget.isBookmarked || _bookmarkController.isAnimating ?
                const EdgeInsets.only(left: 10, right: 14, top: 8, bottom: 8)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

