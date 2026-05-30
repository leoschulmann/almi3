import 'package:almi3/core/enums.dart';
import 'package:almi3/model/dto/verb_form_t13n_dto.dart';
import 'package:json_annotation/json_annotation.dart';

part 'verb_form_dto.g.dart';

@JsonSerializable()
class VerbFormDto {
  final int id;

  @JsonKey(name: 'vb')
  final int verbId;

  @JsonKey(name: 'v')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  @JsonKey(name: 't', fromJson: tenseFromJson)
  final Tense tense;

  @JsonKey(name: 'p', fromJson: personFromJson)
  final GrammaticalPerson person;

  @JsonKey(name: 'pl', fromJson: pluralityFromJson)
  final Plurality plurality;

  @JsonKey(name: 'g', fromJson: genderFromJson)
  final GrammaticalGender gender;

  @JsonKey(name: 'ts')
  final List<VerbFormTransliterationDto> transliterations;

  const VerbFormDto({
    required this.id,
    required this.verbId,
    required this.value,
    required this.version,
    required this.tense,
    required this.person,
    required this.plurality,
    required this.gender,
    required this.transliterations,
  });

  factory VerbFormDto.fromJson(Map<String, dynamic> json) => _$VerbFormDtoFromJson(json);

  Map<String, dynamic> toJson() => _$VerbFormDtoToJson(this);
}
