import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/icon_assets.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/view/widgets/bookmark_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class VerbFormChip extends StatefulWidget {
  final VerbFormDisplayDto form;
  final GrammaticalPerson? iconPerson;
  final Plurality? iconPlurality;
  final GrammaticalGender? iconGender;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkToggle;

  const VerbFormChip({
    super.key,
    required this.form,
    this.iconPerson,
    this.iconPlurality,
    this.iconGender,
    this.isBookmarked = false,
    this.onTap,
    this.onBookmarkToggle,
  });

  @override
  State<VerbFormChip> createState() => _VerbFormChipState();
}

class _VerbFormChipState extends State<VerbFormChip> with TickerProviderStateMixin {
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
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.07), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.07, end: 1.0), weight: 1),
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
  void didUpdateWidget(VerbFormChip old) {
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
    final iconPath = grammaticIconAsset(
      widget.iconPerson ?? widget.form.person,
      widget.iconPlurality ?? widget.form.plurality,
      widget.iconGender ?? widget.form.gender,
    );

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.cardBorder),
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
                  padding: EdgeInsetsGeometry.only(left: 12, right: 2),
                  child: SlideTransition(
                    position: _bookmarkSlide,
                    child: BookmarkRibbon(size: const Size(18, 27), color: AppColors.verbMain),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.form.value,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.rubik(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (widget.form.translit.isNotEmpty) const SizedBox(height: 2),
                        Text(
                          widget.form.translit,
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
                    const SizedBox(width: 10),
                    SvgPicture.asset(iconPath, width: 24, height: 24),
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
