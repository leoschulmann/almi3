import 'package:almi3/model/dto/verb_t9n_dto.dart';
import 'package:json_annotation/json_annotation.dart';

part 'verb_dto.g.dart';

@JsonSerializable()
class VerbSyncDto {
  @JsonKey(name: "id")
  final int id;

  @JsonKey(name: "v")
  final String value;

  @JsonKey(name: "ver")
  final int version;

  @JsonKey(name: "r_id")
  final int rootId;

  @JsonKey(name: "b_id")
  final int binyanId;

  @JsonKey(name: "g_id")
  final List<int> gizrahIds;

  @JsonKey(name: "p_id")
  final List<int> prepIds;

  @JsonKey(name: "t")
  final List<VerbTranslationDto> translations;

  VerbSyncDto({
    required this.id,
    required this.value,
    required this.version,
    required this.rootId,
    required this.binyanId,
    required this.gizrahIds,
    required this.prepIds,
    required this.translations,
  });

  factory VerbSyncDto.fromJson(Map<String, dynamic> json) => _$VerbSyncDtoFromJson(json);
}
