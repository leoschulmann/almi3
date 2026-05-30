import 'package:json_annotation/json_annotation.dart';

part 'verb_form_simple_dto.g.dart';

/// DTOs matching /api/sync/simple/vform response.
/// Transliterations are nested — verbFormId is not in the nested object, use parent id when persisting.
@JsonSerializable()
class VerbFormSimpleDto {
  final int id;

  @JsonKey(name: 'vb')
  final int verbId;

  @JsonKey(name: 'v')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  @JsonKey(name: 't')
  final int tense;

  @JsonKey(name: 'p')
  final int person;

  @JsonKey(name: 'pl')
  final int plurality;

  @JsonKey(name: 'g')
  final int gender;

  @JsonKey(name: 'ts')
  final List<VerbFormTranslitSimpleDto> transliterations;

  const VerbFormSimpleDto({
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

  factory VerbFormSimpleDto.fromJson(Map<String, dynamic> json) => _$VerbFormSimpleDtoFromJson(json);
  Map<String, dynamic> toJson() => _$VerbFormSimpleDtoToJson(this);
}

@JsonSerializable()
class VerbFormTranslitSimpleDto {
  final int id;

  @JsonKey(name: 'v')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  final String lang;

  const VerbFormTranslitSimpleDto({
    required this.id,
    required this.value,
    required this.version,
    required this.lang,
  });

  factory VerbFormTranslitSimpleDto.fromJson(Map<String, dynamic> json) => _$VerbFormTranslitSimpleDtoFromJson(json);
  Map<String, dynamic> toJson() => _$VerbFormTranslitSimpleDtoToJson(this);
}
