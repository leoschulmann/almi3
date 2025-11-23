import 'package:drift/drift.dart';

@TableIndex(name: "verb_val_idx", columns: {#value})
class VerbTable extends Table {
  IntColumn get id => integer()();

  TextColumn get value => text().withLength(min: 1, max: 255)();

  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
