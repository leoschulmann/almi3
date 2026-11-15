import 'package:drift/drift.dart';

@TableIndex(name: "gizrah_val_idx", columns: {#value})
class GizrahTable extends Table{
  IntColumn get id => integer()();

  TextColumn get value => text().withLength(min: 1, max: 32)();

  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}