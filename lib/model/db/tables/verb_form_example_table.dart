import 'package:almi3/model/db/tables/verb_form_table.dart';
import 'package:drift/drift.dart';

@TableIndex(name: "vfex__vf__idx", columns: {#verbFormId})
class VerbFormExampleTable extends Table {
  IntColumn get id => integer()();
  IntColumn get verbFormId => integer().references(VerbFormTable, #id)();
  TextColumn get value => text().withLength(min: 1, max: 255)();
  TextColumn get file => text().withLength(min: 1, max: 255).nullable()();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'verb_form_example_table';
}
