import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

class RootRepository {
  final AppDatabase database;
  final Dio dio;

  RootRepository(this.database, this.dio);

  Future<void> insertRoot(RootDto dto) async {
    await database
        .into(database.rootTable)
        .insert(RootTableCompanion(id: Value(dto.id), value: Value(dto.value), version: Value(dto.version)));
  }

  Future<List<RootDto>> getRootsFromApi() async {
    final response = await dio.get('http://localhost:9999/api/root?page=0&size=1000');

    if (response.statusCode == 200) {
      final responseBody = response.data as Map<String, dynamic>;

      final List<dynamic> data = responseBody['content'] is List ? responseBody['content'] as List<dynamic> : [];

      return data.map((item) => RootDto.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch');
  }

  Future<List<RootDto>> getRootsPaged(int page, int size) async {
    try {
      logger.d('getRootsPaged: page=$page, size=$size');
      final List<RootTableData> future = await (database.select(
        database.rootTable,
      )..limit(size, offset: page * size)).get();

      logger.i('getRootsPaged: fetched ${future.length} items from database');
      final result = future
          .map((data) => RootDto(id: data.id, value: data.value, version: data.version))
          .toList();
      logger.d('getRootsPaged: converted to ${result.length} DTOs');
      return result;
    } catch (e, stackTrace) {
      logger.e('getRootsPaged: ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
