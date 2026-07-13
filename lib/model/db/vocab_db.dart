import 'dart:io';

import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/tables/verb_form_example_t9n_table.dart';
import 'package:almi3/model/db/tables/verb_form_example_table.dart';
import 'package:almi3/model/db/tables/verb_form_t13n_table.dart';
import 'package:almi3/model/db/tables/verb_form_table.dart';
import 'package:flutter/foundation.dart';
import 'package:almi3/model/db/tables/binyan_table.dart';
import 'package:almi3/model/db/tables/gizrah_table.dart';
import 'package:almi3/model/db/tables/prep_table.dart';
import 'package:almi3/model/db/tables/root_table.dart';
import 'package:almi3/model/db/tables/verb_gizrah_table.dart';
import 'package:almi3/model/db/tables/verb_prep_table.dart';
import 'package:almi3/model/db/tables/verb_table.dart';
import 'package:almi3/model/db/tables/verb_translation_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'vocab_db.g.dart';

// Content database: bundled dictionary/reference data only. User-owned data
// (bookmarks, progress, review history) lives in UserDatabase (user_db.dart).
@DriftDatabase(
  tables: [
    RootTable, BinyanTable, VerbTable, GizrahTable, VerbGizrahTable, PrepositionTable, VerbPrepTable,
    VerbTranslationTable, VerbFormTable, VerbFormTransliterationTable,
    VerbFormExampleTable, VerbFormExampleTranslationTable,
  ],
)
class VocabularyDatabase extends _$VocabularyDatabase {
  VocabularyDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      logger.i('onCreate: creating all tables...');
      await m.createAll();
      logger.i('onCreate: tables created successfully');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      logger.i('onUpgrade: migrating from $from to $to');
    },
  );
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'almidb.sqlite'));

    // sqlite3 3.x bundles its own SQLite — no Android workaround needed.
    // Point temp files at the app cache dir (sandbox-safe on both platforms).
    final String cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    logger.d('DB path: ${file.path}');

    return NativeDatabase.createInBackground(
      file,
      logStatements: kDebugMode,
    );
  });
}
