import 'package:json_annotation/json_annotation.dart';

part 'root_dto.g.dart';

@JsonSerializable()
class RootDto {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'r')
  final String value;

  @JsonKey(name: 'ver')
  final int version;

  RootDto({
    required this.id,
    required this.value,
    required this.version,
  });

  factory RootDto.fromJson(Map<String, dynamic> json) =>
      _$RootDtoFromJson(json);

  Map<String, dynamic> toJson() => _$RootDtoToJson(this);
}
