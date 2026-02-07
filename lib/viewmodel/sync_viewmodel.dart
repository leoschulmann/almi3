import 'package:almi3/core/logger.dart';
import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/binyan_dto.dart';
import 'package:almi3/model/dto/gizrah_dto.dart';
import 'package:almi3/model/dto/prep_dto.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/dto/verb_dto.dart';
import 'package:almi3/model/repository/binyan_repository.dart';
import 'package:almi3/model/repository/prep_repo.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/model/repository/verb_t9n_repository.dart';
import 'package:almi3/viewmodel/state/sync_page_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../model/dto/verb_t9n_dto.dart';
import '../model/repository/gizrah_repo.dart';
import '../model/sync_result.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider((ref) => AppDatabase());

final Provider<RootRepository> rootRepositoryProvider = Provider(
  (ref) => RootRepository(ref.watch(appDatabaseProvider)),
);

Provider<BinyanRepository> binyanRepositoryProvider = Provider(
  (ref) => BinyanRepository(database: ref.watch(appDatabaseProvider)),
);

Provider<PrepositionRepository> prepositionRepositoryProvider = Provider(
  (ref) => PrepositionRepository(database: ref.watch(appDatabaseProvider)),
);

Provider<GizrahRepository> gizrahRepositoryProvider = Provider(
  (ref) => GizrahRepository(database: ref.watch(appDatabaseProvider)),
);

Provider<VerbRepository> verbRepositoryProvider = Provider((ref) => VerbRepository(ref.watch(appDatabaseProvider)));

Provider<VerbTranslationRepository> verbTranslationRepositoryProvider = Provider(
  (ref) => VerbTranslationRepository(ref.watch(appDatabaseProvider)),
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
  final Dio _dio = Dio();

  @override
  SyncViewmodelState build() {
    _rootRepository = ref.watch(rootRepositoryProvider);
    _binyanRepository = ref.watch(binyanRepositoryProvider);
    _prepositionRepository = ref.watch(prepositionRepositoryProvider);
    _gizrahRepository = ref.watch(gizrahRepositoryProvider);
    _verbRepository = ref.watch(verbRepositoryProvider);
    _verbTranslationRepository = ref.watch(verbTranslationRepositoryProvider);

    return const SyncViewmodelState();
  }

  Future<void> fetchAndInsertFromApi() async {
    try {
      logger.i('fetchAndInsertFromApi: starting');
      state = state.copyWith(isLoading: true, errorMessage: null);

      final SyncResult result = await () async {
        try {
          logger.i('Starting batched fetch and upsert from backend');
          int page = 0;
          int totalInserted = 0;
          int totalUpdated = 0;
          int totalSkipped = 0;
          int batchNumber = 1;

          List<BinyanDto> allBinyans = await _fetchBinyansFromApi();
          if (allBinyans.isEmpty) {
            logger.i("Backend returned empty binyan list");
          } else {
            SyncResult res = await _binyanRepository.upsertBinyans(allBinyans);
            logger.i(
              'Upserting binyans finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
            );
            totalInserted += res.inserted;
            totalUpdated += res.updated;
            totalSkipped += res.skipped;
          }

          List<PrepositionDto> allPrepositions = await _fetchPrepositionsFromApi();
          if (allPrepositions.isEmpty) {
            logger.i("Backend returned empty preposition list");
          } else {
            SyncResult res = await _prepositionRepository.upsertPrepositions(allPrepositions);
            logger.i(
              'Upserting prepositions finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
            );
            totalInserted += res.inserted;
            totalUpdated += res.updated;
            totalSkipped += res.skipped;
          }

          List<GizrahDto> allGizrahs = await _fetchGizrahsFromApi();
          if (allGizrahs.isEmpty) {
            logger.i("Backend returned empty gizrah list");
          } else {
            SyncResult res = await _gizrahRepository.upsertGizrah(allGizrahs);
            logger.i(
              'Upserting binyans finished inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}',
            );
            totalInserted += res.inserted;
            totalUpdated += res.updated;
            totalSkipped += res.skipped;
          }

          while (true) {
            logger.d('Fetching batch $batchNumber (page=$page, size=${AppConfig.batchSize})');
            final apiBatch = await _fetchRootsFromApi(page, AppConfig.batchSize);

            if (apiBatch.isEmpty) {
              logger.i('Backend returned empty batch, stopping fetch loop');
              break;
            }

            logger.i('Batch $batchNumber: received ${apiBatch.length} items from backend');

            // Upsert this batch immediately and collect results
            final SyncResult result = await _rootRepository.upsertRoots(apiBatch);
            totalInserted += result.inserted;
            totalUpdated += result.updated;
            totalSkipped += result.skipped;

            // Move to next page
            page++;
            batchNumber++;

            // If we received less than batch size, we've reached the end
            if (apiBatch.length < AppConfig.batchSize) {
              logger.i('Received incomplete batch (${apiBatch.length} < ${AppConfig.batchSize}), stopping fetch loop');
              break;
            }
          }

          page = 0;

          while (true) {
            logger.d('Fetching batch $batchNumber (page=$page, size=${AppConfig.batchSize})');
            final List<VerbSyncDto> apiBatch = await _fetchVerbsFromApi(page, AppConfig.batchSize);

            if (apiBatch.isEmpty) {
              logger.i('Backend returned empty batch, stopping fetch loop');
              break;
            }

            logger.i('Batch $batchNumber: received ${apiBatch.length} items from backend');

            final SyncResult result = await _verbRepository.upsertVerbs(apiBatch);

            Map<int, List<VerbTranslationDto>> translationsWithParentIds = {
              for (var dto in apiBatch) dto.id: dto.translations,
            };

            final SyncResult t9nRes = await _verbTranslationRepository.upsertForBatch(translationsWithParentIds);

            totalInserted += result.inserted;
            totalInserted += t9nRes.inserted;
            totalUpdated += result.updated;
            totalUpdated += t9nRes.updated;
            totalSkipped += result.skipped;
            totalSkipped += t9nRes.skipped;

            // Move to next page
            page++;
            batchNumber++;

            // If we received less than batch size, we've reached the end
            if (apiBatch.length < AppConfig.batchSize) {
              logger.i('Received incomplete batch (${apiBatch.length} < ${AppConfig.batchSize}), stopping fetch loop');
              break;
            }
          }

          final syncResult = SyncResult(inserted: totalInserted, updated: totalUpdated, skipped: totalSkipped);
          logger.i('Successfully completed sync: $syncResult');
          return syncResult;
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
}
