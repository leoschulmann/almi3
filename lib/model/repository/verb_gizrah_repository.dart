import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/gizrah_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbGizrahRepository {
  final AppDatabase database;

  VerbGizrahRepository(this.database);

  Future<SyncResult> insertBatch(List<VerbGizrahLinkDto> links) async {
    if (links.isEmpty) {
      logger.i("No gizrah links to insert");
      return SyncResult.empty();
    }

    List<VerbGizrahTableCompanion> toInsert = links
        .map((l) => VerbGizrahTableCompanion(verbId: Value(l.verbId), gizrahId: Value(l.gizrahId)))
        .toList();

    await database.batch((runInBatch) => runInBatch.insertAll(database.verbGizrahTable, toInsert));
    logger.d('Inserted ${toInsert.length} verb-gizrah links');
    return SyncResult(inserted: toInsert.length, updated: 0, skipped: 0);

  }

  Future<void> dropAllLinks() async {
    await (database.delete(database.verbGizrahTable)).go();
  }
}