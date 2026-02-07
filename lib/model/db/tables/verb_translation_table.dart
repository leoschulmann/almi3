import 'package:almi3/model/db/tables/verb_table.dart';
import 'package:drift/drift.dart';

@TableIndex(name: "verb_fk_idx", columns: {#verbId})
class VerbTranslationTable extends Table {
  IntColumn get id => integer()();

  TextColumn get value => text().withLength(min: 1, max: 64)();

  IntColumn get version => integer()();

  TextColumn get lang => text().withLength(min: 1, max: 16)();
  
  IntColumn get verbId => integer().references(VerbTable, #id)();

  @override
  Set<Column> get primaryKey => {id};
}
