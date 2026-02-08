import 'package:almi3/core/config.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/binyan_dto.dart';
import 'package:almi3/model/dto/gizrah_dto.dart';
import 'package:almi3/model/dto/prep_dto.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/dto/verb_dto.dart';
import 'package:almi3/model/dto/verb_t9n_dto.dart';
import 'package:almi3/model/repository/binyan_repository.dart';
import 'package:almi3/model/repository/gizrah_repo.dart';
import 'package:almi3/model/repository/prep_repo.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/model/repository/verb_t9n_repository.dart';
import 'package:almi3/model/repository/verb_prep_repository.dart';
import 'package:almi3/model/sync_result.dart';
import 'package:almi3/viewmodel/state/sync_page_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider((ref) => AppDatabase());

final Provider<RootRepository> rootRepositoryProvider = Provider(
  (ref) => RootRepository(ref.watch(appDatabaseProvider)),
);

final Provider<BinyanRepository> binyanRepositoryProvider = Provider(
  (ref) => BinyanRepository(database: ref.watch(appDatabaseProvider)),
);

final Provider<PrepositionRepository> prepositionRepositoryProvider = Provider(
  (ref) => PrepositionRepository(database: ref.watch(appDatabaseProvider)),
);

final Provider<GizrahRepository> gizrahRepositoryProvider = Provider(
  (ref) => GizrahRepository(database: ref.watch(appDatabaseProvider)),
);

final Provider<VerbRepository> verbRepositoryProvider = Provider(
        (ref) => VerbRepository(ref.watch(appDatabaseProvider)));

final Provider<VerbTranslationRepository> verbTranslationRepositoryProvider = Provider(
  (ref) => VerbTranslationRepository(ref.watch(appDatabaseProvider)),
);

final Provider<VerbPrepRepository> verbPrepRepositoryProvider = Provider(
  (ref) => VerbPrepRepository(ref.watch(appDatabaseProvider)),
);

final NotifierProvider<SyncViewmodelNotifier, SyncViewmodelState> rootViewmodelProvider =
    NotifierProvider<SyncViewmodelNotifier, SyncViewmodelState>(SyncViewmodelNotifier.new);

class SyncViewmodelNotifier extends Notifier<SyncViewmodelState> {
  late final RootRepository _rootRepository;
  late final BinyanRepository _binyanRepository;
  late final PrepositionRepository _prepositionRepository;
  late final GizrahRepository _gizrahRepository;
  late final VerbRepository _verbRepository;
  late final VerbTranslationRepository _verbTranslationRepository;
  late final VerbPrepRepository _verbPrepRepository;
  final Dio _dio = Dio();

  @override
  SyncViewmodelState build() {
    _rootRepository = ref.watch(rootRepositoryProvider);
    _binyanRepository = ref.watch(binyanRepositoryProvider);
    _prepositionRepository = ref.watch(prepositionRepositoryProvider);
    _gizrahRepository = ref.watch(gizrahRepositoryProvider);
    _verbRepository = ref.watch(verbRepositoryProvider);
    _verbTranslationRepository = ref.watch(verbTranslationRepositoryProvider);
    _verbPrepRepository = ref.watch(verbPrepRepositoryProvider);

    return const SyncViewmodelState();
  }

