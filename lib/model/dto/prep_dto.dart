import 'package:json_annotation/json_annotation.dart';

part 'prep_dto.g.dart';

@JsonSerializable()
class PrepositionDto {
  @JsonKey(name: "id")
  final int id;

  @JsonKey(name: "p")
  final String value;

  @JsonKey(name: "ver")
  final int version;

  PrepositionDto({required this.id, required this.value, required this.version});

  factory PrepositionDto.fromJson(Map<String, dynamic> json) => _$PrepositionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$PrepositionDtoToJson(this);
}
