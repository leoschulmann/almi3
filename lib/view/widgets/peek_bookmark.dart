import 'package:flutter/material.dart';

/// Wraps [child] with an animated colored crescent that slides out to the right
/// when [isBookmarked] is true. The crescent matches [child]'s corner radius.
///
/// Callers own the long-press gesture and pulse animation; this widget only
/// handles the peek layer and the layout space it needs.
class PeekBookmark extends StatefulWidget {
  final bool isBookmarked;
  final Color peekColor;
  final double peekWidth;
  final double borderRadius;
  final Widget child;

  const PeekBookmark({
    super.key,
    required this.isBookmarked,
    required this.peekColor,
    required this.child,
    this.peekWidth = 12,
    this.borderRadius = 16,
  });

  @override
  State<PeekBookmark> createState() => _PeekBookmarkState();
}

class _PeekBookmarkState extends State<PeekBookmark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.isBookmarked) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(PeekBookmark old) {
    super.didUpdateWidget(old);
    if (widget.isBookmarked != old.isBookmarked) {
      widget.isBookmarked ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        return Padding(
          padding: EdgeInsets.only(right: t * widget.peekWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (t > 0)
                Positioned.fill(
                  right: -(t * widget.peekWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.peekColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