  Future<void> fetchAndInsertFromApi() async {
    final stopwatch = Stopwatch()
      ..start();
    try {
      logger.i('fetchAndInsertFromApi: starting');
      state = state.copyWith(isLoading: true, errorMessage: null);

      final SyncResult result = await () async {
        try {
          logger.i('Starting batched fetch and upsert from backend');
          final List<BinyanDto> allBinyans = await _fetchBinyansFromApi();
          final SyncResult syncBinyansRes = await _persistBinyans(allBinyans);

          final List<PrepositionDto> allPrepositions = await _fetchPrepositionsFromApi();
          final SyncResult syncPrepsRes = await _persistPrepositions(allPrepositions);

          final List<GizrahDto> allGizrahs = await _fetchGizrahsFromApi();
          final SyncResult syncGizrahsRes = await _persistGizrahs(allGizrahs);

          final SyncResult syncRootRes = await _fetchPersistRoots();

          final SyncResult syncVerbsRes = await _fetchPersistVerbs();

          final SyncResult syncPrepositionLinks = await _fetchPersistPrepLinks();

          final SyncResult grandTotal = SyncResult.empty()
              .addResult(syncBinyansRes)
              .addResult(syncPrepsRes)
              .addResult(syncGizrahsRes)
              .addResult(syncRootRes)
              .addResult(syncVerbsRes)
              .addResult(syncPrepositionLinks);

          logger.i('Successfully completed sync: $grandTotal');
          return grandTotal;
        } catch (e, stackTrace) {
          logger.e('Error in fetchAndUpsertFromApi', error: e, stackTrace: stackTrace);
          rethrow;
        }
      }();
      logger.i('fetchAndInsertFromApi: completed successfully - $result');

      state = state.copyWith(
        isLoading: false,
        inserted: result.inserted,
        updated: result.updated,
        skipped: result.skipped,
      );
    } catch (e, stackTrace) {
      logger.e('fetchAndInsertFromApi: error', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    } finally {
      stopwatch.stop();
      logger.i('fetchAndInsertFromApi: took ${stopwatch.elapsedMilliseconds}ms');
    }
  }
  
  Future<SyncResult> _fetchPersistVerbs() async {
    SyncResult syncVerbRes = SyncResult.empty();

    int verbQueryPage = 0;
    int verbBatchNum = 1;
    while (true) {
      logger.d('Fetching batch $verbBatchNum (rootQueryPage=$verbQueryPage, size=${AppConfig.batchSize})');
      final List<VerbSyncDto> apiBatch = await _fetchVerbsFromApi(verbQueryPage, AppConfig.batchSize);

      if (apiBatch.isEmpty) {
        logger.i('Backend returned empty batch, stopping fetch loop');
        break;
      }

      logger.i('Batch $verbBatchNum: received ${apiBatch.length} items from backend');

      final SyncResult verbRes = await _persistVerbs(apiBatch, verbBatchNum);
      final SyncResult t9nRes = await _persistVerbTranslations(apiBatch, verbBatchNum);

      syncVerbRes = syncVerbRes
          .addResult(verbRes)
          .addResult(t9nRes);
      
      verbQueryPage++;
      verbBatchNum++;

      // If we received less than batch size, we've reached the end
      if (apiBatch.length < AppConfig.batchSize) {
        logger.i('Received incomplete batch (${apiBatch.length} < ${AppConfig.batchSize}), stopping fetch loop');
        break;
      }

    }
    return syncVerbRes;
  }

  Future<SyncResult> _persistVerbTranslations(List<VerbSyncDto> apiBatch, int verbBatchNum) async {
    final Map<int, List<VerbTranslationDto>> translationsWithParentIds = {
      for (final dto in apiBatch) dto.id: dto.translations,
    };

    logger.i("Upserting translations for ${translationsWithParentIds.length} verbs");
    final SyncResult res = await _verbTranslationRepository.upsertForBatch(translationsWithParentIds);
    logger.i("Upserting translations for verbs finished: inserted=${res.inserted}, updated=${res.updated}, "
        "skipped=${res.skipped}");
    return res;
  }

  Future<SyncResult> _persistVerbs(List<VerbSyncDto> apiBatch, int batchNumber) async {
    if (apiBatch.isEmpty) {
      logger.i('Backend returned empty batch, stopping fetch loop');
      return SyncResult.empty();
    }

    final res = await _verbRepository.upsertVerbs(apiBatch);
    logger.i(
      'Upserting verbs finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
    );
    return res;
  }

  Future<SyncResult> _fetchPersistRoots() async {
    SyncResult syncRootRes = SyncResult.empty();

    int rootQueryPage = 0;
    int rootBatchNum = 1;
    while (true) {
      logger.d('Fetching batch $rootBatchNum (rootQueryPage=$rootQueryPage, size=${AppConfig.batchSize})');
      final List<RootDto> apiBatch = await _fetchRootsFromApi(rootQueryPage, AppConfig.batchSize);
      final SyncResult result = await _persistRoots(apiBatch, rootBatchNum);
      syncRootRes = syncRootRes.addResult(result);

      rootQueryPage++;
      rootBatchNum++;

      if (apiBatch.length < AppConfig.batchSize) {
        logger.i('Received incomplete batch (${apiBatch.length} < ${AppConfig.batchSize}), stopping fetch loop');
        break;
      }
    }
    return syncRootRes;
  }
  
  Future<SyncResult> _fetchPersistPrepLinks() async {
    SyncResult res = SyncResult.empty();
    int page = 0;
    int batch = 1;
    bool droppedLinks = false;
    
    while (true) {
      logger.d('Fetching batch #$batch of verb-preposition links (page=$page, size=${AppConfig.batchSize})');
      final List<VerbPrepositionLinkDto> apiBatch = await _fetchPrepLinksFromApi(page, AppConfig.batchSize);

      if(!droppedLinks) {
        _verbPrepRepository.dropAllLinks();
        logger.i("Dropped all verb/preposition links");
      }
      
      final SyncResult batchResult = await _persistPrepLinks(apiBatch, batch);
      res = res.addResult(batchResult);

      page++;
      batch++;

      if (apiBatch.length < AppConfig.batchSize) {
        logger.i('Received incomplete batch (${apiBatch.length} < ${AppConfig.batchSize}), stopping fetch loop');
        break;
      }
    }
    return res;
  }

  Future<SyncResult> _persistRoots(List<RootDto> apiBatch, int batchNumber) async {
    if (apiBatch.isEmpty) {
      logger.i('Backend returned empty batch, stopping fetch loop');
      return SyncResult.empty();
    }

    final res = await _rootRepository.upsertRoots(apiBatch);
    logger.i(
      'Upserting roots finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
    );
    return res;
  }

  Future<SyncResult> _persistGizrahs(List<GizrahDto> allGizrahs) async {
    if (allGizrahs.isEmpty) {
      logger.i("Backend returned empty gizrah list");
      return SyncResult.empty();
    } else {
      final res = await _gizrahRepository.upsertGizrah(allGizrahs);
      logger.i(
        'Upserting binyans finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
      );
      return res;
    }
  }

  Future<SyncResult> _persistPrepositions(List<PrepositionDto> allPrepositions) async {
    if (allPrepositions.isEmpty) {
      logger.i("Backend returned empty preposition list");
      return SyncResult.empty();
    } else {
      final res = await _prepositionRepository.upsertPrepositions(allPrepositions);
      logger.i(
        'Upserting prepositions finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
      );
      return res;
    }
  }

  Future<SyncResult> _persistPrepLinks(List<VerbPrepositionLinkDto> apiBatch, int batch) async {
    if (apiBatch.isEmpty) {
      logger.i('Backend returned empty batch, stopping fetch loop');
      return SyncResult.empty();
    }

    // final res = await _verbPrepRepository.upsertLinks(apiBatch);
    final res = await _verbPrepRepository.insertBatch(apiBatch);
    logger.i(
      'Upserting verb/prep links finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
    );
    return res;
  }

  Future<SyncResult> _persistBinyans(List<BinyanDto> allBinyans) async {
    if (allBinyans.isEmpty) {
      logger.i("Backend returned empty binyan list");
      return SyncResult.empty();
    } else {
      final res = await _binyanRepository.upsertBinyans(allBinyans);
      logger.i(
        'Upserting binyans finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
      );
      return res;
    }
  }

  /// Fetch roots from backend API with pagination
  Future<List<RootDto>> _fetchRootsFromApi(int page, int size) async {
    try {
      final url = '${AppConfig.backendUrl}${AppConfig.rootsEndpoint}?page=$page&size=$size';
      logger.d('Fetching roots from backend: $url');
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final responseBody = response.data as Map<String, dynamic>;

        final List<dynamic> data = responseBody['content'] is List ? responseBody['content'] as List<dynamic> : [];

        logger.i('Fetched ${data.length} roots from backend (page=$page, size=$size)');
        return data.map((item) => RootDto.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch: status code ${response.statusCode}');
    } catch (e, stackTrace) {
      logger.e('Error fetching roots from backend', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<BinyanDto>> _fetchBinyansFromApi() async {
    try {
      final url = '${AppConfig.backendUrl}${AppConfig.binyanEndpoint}';
      logger.d('Fetching all binyans from $url');
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((item) => BinyanDto.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch binyans: status code ${response.statusCode}');
    } catch (e, stackTrace) {
      logger.e('Error fetching binyans from backend', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<PrepositionDto>> _fetchPrepositionsFromApi() async {
    try {
      final url = '${AppConfig.backendUrl}${AppConfig.prepEndpoint}';
      logger.d('Fetching all prepositions from $url');
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((item) => PrepositionDto.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch prepositions: status code ${response.statusCode}');
    } catch (e, stackTrace) {
      logger.e('Error fetching prepositions from backend', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<GizrahDto>> _fetchGizrahsFromApi() async {
    try {
      final url = '${AppConfig.backendUrl}${AppConfig.gizrahEndpoint}';
      logger.d('Fetching all gizrah from $url');
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((item) => GizrahDto.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch gizrah: status code ${response.statusCode}');
    } catch (e, stackTrace) {
      logger.e('Error fetching gizrah from backend', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<VerbSyncDto>> _fetchVerbsFromApi(int page, int size) async {
    try {
      final url = '${AppConfig.backendUrl}${AppConfig.verbEndpoint}?page=$page&size=$size';
      logger.d('Fetching verbs from $url');
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        // final List<dynamic> data = response.data as List<dynamic>;
        final responseBody = response.data as Map<String, dynamic>;
        final List<dynamic> data = responseBody['content'] is List ? responseBody['content'] as List<dynamic> : [];
        logger.i('Fetched ${data.length} verbs from backend (page=$page, size=$size)');

        return data.map((item) => VerbSyncDto.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch verbs: status code ${response.statusCode}');
    } catch (e, stackTrace) {
      logger.e('Error fetching verbs from backend', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<VerbPrepositionLinkDto>> _fetchPrepLinksFromApi(int page, int batchSize) async {
    try {
      final url = '${AppConfig.backendUrl}${AppConfig.prepLinkEndpoint}?page=$page&size=$batchSize';
      logger.d('Fetching all prepositions links from $url');
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        List<dynamic> values = data['content'] is List ? data['content'] as List<dynamic> : [];
        return values.map((item) => VerbPrepositionLinkDto.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch prepositions: status code ${response.statusCode}');
    } catch (e, stackTrace) {
      logger.e('Error fetching prepositions from backend', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
