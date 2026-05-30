import 'package:json_annotation/json_annotation.dart';

part 'verb_form_example_simple_dto.g.dart';

/// DTOs matching /api/sync/simple/vf-ex response.
@JsonSerializable()
class VerbFormExampleSimpleDto {
  final int id;

  @JsonKey(name: 'vf')
  final int verbFormId;

  @JsonKey(name: 'e')
  final String value;

  @JsonKey(name: 'f')
  final String? file;

  @JsonKey(name: 'ver')
  final int version;

  final List<VerbFormExampleTranslationSimpleDto> translations;

  const VerbFormExampleSimpleDto({
    required this.id,
    required this.verbFormId,
    required this.value,
    required this.file,
    required this.version,
    required this.translations,
  });

  factory VerbFormExampleSimpleDto.fromJson(Map<String, dynamic> json) => _$VerbFormExampleSimpleDtoFromJson(json);
  Map<String, dynamic> toJson() => _$VerbFormExampleSimpleDtoToJson(this);
}

@JsonSerializable()
class VerbFormExampleTranslationSimpleDto {
  final int id;

  @JsonKey(name: 'l')
  final String lang;

  @JsonKey(name: 't')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  const VerbFormExampleTranslationSimpleDto({
    required this.id,
    required this.lang,
    required this.value,
    required this.version,
  });

  factory VerbFormExampleTranslationSimpleDto.fromJson(Map<String, dynamic> json) =>
      _$VerbFormExampleTranslationSimpleDtoFromJson(json);
  Map<String, dynamic> toJson() => _$VerbFormExampleTranslationSimpleDtoToJson(this);
}
