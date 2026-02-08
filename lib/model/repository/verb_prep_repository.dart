import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/prep_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbPrepRepository {
  final AppDatabase database;

  VerbPrepRepository(this.database);

  Future<SyncResult> upsertLinks(List<VerbPrepositionLinkDto> links) async {
    if (links.isEmpty) {
      return SyncResult.empty();
    }

    // Get existing links for these verb IDs
    final List<int> verbIds = links.map((l) => l.verbId).toSet().toList();
    final List<VerbPrepTableData> existing = await (database.select(database.verbPrepTable)
          ..where((t) => t.verbId.isIn(verbIds)))
        .get();

    final Set<String> existingKeys = existing.map((e) => '${e.verbId}_${e.prepId}').toSet();

    final toInsert = <VerbPrepTableCompanion>[];
    int skipped = 0;

    for (final link in links) {
      final key = '${link.verbId}_${link.prepositionId}';
      if (existingKeys.contains(key)) {
        skipped++;
      } else {
        toInsert.add(VerbPrepTableCompanion(
          verbId: Value(link.verbId),
          prepId: Value(link.prepositionId),
        ));
      }
    }

    if (toInsert.isNotEmpty) {
      await database.batch((batch) {
        batch.insertAll(database.verbPrepTable, toInsert);
      });
      logger.d('Inserted ${toInsert.length} verb-prep links');
    }

    return SyncResult(inserted: toInsert.length, updated: 0, skipped: skipped);
  }
  
  Future<SyncResult> insertBatch(List<VerbPrepositionLinkDto> links) async {
    if (links.isEmpty) {
      logger.i("No preposition links to insert");
      return SyncResult.empty();
    }

    List<VerbPrepTableCompanion> toInsert = links
        .map((l) => VerbPrepTableCompanion(verbId: Value(l.verbId), prepId: Value(l.prepositionId)))
        .toList();
    
    await database.batch((runInBatch) => runInBatch.insertAll(database.verbPrepTable, toInsert));
    logger.d('Inserted ${toInsert.length} verb-prep links');
    return SyncResult(inserted: toInsert.length, updated: 0, skipped: 0);

  }

  Future<void> dropAllLinks() async {
    await (database.delete(database.verbPrepTable)).go();
  }
  
  
/*
  Future<void> deleteForVerb(int verbId) async {
    await (database.delete(database.verbPrepTable)
          ..where((t) => t.verbId.equals(verbId)))
        .go();
  }

  Future<List<int>> getPrepIdsForVerb(int verbId) async {
    final rows = await (database.select(database.verbPrepTable)
          ..where((t) => t.verbId.equals(verbId)))
        .get();
    return rows.map((r) => r.prepId).toList();
  }
*/
}
