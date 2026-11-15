import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App bar toggle: Hebrew with niqqud vs ktiv male (no vowel marks).
class NiqqudBtn extends ConsumerWidget {
  final double fontSize;

  const NiqqudBtn({super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showNiqqudProvider);
    return AdaptiveIconButton(
      tooltip: AppLocalizations.of(context)!.toggleNiqqudTooltip,
      onPressed: () => ref.read(settingsProvider.notifier).setShowNiqqud(!show),
      icon: Text(
        show ? '\u05D0\u05B8' : '\u05D0',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: AppColors.tekhelet),
      ),
    );
  }
}
