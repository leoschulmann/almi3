import 'package:drift/drift.dart';

// CREATE TABLE fsrs_params (
//     version           INTEGER PRIMARY KEY,
//     params_json       TEXT NOT NULL,   -- array of 21 numbers
//     desired_retention REAL NOT NULL,
//     created_at        INTEGER NOT NULL,
//     note              TEXT             -- 'default' | 'optimized@1200revs' etc
// );
class FsrsParamsTable extends Table {
  IntColumn get version => integer().autoIncrement()();
  TextColumn get paramsJson => text()();
  RealColumn get desiredRetention => real()();
  IntColumn get createdAt => integer()();
  TextColumn get note => text().nullable()();

  @override
  String get tableName => 'fsrs_params';
}
