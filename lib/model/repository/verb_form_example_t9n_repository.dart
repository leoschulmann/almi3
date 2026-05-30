import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/verb_form_example_simple_dto.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:drift/drift.dart';

class VerbFormExampleT9nRepository {
  final AppDatabase database;

  VerbFormExampleT9nRepository(this.database);

  Future<SyncResult> upsertForExamples(List<VerbFormExampleSimpleDto> examples) async {
    final companions = [
      for (final ex in examples)
        for (final t in ex.translations)
          VerbFormExampleTranslationTableCompanion(
            id: Value(t.id),
            exampleId: Value(ex.id),
            lang: Value(t.lang),
            value: Value(t.value),
            version: Value(t.version),
          ),
    ];

    if (companions.isEmpty) return SyncResult.empty();

    await database.batch(
      (b) => b.insertAll(database.verbFormExampleTranslationTable, companions, mode: InsertMode.insertOrReplace),
    );

    return SyncResult(inserted: companions.length, updated: 0, skipped: 0);
  }
}
