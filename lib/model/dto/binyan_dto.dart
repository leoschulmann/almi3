import 'package:json_annotation/json_annotation.dart';

part 'binyan_dto.g.dart';

@JsonSerializable()
class BinyanDto {
  @JsonKey(name: "id")
  final int id;

  @JsonKey(name: "b")
  final String value;

  @JsonKey(name: "ver")
  final int version;

  BinyanDto({required this.id, required this.value, required this.version});

  factory BinyanDto.fromJson(Map<String, dynamic> json) => _$BinyanDtoFromJson(json);

  Map<String, dynamic> toJson() => _$BinyanDtoToJson(this);
}
