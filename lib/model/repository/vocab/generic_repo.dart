import 'package:almi3/core/logger.dart';
import 'package:almi3/model/sync_result.dart';

/// Generic upsert helper for managing batch insert/update operations with version checking
abstract class GenericRepository<DtoType, TableDataType, CompanionType> {
  /// Get the ID from a DTO object
  int getDtoId(DtoType dto);

  int getDataId(TableDataType data);

  /// Get the version from a DTO object
  int getDtoVersion(DtoType dto);

  /// Get the version from existing table data
  int getExistingVersion(TableDataType existing);

  /// Create a companion for insert/update from a DTO
  CompanionType createCompanion(DtoType dto);

  /// Execute batch insert operation
  Future<void> executeBatchInsert(List<CompanionType> companions);

  /// Execute batch update operation
  Future<void> executeBatchUpdate(List<CompanionType> companions);

  /// Fetch existing records by IDs from database
  Future<List<TableDataType>> fetchExistingByIds(List<int> ids);

  /// Perform upsert operation on a batch
  /// Returns SyncResult with counts of inserted, updated, and skipped records
  Future<SyncResult> upsertBatch(List<DtoType> batch) async {
    try {
      // Get IDs of all items in this batch
      final batchIds = batch.map((item) => getDtoId(item)).toList();

      // Fetch ALL existing items with these IDs from database in one query
      final List<TableDataType> existingItems = await fetchExistingByIds(batchIds);

      // Create a map for quick lookup: id -> existing item
      final Map<int, TableDataType> existingMap = {for (final item in existingItems) getDataId(item as dynamic): item};

      // Determine what to insert, update, and skip
      final toInsert = <CompanionType>[];
      final toUpdate = <CompanionType>[];
      // todo add toDelete

      int inserted = 0;
      int updated = 0;
      int skipped = 0;

      for (final DtoType apiItem in batch) {
        final int dtoId = getDtoId(apiItem);
        final TableDataType? existing = existingMap[dtoId];

        if (existing == null) {
          // Item doesn't exist - MARK FOR INSERT
          toInsert.add(createCompanion(apiItem));
          inserted++;
          logger.d('Upsert: will insert ${DtoType.toString()} id=$dtoId');
        } else if (getDtoVersion(apiItem) > getExistingVersion(existing)) {
          // Item exists but backend version is newer - MARK FOR UPDATE
          toUpdate.add(createCompanion(apiItem));
          updated++;
          logger.d(
            'Upsert: will update ${DtoType.toString()} id=$dtoId, version ${getExistingVersion(existing)} -> ${getDtoVersion(apiItem)}',
          );
        } else {
          // Item exists and local version is same or newer - SKIP
          skipped++;
          logger.d(
            'Upsert: will skip ${DtoType.toString()} id=$dtoId, local version=${getExistingVersion(existing)} >= backend version=${getDtoVersion(apiItem)}',
          );
        }
      }

      if (toInsert.isNotEmpty) {
        logger.d('Batch inserting ${toInsert.length} ${DtoType.toString()} items');
        await executeBatchInsert(toInsert);
      }

      if (toUpdate.isNotEmpty) {
        logger.d('Batch updating ${toUpdate.length} ${DtoType.toString()} items');
        await executeBatchUpdate(toUpdate);
      }

      logger.i('Batch complete: inserted=$inserted, updated=$updated, skipped=$skipped');
      return SyncResult(inserted: inserted, updated: updated, skipped: skipped);
    } catch (e, stackTrace) {
      logger.e('Error in upsertBatch', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
