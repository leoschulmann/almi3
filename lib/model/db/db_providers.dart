import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/db/vocab_db.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart' show appDatabaseProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Content database (bundled dictionary data). Alias of the pre-existing
/// [appDatabaseProvider] so there is a single AppDatabase instance/connection
/// shared across the app.
final Provider<VocabularyDatabase> contentDbProvider = appDatabaseProvider;

/// User database (bookmarks, FSRS review state, progress, answer history).
/// Independent singleton, own sqlite file (almi_user.sqlite). No cross-db
/// joins in drift: combine data from contentDbProvider and userDbProvider
/// with separate queries composed in Dart.
final Provider<UserDatabase> userDbProvider = Provider((ref) => UserDatabase());
