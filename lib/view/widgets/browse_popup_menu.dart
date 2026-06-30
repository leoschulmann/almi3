import 'dart:ui';

import 'package:almi3/core/app_colors.dart';
import 'package:almi3/view/adjective_list_page.dart';
import 'package:almi3/view/noun_list_page.dart';
import 'package:almi3/view/verb_list_page.dart';
import 'package:almi3/viewmodel/browse_counts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BrowseMode { allRoots, verbs, nouns, adjs }

OverlayEntry? _activeEntry;

void showBrowsePopupMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required BrowseMode currentMode,
  required void Function(Widget? page, BrowseMode mode) onSelect,
}) {
  _dismissBrowsePopupMenu();

  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  final anchorTopLeft = renderBox.localToGlobal(Offset.zero);
  final anchorSize = renderBox.size;
  final screenSize = MediaQuery.of(context).size;

  _activeEntry = OverlayEntry(
    builder: (ctx) => _BrowseMenuOverlay(
      anchorTopLeft: anchorTopLeft,
      anchorSize: anchorSize,
      screenSize: screenSize,
      currentMode: currentMode,
      onSelect: (page, mode) {
        _dismissBrowsePopupMenu();
        onSelect(page, mode); // page is null for allRoots
      },
      onDismiss: _dismissBrowsePopupMenu,
    ),
  );

  Overlay.of(context).insert(_activeEntry!);
}

void _dismissBrowsePopupMenu() {
  _activeEntry?.remove();
  _activeEntry = null;
}

// ---------------------------------------------------------------------------

class _BrowseMenuOverlay extends ConsumerStatefulWidget {
  final Offset anchorTopLeft;
  final Size anchorSize;
  final Size screenSize;
  final BrowseMode currentMode;
  final void Function(Widget? page, BrowseMode mode) onSelect;
  final VoidCallback onDismiss;

  const _BrowseMenuOverlay({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.screenSize,
    required this.currentMode,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  ConsumerState<_BrowseMenuOverlay> createState() => _BrowseMenuOverlayState();
}

class _BrowseMenuOverlayState extends ConsumerState<_BrowseMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  static const _popupWidth = 230.0;
  static const _caretWidth = 18.0;
  static const _caretHeight = 8.0;
  static const _popupBottomGap = 4.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(browseCountsProvider);

    // anchor center X — center of Browse tab
    final anchorCenterX = widget.anchorTopLeft.dx + widget.anchorSize.width / 2;

    // popup left — left-aligned to Browse tab, clamped to screen
    final popupLeft = (anchorCenterX - _caretWidth / 2 - 14.0)
        .clamp(8.0, widget.screenSize.width - _popupWidth - 8.0);

    // caret left — centered on Browse tab relative to popup
    final caretLeft = (anchorCenterX - popupLeft - _caretWidth / 2).clamp(12.0, _popupWidth - _caretWidth - 12.0);

    // bottom of popup sits above the tab bar top
    final tabBarTop = widget.anchorTopLeft.dy;
    final popupBottom = widget.screenSize.height - tabBarTop + _popupBottomGap;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Full-screen dismiss tap — translucent so taps pass through to nav bar items.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
            ),
          ),

          // Scrim with blur — clipped to content area above the tab bar.
          Positioned(
            left: 0, right: 0, top: 0,
            bottom: widget.screenSize.height - tabBarTop,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: const ColoredBox(color: Color(0x47000000)),
              ),
            ),
          ),

          // Popup card + caret — absorbs taps so they don't reach the dismiss layer.
          Positioned(
            left: popupLeft,
            bottom: popupBottom,
            width: _popupWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorb taps on card background
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PopupCard(
                        counts: countsAsync is AsyncData<BrowseCounts>
                            ? countsAsync.value
                            : null,
                        currentMode: widget.currentMode,
                        onSelect: widget.onSelect,
                      ),
                      // caret pointing down to Browse tab
                      Padding(
                        padding: EdgeInsets.only(left: caretLeft),
                        child: CustomPaint(
                          size: const Size(_caretWidth, _caretHeight),
                          painter: _CaretPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PopupCard extends StatelessWidget {
  final BrowseCounts? counts;
  final BrowseMode currentMode;
  // page is null for "All roots" — caller should pop to first route
  final void Function(Widget? page, BrowseMode mode) onSelect;

  const _PopupCard({
    required this.counts,
    required this.currentMode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xD1FFFFFF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x38000000), blurRadius: 40, offset: Offset(0, 12)),
              BoxShadow(color: Color(0x0F000000), blurRadius: 0, spreadRadius: 0.5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PopupRow(
                label: 'All roots',
                dot: AppColors.ink.withValues(alpha: 0.25),
                count: counts?.roots,
                isActive: currentMode == BrowseMode.allRoots,
                isFirst: true,
                onTap: () => onSelect(null, BrowseMode.allRoots),
              ),
              _PopupRow(
                label: 'Verbs',
                dot: AppColors.verbMain,
                count: counts?.verbs,
                isActive: currentMode == BrowseMode.verbs,
                onTap: () => onSelect(const VerbListPage(), BrowseMode.verbs),
              ),
              _PopupRow(
                label: 'Nouns',
                dot: AppColors.nounMain,
                count: counts?.nouns,
                isActive: currentMode == BrowseMode.nouns,
                onTap: () => onSelect(const NounListPage(), BrowseMode.nouns),
              ),
              _PopupRow(
                label: 'Adjectives',
                dot: AppColors.adjectiveMain,
                count: counts?.adjs,
                isActive: currentMode == BrowseMode.adjs,
                onTap: () => onSelect(const AdjectiveListPage(), BrowseMode.adjs),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupRow extends StatelessWidget {
  final String label;
  final Color dot;
  final int? count;
  final bool isActive;
  final bool isFirst;
  final VoidCallback onTap;

  const _PopupRow({
    required this.label,
    required this.dot,
    required this.onTap,
    this.count,
    this.isActive = false,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: isFirst
            ? null
            : const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x14000000), width: 0.5)),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            // type dot
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            // label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
            // count
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            // checkmark for active row
            if (isActive)
              const Icon(Icons.check_rounded, size: 17, color: AppColors.tekhelet),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CaretPainter extends CustomPainter {
  const _CaretPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = const Color(0x14000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final fill = Paint()..color = const Color(0xD1FFFFFF);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => false;
}
