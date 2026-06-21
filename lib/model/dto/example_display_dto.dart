import 'package:almi3/core/enums.dart';

class VerbFormExampleGroupDto {
  final int formId;
  final String formValue;
  final Tense tense;
  final GrammaticalPerson person;
  final Plurality plurality;
  final GrammaticalGender gender;
  final List<ExampleDisplayDto> examples;

  const VerbFormExampleGroupDto({
    required this.formId,
    required this.formValue,
    required this.tense,
    required this.person,
    required this.plurality,
    required this.gender,
    required this.examples,
  });
}

class ExampleDisplayDto {
  final int exampleId;
  final String sentence;
  final String translation;

  const ExampleDisplayDto({
    required this.exampleId,
    required this.sentence,
    required this.translation,
  });
}
