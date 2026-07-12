import 'package:flutter/material.dart';

/// Floating "saved" badge: a white disc with a colored bookmark glyph,
/// straddling the top edge of a card/chip. Pops in with a small overshoot
/// when bookmarked, and reverses (shrink + fade) when un-bookmarked.
///
/// Meant to be used as a child of a [Stack] with `clipBehavior: Clip.none`,
/// positioned via [top]/[left]/[right].
class BookmarkBadge extends StatefulWidget {
  final bool isBookmarked;
  final Color iconColor;
  final double size;
  final double top;
  final double? left;
  final double? right;

  const BookmarkBadge({
    super.key,
    required this.isBookmarked,
    required this.iconColor,
    this.size = 26,
    this.top = -11,
    this.left,
    this.right,
  });

  @override
  State<BookmarkBadge> createState() => _BookmarkBadgeState();
}

class _BookmarkBadgeState extends State<BookmarkBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    if (widget.isBookmarked) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(BookmarkBadge old) {
    super.didUpdateWidget(old);
    if (widget.isBookmarked != old.isBookmarked) {
      widget.isBookmarked
          ? _controller.forward(from: 0)
          : _controller.reverse(from: 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.value == 0) return const SizedBox.shrink();
          return Opacity(
            opacity: _fade.value,
            child: Transform.scale(scale: _scale.value, child: child),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.bookmark,
            size: widget.size * 0.5,
            color: widget.iconColor,
          ),
        ),
      ),
    );
  }
}
