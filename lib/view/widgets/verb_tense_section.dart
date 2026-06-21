import 'package:almi3/core/enums.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/view/widgets/tense_section_header.dart';
import 'package:almi3/view/widgets/verb_form_chip.dart';
import 'package:flutter/material.dart';

class VerbTenseSection extends StatelessWidget {
  final String label;
  final Tense tense;
  final List<VerbFormDisplayDto> forms;
  final void Function(VerbFormDisplayDto form)? onChipTap;

  const VerbTenseSection({
    super.key,
    required this.label,
    required this.tense,
    required this.forms,
    this.onChipTap,
  });

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
        TenseSectionHeader(label: label),
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
                  onTap: onChipTap != null ? () => onChipTap!(c.form) : null,
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



extension<T> on List<T?> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (item != null && test(item)) return item;
    }
    return null;
  }
}

typedef FormKey = ({GrammaticalPerson person, Plurality plurality, GrammaticalGender gender});

// Display rows per tense, ordered 1st→2nd→3rd person, sg→pl, masc→fem→none.
// For present/imperative, person is the ICON person (DB may store none).
List<List<FormKey>> tenseFormRows(Tense tense) {
  const mk = _mk;
  switch (tense) {
    case Tense.infinitive:
      return [[mk(GrammaticalPerson.none, Plurality.none, GrammaticalGender.none)]];
    case Tense.present:
    case Tense.imperative:
      return [
        [mk(GrammaticalPerson.second, Plurality.singular, GrammaticalGender.masculine),
          mk(GrammaticalPerson.second, Plurality.singular, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.second, Plurality.plural, GrammaticalGender.masculine),
          mk(GrammaticalPerson.second, Plurality.plural, GrammaticalGender.feminine)],
      ];
    case Tense.past:
      return [
        [mk(GrammaticalPerson.first, Plurality.singular, GrammaticalGender.none),
          mk(GrammaticalPerson.first, Plurality.plural, GrammaticalGender.none)],
        [mk(GrammaticalPerson.second, Plurality.singular, GrammaticalGender.masculine),
          mk(GrammaticalPerson.second, Plurality.singular, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.second, Plurality.plural, GrammaticalGender.masculine),
          mk(GrammaticalPerson.second, Plurality.plural, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.third, Plurality.singular, GrammaticalGender.masculine),
          mk(GrammaticalPerson.third, Plurality.singular, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.third, Plurality.plural, GrammaticalGender.none)],
      ];
    case Tense.future:
      return [
        [mk(GrammaticalPerson.first, Plurality.singular, GrammaticalGender.none),
          mk(GrammaticalPerson.first, Plurality.plural, GrammaticalGender.none)],
        [mk(GrammaticalPerson.second, Plurality.singular, GrammaticalGender.masculine),
          mk(GrammaticalPerson.second, Plurality.singular, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.second, Plurality.plural, GrammaticalGender.masculine),
          mk(GrammaticalPerson.second, Plurality.plural, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.third, Plurality.singular, GrammaticalGender.masculine),
          mk(GrammaticalPerson.third, Plurality.singular, GrammaticalGender.feminine)],
        [mk(GrammaticalPerson.third, Plurality.plural, GrammaticalGender.masculine),
          mk(GrammaticalPerson.third, Plurality.plural, GrammaticalGender.feminine)],
      ];
  }
}

FormKey _mk(GrammaticalPerson p, Plurality pl, GrammaticalGender g) =>
    (person: p, plurality: pl, gender: g);
