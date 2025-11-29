import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

class RootRepository {
  final AppDatabase database;
  final Dio dio;

  RootRepository(this.database, this.dio);

  Future<void> insertRoot(RootDto dto) async {
    await database.into(database.rootTable).insert(
      RootTableCompanion(
        id: Value(dto.id),
        value: Value(dto.value),
        version: Value(dto.version),
      ),
    );
  }

  Future<List<RootDto>> getRootsFromApi() async {
    final response = await dio.get(
      'http://localhost:9999/api/root?page=0&size=1000',
    );

    if (response.statusCode == 200) {
      final responseBody = response.data as Map<String, dynamic>;

      final List<dynamic> data = responseBody['content'] is List
          ? responseBody['content'] as List<dynamic>
          : [];

      return data
          .map((item) => RootDto.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to fetch');
  }
}
