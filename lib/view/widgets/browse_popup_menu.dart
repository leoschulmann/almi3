import 'dart:math';

import 'package:almi3/view/adjective_list_page.dart';
import 'package:almi3/view/noun_list_page.dart';
import 'package:almi3/view/verb_list_page.dart';
import 'package:flutter/material.dart';

OverlayEntry? _activeEntry;

/// Shows an animated popup menu above [anchorKey] with Browse sub-sections.
/// [onSelect] receives a page widget to push onto the Browse tab navigator.
void showBrowsePopupMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required void Function(Widget page) onSelect,
}) {
  _dismissBrowsePopupMenu();

  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  final anchorTopLeft = renderBox.localToGlobal(Offset.zero);
  final anchorSize = renderBox.size;
  final screenWidth = MediaQuery.of(context).size.width;

  _activeEntry = OverlayEntry(
    builder: (_) => _BrowseMenuOverlay(
      anchorTopLeft: anchorTopLeft,
      anchorSize: anchorSize,
      screenWidth: screenWidth,
      onSelect: (page) {
        _dismissBrowsePopupMenu();
        onSelect(page);
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

class _BrowseMenuOverlay extends StatefulWidget {
  final Offset anchorTopLeft;
  final Size anchorSize;
  final double screenWidth;
  final void Function(Widget page) onSelect;
  final VoidCallback onDismiss;

  const _BrowseMenuOverlay({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.screenWidth,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_BrowseMenuOverlay> createState() => _BrowseMenuOverlayState();
}

class _BrowseMenuOverlayState extends State<_BrowseMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _cardWidth = 160.0;
  static const _notchSize = 10.0;
  static const _gapAboveNav = 6.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
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
    final anchorCenterX =
        widget.anchorTopLeft.dx + widget.anchorSize.width / 2;
    final cardLeft =
        max(8.0, min(anchorCenterX - _cardWidth / 2, widget.screenWidth - _cardWidth - 8));
    // Position bottom of the notch at the top of the nav bar minus gap
    final cardBottom = MediaQuery.of(context).size.height -
        widget.anchorTopLeft.dy +
        _gapAboveNav;

    return Stack(
      children: [
        // Barrier — captures taps outside the menu
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: cardLeft,
          bottom: cardBottom,
          width: _cardWidth,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MenuCard(onSelect: widget.onSelect),
                  // Notch pointing down toward the nav button
                  Center(
                    child: CustomPaint(
                      size: Size(_notchSize * 2, _notchSize),
                      painter: _DownTrianglePainter(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _MenuCard extends StatelessWidget {
  final void Function(Widget page) onSelect;

  const _MenuCard({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuItem(label: 'Verbs', onTap: () => onSelect(const VerbListPage())),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _MenuItem(label: 'Nouns', onTap: () => onSelect(const NounListPage())),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _MenuItem(label: 'Adjectives', onTap: () => onSelect(const AdjectiveListPage())),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DownTrianglePainter extends CustomPainter {
  final Color color;
  const _DownTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DownTrianglePainter old) => old.color != color;
}

