import 'package:almi3/core/enums.dart';

class VerbDetailDto {
  final int id;
  final String value;
  final String binyan;
  final String root;
  final List<String> gizrahs;
  final List<String> preps;
  final String translation;
  final List<VerbFormDisplayDto> forms;

  const VerbDetailDto({
    required this.id,
    required this.value,
    required this.binyan,
    required this.root,
    required this.gizrahs,
    required this.preps,
    required this.translation,
    required this.forms,
  });
}

class VerbFormDisplayDto {
  final int id;
  final String value;
  final String translit;
  final Tense tense;
  final GrammaticalPerson person;
  final Plurality plurality;
  final GrammaticalGender gender;

  const VerbFormDisplayDto({
    required this.id,
    required this.value,
    required this.translit,
    required this.tense,
    required this.person,
    required this.plurality,
    required this.gender,
  });
}
