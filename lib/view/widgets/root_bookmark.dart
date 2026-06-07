import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class BookmarkRibbon extends StatelessWidget {
  const BookmarkRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(25, 37), painter: _BookmarkPainter());
  }
}

class _BookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.bookmark, AppColors.bookmarkGradient, AppColors.bookmark],
        stops: [0.0, 0.05, 0.31],
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
  bool shouldRepaint(_) => false;
}
