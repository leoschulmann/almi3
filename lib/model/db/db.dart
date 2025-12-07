import 'dart:io';

import 'package:almi3/model/db/tables/binyan_table.dart';
import 'package:almi3/model/db/tables/gizrah_table.dart';
import 'package:almi3/model/db/tables/prep_table.dart';
import 'package:almi3/model/db/tables/root_table.dart';
import 'package:almi3/model/db/tables/verb_gizrah_table.dart';
import 'package:almi3/model/db/tables/verb_prep_table.dart';
import 'package:almi3/model/db/tables/verb_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'db.g.dart';

@DriftDatabase(
  tables: [RootTable, BinyanTable, VerbTable, GizrahTable, VerbGizrahTable, PrepositionTable, VerbPrepTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'almidb.sqlite'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to sandboxing.
    final String cachebase = (await getTemporaryDirectory()).path;
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = cachebase;

    print('DB path: ${dbFolder.path}/almidb.sqlite');

    return NativeDatabase.createInBackground(file);
  });
}
