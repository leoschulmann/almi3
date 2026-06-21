import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/icon_assets.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class VerbFormChip extends StatelessWidget {
  final VerbFormDisplayDto form;
  final GrammaticalPerson? iconPerson;
  final Plurality? iconPlurality;
  final GrammaticalGender? iconGender;
  final VoidCallback? onTap;

  const VerbFormChip({
    super.key,
    required this.form,
    this.iconPerson,
    this.iconPlurality,
    this.iconGender,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconPath = grammaticIconAsset(
      iconPerson ?? form.person,
      iconPlurality ?? form.plurality,
      iconGender ?? form.gender,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                form.value,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.rubik(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  // height: 1.1,
                  letterSpacing: -0.1,
                ),
              ),
              if (form.translit.isNotEmpty) SizedBox(height: 2),
              Text(
                form.translit,
                textAlign: TextAlign.end,
                style: GoogleFonts.rubik(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  // height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          SvgPicture.asset(iconPath, width: 24, height: 24),
        ],
      ),
    ),
    );
  }
}
