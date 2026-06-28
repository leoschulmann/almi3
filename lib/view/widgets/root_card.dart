import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/root_summary_resolver.dart';
import 'package:almi3/model/dto/root_card_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class RootCard extends StatefulWidget {
  final String hebrewText;
  final bool isBookmarked;
  final RootCardStats? stats;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkToggle;

  const RootCard({
    super.key,
    required this.hebrewText,
    this.isBookmarked = false,
    this.stats,
    this.onTap,
    this.onBookmarkToggle,
  });

  @override
  State<RootCard> createState() => _RootCardState();
}

class _RootCardState extends State<RootCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scale;

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
    final summary = RootSummaryResolver.resolve(widget.stats);
    final metaLeft = widget.isBookmarked ? 22.0 : 18.0;

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
          height: 96,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: const [
              BoxShadow(color: AppColors.cardShadowSoft, blurRadius: 3, offset: Offset(0, 1)),
              BoxShadow(color: AppColors.hairline, blurRadius: 0, spreadRadius: 0.5),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // TODO(parallax): wrap ghost in Transform.translate and feed offset from:
                //   1. scroll-driven: card position in viewport via ScrollController → ±26px horizontal
                //   2. gyroscope-driven: sensors_plus stream → additive Offset, physical device only
                //   3. tap-pulse: onTapDown nudge in tap direction via AnimationController + Tween<Offset>
                // ghost watermark
                Positioned(
                  right: -30,
                  top: 0,
                  bottom: 5,
                  child: Align(
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: 0.045,
                      child: Text(
                        widget.hebrewText,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.frankRuhlLibre(
                          fontSize: 150,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          height: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

                // crisp root glyph
                Positioned(
                  right: 25,
                  top: 0,
                  bottom: 5,
                  child: Align(
                    alignment: const Alignment(0, -0.1),
                    child: Text(
                      widget.hebrewText,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.notoSansHebrew(
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),

                // meta block (left)
                Positioned(
                  left: metaLeft,
                  top: 0,
                  bottom: 5,
                  right: 80,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (summary.pillText != null) ...[
                          _ReviewPill(summary.pillText!),
                          const SizedBox(height: 7),
                        ],
                        Text(
                          summary.verdict,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.15,
                          ),
                        ),
                        if (summary.info.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            summary.info,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // saved spine slab
                if (widget.isBookmarked)
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 5,
                    child: SizedBox(
                      width: 7,
                      child: ColoredBox(color: AppColors.tekhelet),
                    ),
                  ),

                // composite progress bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ProgressBar(stats: widget.stats),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewPill extends StatelessWidget {
  final String text;

  const _ReviewPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.pillBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.pillDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.pillText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final RootCardStats? stats;

  const _ProgressBar({this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final total = s?.totalWords ?? 0;

    return SizedBox(
      height: 5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (s == null || total == 0) {
            return Container(color: AppColors.progressTrack);
          }

          final width = constraints.maxWidth;
          final verbW = width * s.verbs.learned / total;
          final nounW = width * s.nouns.learned / total;
          final adjW = width * s.adjs.learned / total;

          return Row(
            children: [
              if (verbW > 0) Container(width: verbW, color: AppColors.verbMain),
              if (nounW > 0) Container(width: nounW, color: AppColors.nounMain),
              if (adjW > 0) Container(width: adjW, color: AppColors.adjectiveMain),
              Expanded(child: Container(color: AppColors.progressTrack)),
            ],
          );
        },
      ),
    );
  }
}
