import 'package:almi3/model/db/tables/verb_table.dart';
import 'package:drift/drift.dart';

@TableIndex(name: "vform__verb__idx", columns: {#verbId})
@TableIndex(name: "vform__value__idx", columns: {#value})
class VerbFormTable extends Table {
  IntColumn get id => integer()();
  IntColumn get verbId => integer().references(VerbTable, #id)();
  IntColumn get version => integer()();
  TextColumn get value => text().withLength(min: 1, max: 255)();
  IntColumn get tense => integer()();
  IntColumn get person => integer()();
  IntColumn get plurality => integer()();
  IntColumn get gender => integer()();


  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'verb_form_table';
}
