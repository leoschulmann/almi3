import 'package:almi3/model/db/tables/verb_form_table.dart';
import 'package:drift/drift.dart';

@TableIndex(name: "vformt13n__vf__idx", columns: {#verbFormId})
class VerbFormTransliterationTable extends Table {
  IntColumn get id => integer()();

  IntColumn get verbFormId => integer().references(VerbFormTable, #id)();
  IntColumn get version => integer()();
  TextColumn get value => text().withLength(min: 1, max: 255)();
  TextColumn get lang => text().withLength(min: 1, max: 16)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'verb_form_t13n_table';
  
  
}
