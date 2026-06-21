import 'package:almi3/core/app_colors.dart';
import 'package:almi3/view/widgets/root_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class RootCard extends StatefulWidget {
  final String hebrewText;
  final int adjCount;
  final int verbCount;
  final int nounCount;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkToggle;

  const RootCard({
    super.key,
    required this.hebrewText,
    this.adjCount = 0,
    this.verbCount = 0,
    this.nounCount = 0,
    this.isBookmarked = false,
    this.onTap,
    this.onBookmarkToggle,
  });

  @override
  State<RootCard> createState() => _RootCardState();
}

class _RootCardState extends State<RootCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scale;

  static const _bookmarkHeight = 37.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence([
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
        scale: _scale,
        child: Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.rootCard, AppColors.rootCardGradient],
            ),
            boxShadow: const [
              BoxShadow(color: AppColors.cardShadow, blurRadius: 8, spreadRadius: 1, offset: Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 5,
                  child: Center(
                    child: Text(
                      widget.hebrewText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.notoSansHebrew(
                        fontSize: 66,
                        fontWeight: FontWeight.w800,
                        color: AppColors.rootCardText,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ProgressBar(
                    adjCount: widget.adjCount,
                    verbCount: widget.verbCount,
                    nounCount: widget.nounCount,
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 5,
                  child: Center(
                    child: _BadgeGroup(
                      adjCount: widget.adjCount,
                      verbCount: widget.verbCount,
                      nounCount: widget.nounCount,
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: widget.isBookmarked ? 0 : -_bookmarkHeight,
                  left: 25,
                  child: const BookmarkRibbon(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeGroup extends StatelessWidget {
  final int adjCount;
  final int verbCount;
  final int nounCount;

  const _BadgeGroup({required this.adjCount, required this.verbCount, required this.nounCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(count: adjCount, color: AppColors.adjectiveMain),
        const SizedBox(width: 2),
        _Badge(count: verbCount, color: AppColors.verbMain),
        const SizedBox(width: 2),
        _Badge(count: nounCount, color: AppColors.nounMain),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int adjCount;
  final int verbCount;
  final int nounCount;

  const _ProgressBar({required this.adjCount, required this.verbCount, required this.nounCount});

  @override
  Widget build(BuildContext context) {
    final total = adjCount + verbCount + nounCount;

    return SizedBox(
      height: 5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (total == 0) {
            return Container(color: AppColors.progressBackground);
          }
          final adjWidth = width * adjCount / total;
          final verbWidth = width * verbCount / total;
          final nounWidth = width * nounCount / total;
          return Row(
            children: [
              if (adjWidth > 0) Container(width: adjWidth, color: AppColors.adjectiveMain),
              if (verbWidth > 0) Container(width: verbWidth, color: AppColors.verbMain),
              if (nounWidth > 0) Container(width: nounWidth, color: AppColors.nounMain),
              Expanded(child: Container(color: AppColors.progressBackground)),
            ],
          );
        },
      ),
    );
  }
}
