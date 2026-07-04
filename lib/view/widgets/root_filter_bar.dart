import 'package:almi3/core/platform_ui.dart';
import 'package:flutter/material.dart';

enum RootFilter { all, saved, toReview }

class RootFilterBar extends StatelessWidget {
  final RootFilter filter;
  final ValueChanged<RootFilter> onChanged;

  const RootFilterBar({super.key, required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AdaptiveSegmentedControl<RootFilter>(
      segments: const [
        (RootFilter.all, 'All'),
        (RootFilter.saved, 'Saved'),
        (RootFilter.toReview, 'To review'),
      ],
      selected: filter,
      onChanged: onChanged,
    );
  }
}
