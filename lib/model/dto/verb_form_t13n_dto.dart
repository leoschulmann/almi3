import 'package:json_annotation/json_annotation.dart';

part 'verb_form_t13n_dto.g.dart';

@JsonSerializable()
class VerbFormTransliterationDto {
  final int id;

  @JsonKey(name: 'vf')
  final int verbFormId;

  @JsonKey(name: 'v')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  final String lang;

  const VerbFormTransliterationDto({
    required this.id,
    required this.verbFormId,
    required this.value,
    required this.version,
    required this.lang,
  });

  factory VerbFormTransliterationDto.fromJson(Map<String, dynamic> json) => _$VerbFormTransliterationDtoFromJson(json);

  Map<String, dynamic> toJson() => _$VerbFormTransliterationDtoToJson(this);
}
