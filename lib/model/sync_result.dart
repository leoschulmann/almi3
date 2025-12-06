/// Sync result from upsert operation
class SyncResult {
  final int inserted;
  final int updated;
  final int skipped;

  SyncResult({required this.inserted, required this.updated, required this.skipped});

  int get total => inserted + updated + skipped;

  @override
  String toString() => 'SyncResult(inserted=$inserted, updated=$updated, skipped=$skipped, total=$total)';
}
