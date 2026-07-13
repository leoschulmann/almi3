import 'package:drift/drift.dart';

@TableIndex(name: "prep_val_idx", columns: {#value})
class PrepositionTable extends Table{
  IntColumn get id => integer()();

  TextColumn get value => text().withLength(min: 1, max: 32)();

  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}