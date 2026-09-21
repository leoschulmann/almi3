import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inline indicator shown next to a single field (translation,
/// transliteration, or example translation) when its value was resolved on
/// a fallback language rather than the one the user selected (CAP-3).
///
/// Per spec: no aggregated banner, no scale-pulse animation (this has no
/// physical/tappable card-like footprint) -- just an icon with a tooltip
/// explaining what happened.
class FallbackWarningMarker extends ConsumerWidget {
  final double size;

  const FallbackWarningMarker({super.key, this.size = 14});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider.select((s) => s.language));
    final message = switch (language) {
      AppLanguage.ru => 'Показан перевод на другом языке',
      AppLanguage.en => 'Shown in another language',
    };
    return Tooltip(
      message: message,
      child: Icon(
        Icons.info_outline,
        size: size,
        color: AppColors.textSecondary,
      ),
    );
  }
}
