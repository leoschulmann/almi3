import 'package:drift/drift.dart';

import 'verb_table.dart';
import 'gizrah_table.dart';

@TableIndex(name: "vg_verb_fk_idx", columns: {#verbId})
@TableIndex(name: "vg_gizrah_fk_idx", columns: {#gizrahId})
class VerbGizrahTable extends Table {
  IntColumn get verbId => integer().references(VerbTable, #id)();

  IntColumn get gizrahId => integer().references(GizrahTable, #id)();

  @override
  Set<Column> get primaryKey => {verbId, gizrahId};
}
