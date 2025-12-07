import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/binyan_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class BinyanRepository {
  final AppDatabase database;

  BinyanRepository({required this.database});

  Future<SyncResult> upsertBinyans(List<BinyanDto> list) async {
    try {
      final List<int> binyanIds = list.map((binyan) => binyan.id).toList();
      final List<BinyanTableData> existing = await (database.select(
            database.binyanTable,
          )..where((tbl) => tbl.id.isIn(binyanIds))).get();

      var asMap = <int, BinyanTableData>{for (BinyanTableData binyan in existing) binyan.id: binyan};

      final toInsert = <BinyanTableCompanion>[];
      final toUpdate = <BinyanTableCompanion>[];

      int inserted = 0;
      int updated = 0;
      int skipped = 0;

      for (final binyan in list) {
            BinyanTableData? current = asMap[binyan.id];
            if (current == null) {
              toInsert.add(
                BinyanTableCompanion(id: Value(binyan.id), value: Value(binyan.value), version: Value(binyan.version)),
              );
              inserted++;
            } else if (binyan.version > current.version) {
              toUpdate.add(
                BinyanTableCompanion(id: Value(binyan.id), value: Value(binyan.value), version: Value(binyan.version)),
              );
              updated++;
            } else {
              skipped++;
              logger.d('Skipping upserting binyan ${binyan.value}, actual version already exists');
            }
          }

      if (toInsert.isNotEmpty) {
            logger.d('Batch inserting binyans to db: ${toInsert.length}');
            await database.batch((batch) => batch.insertAll(database.binyanTable, toInsert));
          }

      if(toUpdate.isNotEmpty) {
            logger.d('Batch update binyans to DB: ${toUpdate.length}');
            await database.batch((batch) => batch.insertAll(database.binyanTable, toUpdate));
          }

      return SyncResult(inserted: inserted, updated: updated, skipped: skipped);
    } catch (e, stackTrace) {
      logger.e('Error upserting binyans', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
