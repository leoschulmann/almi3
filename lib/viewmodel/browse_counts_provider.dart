import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BrowseCounts {
  final int roots;
  final int verbs;
  final int nouns;     // TODO: wire when noun table exists
  final int adjs;      // TODO: wire when adjective table exists
  
  const BrowseCounts({
    required this.roots,
    required this.verbs,
    this.nouns = 0,
    this.adjs = 0,
  });
}

final browseCountsProvider = FutureProvider<BrowseCounts>((ref) async {
  final rootRepo = ref.watch(rootRepositoryProvider);
  final verbRepo = ref.watch(verbRepositoryProvider);
  ref.watch(syncCounterProvider); // refresh after sync

  final results = await Future.wait([
    rootRepo.getTotalCount(),
    verbRepo.getTotalCount(),
  ]);

  return BrowseCounts(roots: results[0], verbs: results[1]);
});
