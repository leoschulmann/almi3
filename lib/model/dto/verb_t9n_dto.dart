import 'package:json_annotation/json_annotation.dart';

part 'verb_t9n_dto.g.dart';

@JsonSerializable()
class VerbTranslationDto {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 't')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  @JsonKey(name: 'l')
  final String lang;

  @JsonKey(includeFromJson: false, includeToJson: false)
  int? verbId;
  
  VerbTranslationDto({required this.id, required this.value, required this.version, required this.lang});

  factory VerbTranslationDto.fromJson(Map<String, dynamic> json) {
    return _$VerbTranslationDtoFromJson(json);
  }
}
