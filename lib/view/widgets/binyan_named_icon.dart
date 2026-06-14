import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/icon_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';


class BinyanNamedIcon extends StatelessWidget {
  final String binyanName;

  const BinyanNamedIcon({super.key, required this.binyanName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(binyanIconAsset(binyanName), width: 53, height: 44),
        const SizedBox(height: 2),
        Text(
          binyanDisplayName(binyanName).toUpperCase(),
          style: GoogleFonts.rubik(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
