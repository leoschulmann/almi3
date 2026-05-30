import 'package:almi3/core/config.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/binyan_dto.dart';
import 'package:almi3/model/dto/gizrah_dto.dart';
import 'package:almi3/model/dto/prep_dto.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/dto/verb_dto.dart';
import 'package:almi3/model/dto/verb_form_example_simple_dto.dart';
import 'package:almi3/model/dto/verb_form_simple_dto.dart';
import 'package:almi3/model/dto/verb_t9n_dto.dart';
import 'package:almi3/model/repository/binyan_repository.dart';
import 'package:almi3/model/repository/gizrah_repo.dart';
import 'package:almi3/model/repository/prep_repo.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/model/repository/verb_form_example_repository.dart';
import 'package:almi3/model/repository/verb_form_example_t9n_repository.dart';
import 'package:almi3/model/repository/verb_form_repository.dart';
import 'package:almi3/model/repository/verb_form_t13n_repository.dart';
import 'package:almi3/model/repository/verb_gizrah_repository.dart';
import 'package:almi3/model/repository/verb_prep_repository.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/model/repository/verb_t9n_repository.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:almi3/viewmodel/state/sync_page_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _base = '${AppConfig.backendUrl}/api/sync/simple';

final NotifierProvider<SimpleSyncViewmodelNotifier, SyncViewmodelState> simpleSyncViewmodelProvider =
    NotifierProvider<SimpleSyncViewmodelNotifier, SyncViewmodelState>(SimpleSyncViewmodelNotifier.new);

final Provider<VerbFormRepository> verbFormRepositoryProvider =
    Provider((ref) => VerbFormRepository(ref.watch(appDatabaseProvider)));

final Provider<VerbFormT13nRepository> verbFormT13nRepositoryProvider =
    Provider((ref) => VerbFormT13nRepository(ref.watch(appDatabaseProvider)));

final Provider<VerbFormExampleRepository> verbFormExampleRepositoryProvider =
    Provider((ref) => VerbFormExampleRepository(ref.watch(appDatabaseProvider)));

final Provider<VerbFormExampleT9nRepository> verbFormExampleT9nRepositoryProvider =
    Provider((ref) => VerbFormExampleT9nRepository(ref.watch(appDatabaseProvider)));

class SimpleSyncViewmodelNotifier extends Notifier<SyncViewmodelState> {
  late final RootRepository _rootRepo;
  late final BinyanRepository _binyanRepo;
  late final PrepositionRepository _prepRepo;
  late final GizrahRepository _gizrahRepo;
  late final VerbRepository _verbRepo;
  late final VerbTranslationRepository _verbT9nRepo;
  late final VerbPrepRepository _verbPrepRepo;
  late final VerbGizrahRepository _verbGizrahRepo;
  late final VerbFormRepository _verbFormRepo;
  late final VerbFormT13nRepository _verbFormT13nRepo;
  late final VerbFormExampleRepository _verbFormExampleRepo;
  late final VerbFormExampleT9nRepository _verbFormExampleT9nRepo;

  final Dio _dio = Dio()
    ..interceptors.add(LogInterceptor(
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
      logPrint: (o) => logger.d('Dio: $o'),
    ));

  @override
  SyncViewmodelState build() {
    _rootRepo = ref.watch(rootRepositoryProvider);
    _binyanRepo = ref.watch(binyanRepositoryProvider);
    _prepRepo = ref.watch(prepositionRepositoryProvider);
    _gizrahRepo = ref.watch(gizrahRepositoryProvider);
    _verbRepo = ref.watch(verbRepositoryProvider);
    _verbT9nRepo = ref.watch(verbTranslationRepositoryProvider);
    _verbPrepRepo = ref.watch(verbPrepRepositoryProvider);
    _verbGizrahRepo = ref.watch(verbGizrahRepositoryProvider);
    _verbFormRepo = ref.watch(verbFormRepositoryProvider);
    _verbFormT13nRepo = ref.watch(verbFormT13nRepositoryProvider);
    _verbFormExampleRepo = ref.watch(verbFormExampleRepositoryProvider);
    _verbFormExampleT9nRepo = ref.watch(verbFormExampleT9nRepositoryProvider);
    return const SyncViewmodelState();
  }

  Future<void> fetchAndInsertFromApi() async {
    final stopwatch = Stopwatch()..start();
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      logger.i('SimpleSyncViewmodel: starting sync');

      final result = await _runSync();

      logger.i('SimpleSyncViewmodel: sync complete - $result');
      state = state.copyWith(
        isLoading: false,
        inserted: result.inserted,
        updated: result.updated,
        skipped: result.skipped,
      );
    } catch (e, st) {
      logger.e('SimpleSyncViewmodel: sync failed', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    } finally {
      stopwatch.stop();
      logger.i('SimpleSyncViewmodel: took ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  Future<SyncResult> _runSync() async {
    final binyans = await _fetchList('$_base/binyan', BinyanDto.fromJson);
    final binyanRes = await _binyanRepo.upsertBinyans(binyans);

    final preps = await _fetchList('$_base/prep', PrepositionDto.fromJson);
    final prepRes = await _prepRepo.upsertPrepositions(preps);

    final gizrahs = await _fetchList('$_base/gizrah', GizrahDto.fromJson);
    final gizrahRes = await _gizrahRepo.upsertGizrah(gizrahs);

    final roots = await _fetchList('$_base/root', RootDto.fromJson);
    final rootRes = await _rootRepo.upsertRoots(roots);

    final verbs = await _fetchList('$_base/verb', VerbSyncDto.fromJson);
    final verbRes = await _verbRepo.upsertVerbs(verbs);
    final verbT9nRes = await _verbT9nRepo.upsertForBatch({
      for (final v in verbs) v.id: v.translations,
    });

    await _verbPrepRepo.dropAllLinks();
    final prepLinks = await _fetchList('$_base/vb-pp', VerbPrepositionLinkDto.fromJson);
    final prepLinkRes = await _verbPrepRepo.insertBatch(prepLinks);

    await _verbGizrahRepo.dropAllLinks();
    final gizrahLinks = await _fetchList('$_base/vb-gz', VerbGizrahLinkDto.fromJson);
    final gizrahLinkRes = await _verbGizrahRepo.insertBatch(gizrahLinks);

    final verbForms = await _fetchList('$_base/vform', VerbFormSimpleDto.fromJson);
    final verbFormRes = await _verbFormRepo.upsertVerbForms(verbForms);
    final verbFormT13nRes = await _verbFormT13nRepo.upsertForVerbForms(verbForms);

    final examples = await _fetchList('$_base/vf-ex', VerbFormExampleSimpleDto.fromJson);
    final exampleRes = await _verbFormExampleRepo.upsertExamples(examples);
    final exampleT9nRes = await _verbFormExampleT9nRepo.upsertForExamples(examples);

    return SyncResult.empty()
        .addResult(binyanRes)
        .addResult(prepRes)
        .addResult(gizrahRes)
        .addResult(rootRes)
        .addResult(verbRes)
        .addResult(verbT9nRes)
        .addResult(prepLinkRes)
        .addResult(gizrahLinkRes)
        .addResult(verbFormRes)
        .addResult(verbFormT13nRes)
        .addResult(exampleRes)
        .addResult(exampleT9nRes);
  }

  Future<List<T>> _fetchList<T>(String url, T Function(Map<String, dynamic>) fromJson) async {
    logger.d('Fetching $url');
    final response = await _dio.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch $url: status ${response.statusCode}');
    }
    final list = response.data as List<dynamic>;
    logger.i('Fetched ${list.length} items from $url');
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}
