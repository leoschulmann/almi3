import 'package:almi3/core/logger.dart';

/// Sync result from upsert operation
class SyncResult {
  final int inserted;
  final int updated;
  final int skipped;

  SyncResult({required this.inserted, required this.updated, required this.skipped});

  SyncResult.empty()
      : inserted = 0,
        updated = 0,
        skipped = 0;

  int get total => inserted + updated + skipped;

  @override
  String toString() => 'SyncResult(inserted=$inserted, updated=$updated, skipped=$skipped, total=$total)';
  
  SyncResult addResult(SyncResult other) {
    logger.d("Adding $other to $this");
    return SyncResult(
        inserted: inserted + other.inserted, updated: updated + other.updated, skipped: skipped + other.skipped);
  }
}
