import 'package:almi3/core/enums.dart';

class VerbDetailDto {
  final int id;
  final String value;
  final String binyan;
  final String root;
  final List<String> gizrahs;
  final List<String> preps;
  final List<String> translations;
  // True when [translations] was resolved on a fallback language rather
  // than the one requested -- one flag for the whole translations block
  // (§ story 2: a lexeme's translations resolve as a single language unit).
  final bool translationsIsFallback;
  final List<VerbFormDisplayDto> forms;

  const VerbDetailDto({
    required this.id,
    required this.value,
    required this.binyan,
    required this.root,
    required this.gizrahs,
    required this.preps,
    required this.translations,
    this.translationsIsFallback = false,
    required this.forms,
  });
}

class VerbFormDisplayDto {
  final int id;
  final String value;
  final String translit;
  // True when [translit] was resolved on a fallback language rather than
  // the one requested.
  final bool translitIsFallback;
  final Tense tense;
  final GrammaticalPerson person;
  final Plurality plurality;
  final GrammaticalGender gender;

  const VerbFormDisplayDto({
    required this.id,
    required this.value,
    required this.translit,
    this.translitIsFallback = false,
    required this.tense,
    required this.person,
    required this.plurality,
    required this.gender,
  });
}
