import 'package:drift/drift.dart';

@TableIndex(name: "root_val_idx", columns: {#value})
class RootTable extends Table {
  IntColumn get id => integer()();
  TextColumn get value => text().withLength(min: 2, max: 16)();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
