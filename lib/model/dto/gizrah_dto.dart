import 'package:json_annotation/json_annotation.dart';

part 'gizrah_dto.g.dart';

@JsonSerializable()
class GizrahDto {
  @JsonKey(name: "id")
  final int id;

  @JsonKey(name: "g")
  final String value;

  @JsonKey(name: "ver")
  final int version;

  GizrahDto({required this.id, required this.value, required this.version});

  factory GizrahDto.fromJson(Map<String, dynamic> json) => _$GizrahDtoFromJson(json);

  Map<String, dynamic> toJson() => _$GizrahDtoToJson(this);
}
