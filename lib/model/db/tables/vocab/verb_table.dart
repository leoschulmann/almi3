import 'package:drift/drift.dart';

import 'root_table.dart';
import 'binyan_table.dart';

@TableIndex(name: "verb_val_idx", columns: {#value})
@TableIndex(name: "root_fk_idx", columns: {#rootId})
@TableIndex(name: "binyan_fk_idx", columns: {#binyanId})
class VerbTable extends Table {
  IntColumn get id => integer()();

  TextColumn get value => text().withLength(min: 1, max: 255)();

  IntColumn get version => integer()();

  IntColumn get rootId => integer().references(RootTable, #id)();

  IntColumn get binyanId => integer().references(BinyanTable, #id)();

  @override
  Set<Column> get primaryKey => {id};
}
