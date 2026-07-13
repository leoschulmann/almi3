import 'dart:io';

import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/tables/user/answer_log_table.dart';
import 'package:almi3/model/db/tables/user/bookmark_table.dart';
import 'package:almi3/model/db/tables/user/card_fsrs_table.dart';
import 'package:almi3/model/db/tables/user/conjugation_card_table.dart';
import 'package:almi3/model/db/tables/user/fsrs_params_table.dart';
import 'package:almi3/model/db/tables/user/lexeme_progress_table.dart';
import 'package:almi3/model/db/tables/user/lexical_card_table.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'user_db.g.dart';

// User database: owns per-user data (bookmarks, FSRS review state,
// progress, answer history). Never joined against content.db in SQL;
// entity references into content.db are soft-refs (plain integers).
@DriftDatabase(
  tables: [
    CardFsrsTable,
    LexicalCardTable,
    ConjugationCardTable,
    LexemeProgressTable,
    AnswerLogTable,
    FsrsParamsTable,
    BookmarkTable,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      logger.i('UserDatabase onCreate: creating all tables...');
      await m.createAll();
      logger.i('UserDatabase onCreate: tables created successfully');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'almi_user.sqlite'));

    final String cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    logger.d('UserDB path: ${file.path}');

    return NativeDatabase.createInBackground(
      file,
      logStatements: kDebugMode,
    );
  });
}
