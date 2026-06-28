import 'package:almi3/core/app_colors.dart';
import 'package:flutter/material.dart';

enum RootFilter { all, saved, toReview }

class RootFilterBar extends StatelessWidget {
  final RootFilter filter;
  final ValueChanged<RootFilter> onChanged;

  const RootFilterBar({super.key, required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _Segment(label: 'All', selected: filter == RootFilter.all, onTap: () => onChanged(RootFilter.all)),
          _Segment(label: 'Saved', selected: filter == RootFilter.saved, onTap: () => onChanged(RootFilter.saved)),
          _Segment(label: 'To review', selected: filter == RootFilter.toReview, onTap: () => onChanged(RootFilter.toReview)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [const BoxShadow(color: AppColors.filterThumbShadow, blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
