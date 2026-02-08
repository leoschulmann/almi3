import 'package:almi3/model/dto/binyan_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BinyanDto', () {
    test('fromJson parses correctly', () {
      final json = {'id': 1, 'b': 'פעל', 'ver': 1};

      final dto = BinyanDto.fromJson(json);

      expect(dto.id, 1);
      expect(dto.value, 'פעל');
      expect(dto.version, 1);
    });

    test('toJson serializes correctly', () {
      final dto = BinyanDto(id: 2, value: 'הפעיל', version: 3);

      final json = dto.toJson();

      expect(json['id'], 2);
      expect(json['b'], 'הפעיל');
      expect(json['ver'], 3);
    });

    test('roundtrip preserves data', () {
      final original = BinyanDto(id: 5, value: 'התפעל', version: 2);

      final restored = BinyanDto.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.value, original.value);
      expect(restored.version, original.version);
    });
  });
}
