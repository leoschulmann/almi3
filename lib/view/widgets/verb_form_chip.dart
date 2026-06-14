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

  const VerbFormChip({
    super.key,
    required this.form,
    this.iconPerson,
    this.iconPlurality,
    this.iconGender,
  });

  @override
  Widget build(BuildContext context) {
    final iconPath = grammaticIconAsset(
      iconPerson ?? form.person,
      iconPlurality ?? form.plurality,
      iconGender ?? form.gender,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                form.value,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.rubik(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              if (form.translit.isNotEmpty)
                Text(
                  form.translit,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          SvgPicture.asset(iconPath, width: 24, height: 24),
        ],
      ),
    );
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
