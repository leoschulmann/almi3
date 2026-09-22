import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class NiqqudBtn extends StatelessWidget {
  const NiqqudBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveIconButton(
      tooltip: AppLocalizations.of(context)!.toggleNiqqudTooltip,
      onPressed: () {
        // TODO: toggle niqqud
      },
      icon: const Text(
        'אָ',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tekhelet),
      ),
    );
  }
}
