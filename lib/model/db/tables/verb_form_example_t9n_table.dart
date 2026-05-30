import 'package:almi3/model/db/tables/verb_form_example_table.dart';
import 'package:drift/drift.dart';

@TableIndex(name: "vfext9n__ex__idx", columns: {#exampleId})
class VerbFormExampleTranslationTable extends Table {
  IntColumn get id => integer()();
  IntColumn get exampleId => integer().references(VerbFormExampleTable, #id)();
  TextColumn get lang => text().withLength(min: 1, max: 16)();
  TextColumn get value => text().withLength(min: 1, max: 255)();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'verb_form_example_t9n_table';
}
