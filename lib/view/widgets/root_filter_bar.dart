import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum RootFilter { all, saved, toReview }

class RootFilterBar extends StatelessWidget {
  final RootFilter filter;
  final ValueChanged<RootFilter> onChanged;

  const RootFilterBar({super.key, required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdaptiveSegmentedControl<RootFilter>(
      segments: [
        (RootFilter.all, l10n.filterAll),
        (RootFilter.saved, l10n.filterSaved),
        (RootFilter.toReview, l10n.filterToReview),
      ],
      selected: filter,
      onChanged: onChanged,
    );
  }
}
