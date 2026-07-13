import 'dart:convert';

import 'package:almi3/core/clock.dart';
import 'package:almi3/core/engine_config.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// Maps the user-facing review-intensity setting to fsrs's desiredRetention
/// (0..1). Deliberately conservative spread around the library default of 0.9.
double desiredRetentionForIntensity(ReviewIntensity intensity) {
  switch (intensity) {
    case ReviewIntensity.relaxed:
      return 0.85;
    case ReviewIntensity.normal:
      return 0.9;
    case ReviewIntensity.intense:
      return 0.95;
  }
}

/// Builds the single [fsrs.Scheduler] instance from the latest row in
/// fsrs_params, inserting a default row (desiredRetention derived from
/// settings.reviewIntensity) if none exists yet.
final schedulerProvider = FutureProvider<fsrs.Scheduler>((ref) async {
  final repo = ref.watch(fsrsParamsRepositoryProvider);

  FsrsParamsTableData? latest = await repo.getLatest();

  if (latest == null) {
    final intensity = ref.watch(settingsProvider).reviewIntensity;
    final desiredRetention = desiredRetentionForIntensity(intensity);

    // INSERT INTO fsrs_params (params_json, desired_retention, created_at, note) VALUES (?, ?, ?, 'default')
    await repo.insert(
      FsrsParamsTableCompanion.insert(
        paramsJson: jsonEncode(defaultFsrsWeights),
        desiredRetention: desiredRetention,
        createdAt: nowUtcSeconds(),
        note: const Value('default'),
      ),
    );

    latest = await repo.getLatest();
  }

  final row = latest!;
  final params = (jsonDecode(row.paramsJson) as List).map((e) => (e as num).toDouble()).toList();

  return fsrs.Scheduler(
    parameters: params,
    desiredRetention: row.desiredRetention,
    learningSteps: defaultLearningSteps,
    relearningSteps: defaultRelearningSteps,
    maximumInterval: defaultMaximumInterval,
    enableFuzzing: true,
  );
});
