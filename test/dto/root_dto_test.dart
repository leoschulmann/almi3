import 'package:almi3/model/dto/root_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RootDto', () {
    test('fromJson parses correctly', () {
      final json = {'id': 1, 'r': 'שלם', 'ver': 2};

      final dto = RootDto.fromJson(json);

      expect(dto.id, 1);
      expect(dto.value, 'שלם');
      expect(dto.version, 2);
    });

    test('toJson serializes correctly', () {
      final dto = RootDto(id: 1, value: 'שלם', version: 2);

      final json = dto.toJson();

      expect(json['id'], 1);
      expect(json['r'], 'שלם');
      expect(json['ver'], 2);
    });

    test('roundtrip preserves data', () {
      final original = RootDto(id: 42, value: 'כתב', version: 5);

      final restored = RootDto.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.value, original.value);
      expect(restored.version, original.version);
    });
  });
}
