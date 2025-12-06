class SyncViewmodelState {
  final bool isLoading;
  final String? errMsg;
  final int inserted;
  final int updated;
  final int skipped;

  const SyncViewmodelState({
    this.isLoading = false,
    this.errMsg,
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
  });

  int get total => inserted + updated + skipped;

  SyncViewmodelState copyWith({bool? isLoading, String? errorMessage, int? inserted, int? updated, int? skipped}) {
    return SyncViewmodelState(
      isLoading: isLoading ?? this.isLoading,
      errMsg: errorMessage ?? errMsg,
      inserted: inserted ?? this.inserted,
      updated: updated ?? this.updated,
      skipped: skipped ?? this.skipped,
    );
  }
}
