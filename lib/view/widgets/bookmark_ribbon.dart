import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class BookmarkRibbon extends StatelessWidget {
  final Size size;
  final Color color;

  const BookmarkRibbon({
    super.key,
    this.size = const Size(25, 37),
    this.color = AppColors.bookmark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _BookmarkPainter(color: color));
  }
}

class _BookmarkPainter extends CustomPainter {
  final Color color;

  const _BookmarkPainter({required this.color});

  // Lighten a color by blending it toward white by [amount] (0.0–1.0).
  Color _lighten(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    final light = _lighten(color, 0.45);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, light, color],
        stops: const [0.0, 0.05, 0.31],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.78)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BookmarkPainter old) => old.color != color;
}
