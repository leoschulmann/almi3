import 'package:almi3/model/db/db.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncViewmodelState {
  final int counter;
  final bool isLoading;
  final String? errMsg;
  final List<RootDto> items;

  const SyncViewmodelState({this.counter = 0, this.isLoading = false, this.errMsg, this.items = const []});

  SyncViewmodelState copyWith({int? counter, bool? isLoading, String? errorMessage, List<RootDto>? items}) {
    return SyncViewmodelState(
      counter: counter ?? this.counter,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errorMessage ?? errMsg,
      items: items ?? this.items,
    );
  }
}

final Provider<AppDatabase> appDatabaseProvider = Provider((ref) => AppDatabase());

final Provider<RootRepository> rootRepositoryProvider = Provider(
  (ref) => RootRepository(ref.watch(appDatabaseProvider), Dio()),
);

class SyncViewmodelNotifier extends Notifier<SyncViewmodelState> {
  late final RootRepository _repository;

  @override
  SyncViewmodelState build() {
    _repository = ref.watch(rootRepositoryProvider);
    return const SyncViewmodelState();
  }

  Future<void> fetchAndInsertFromApi() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final roots = await _repository.getRootsFromApi();

      for (final root in roots) {
        await _repository.insertRoot(root);
      }

      state = state.copyWith(counter: state.counter + roots.length, isLoading: false, items: roots);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final rootViewmodelProvider = NotifierProvider<SyncViewmodelNotifier, SyncViewmodelState>(SyncViewmodelNotifier.new);
