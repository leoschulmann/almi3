// Time model for the learning engine. All storage/scheduling is done in
// Unix seconds, UTC. Local time is only for display, never inside the
// engine (see learning_engine_spec.md §2).

/// Current time as Unix seconds (UTC).
int nowUtcSeconds() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

/// Returns the Unix-seconds timestamp of the start of the "logical day"
/// containing [unixSec], where a new day begins at [boundaryHour] (0-23,
/// UTC). This is the most recent boundary-hour crossing at or before
/// [unixSec].
int dayBoundary(int unixSec, int boundaryHour) {
  final utc = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000, isUtc: true);
  var boundary = DateTime.utc(utc.year, utc.month, utc.day, boundaryHour);
  if (boundary.isAfter(utc)) {
    boundary = boundary.subtract(const Duration(days: 1));
  }
  return boundary.millisecondsSinceEpoch ~/ 1000;
}
