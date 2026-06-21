import 'package:almi3/core/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TenseSectionHeader extends StatelessWidget {
  final String label;

  const TenseSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.verbMain)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: AppColors.verbMain,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.verbMain)),
      ],
    );
  }
}
