import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/view/widgets/verb_form_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VerbTenseSection extends StatelessWidget {
  final String label;
  final Tense tense;
  final List<VerbFormDisplayDto> forms;

  const VerbTenseSection({super.key, required this.label, required this.tense, required this.forms});

  @override
  Widget build(BuildContext context) {
    // Exact match by (person, plurality, gender)
    final exactMap = {
      for (final f in forms)
        (person: f.person, plurality: f.plurality, gender: f.gender): f,
    };

    final rows = tenseFormRows(tense);
    final isPresentLike = tense == Tense.present || tense == Tense.imperative;

    return Column(
      children: [
        _SectionHeader(label: label),
        const SizedBox(height: 12),
        ...rows.map((rowKeys) {
          final chips = rowKeys.map((slot) {
            // Try exact match first; fall back to (plurality, gender) for present/imperative
            // where DB may store person=none instead of person=second
            VerbFormDisplayDto? form = exactMap[slot];
            if (form == null && isPresentLike) {
              form = forms.firstWhereOrNull(
                    (f) => f.plurality == slot.plurality && f.gender == slot.gender,
              );
            }
            if (form == null) return null;
            return (form: form, slot: slot);
          }).nonNulls.toList();

          if (chips.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: chips
                  .expand((c) => [
                VerbFormChip(
                  form: c.form,
                  // For present/imperative, override icon to show 2nd person
                  iconPerson: isPresentLike ? c.slot.person : null,
                  iconPlurality: isPresentLike ? c.slot.plurality : null,
                  iconGender: isPresentLike ? c.slot.gender : null,
                ),
                const SizedBox(width: 7),
              ])
                  .toList()
                ..removeLast(),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

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

extension<T> on List<T?> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (item != null && test(item)) return item;
    }
    return null;
  }
}