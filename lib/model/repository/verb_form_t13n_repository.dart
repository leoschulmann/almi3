import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_form_simple_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbFormT13nRepository {
  final AppDatabase database;

  VerbFormT13nRepository(this.database);

  /// Inserts or replaces all transliterations for a batch of verb forms.
  /// Uses insertOrReplace so re-syncing is idempotent.
  Future<SyncResult> upsertForVerbForms(List<VerbFormSimpleDto> verbForms) async {
    final companions = [
      for (final vf in verbForms)
        for (final t in vf.transliterations)
          VerbFormTransliterationTableCompanion(
            id: Value(t.id),
            verbFormId: Value(vf.id),
            value: Value(t.value),
            version: Value(t.version),
            lang: Value(t.lang),
          ),
    ];

    if (companions.isEmpty) return SyncResult.empty();

    await database.batch(
      (b) => b.insertAll(database.verbFormTransliterationTable, companions, mode: InsertMode.insertOrReplace),
    );

    return SyncResult(inserted: companions.length, updated: 0, skipped: 0);
  }
}
