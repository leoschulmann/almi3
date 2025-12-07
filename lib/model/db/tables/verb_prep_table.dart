import 'package:almi3/model/db/tables/prep_table.dart';
import 'package:drift/drift.dart';

import 'verb_table.dart';

@TableIndex(name: "vp_verb_fk_idx", columns: {#verbId})
@TableIndex(name: "vp_gizrah_fk_idx", columns: {#prepId})
class VerbPrepTable extends Table {
  IntColumn get verbId => integer().references(VerbTable, #id)();

  IntColumn get prepId => integer().references(PrepositionTable, #id)();

  @override
  Set<Column> get primaryKey => {verbId, prepId};
}
