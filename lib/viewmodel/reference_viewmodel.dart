import 'package:almi3/core/logger.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/model/repository/root_repository.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReferencePageState {
  final List<RootDto> roots;
  final bool isLoading;
  final bool hasMore;
  final String? errMsg;

  const ReferencePageState({this.roots = const [], this.isLoading = false, this.hasMore = true, this.errMsg});

  ReferencePageState copyWith({List<RootDto>? roots, bool? isLoading, bool? hasMore, String? errMsg}) {
    return ReferencePageState(
      roots: roots ?? this.roots,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}

class ReferencePageNotifier extends Notifier<ReferencePageState> {
  late final RootRepository _repository;
  int _page = 0;
  static const int _size = 20;

  @override
  ReferencePageState build() {
    _repository = ref.watch(rootRepositoryProvider);
    Future.microtask(() => _loadInit());
    return const ReferencePageState();
  }

  Future<void> _loadInit() async {
    try {
      state = state.copyWith(isLoading: true, errMsg: null);
      logger.d('calling getRootsPaged with page=$_page, size=$_size');
      final rootsPaged = await _repository.getRootsPaged(_page, _size);
      logger.i('received ${rootsPaged.length} items');
      state = state.copyWith(
        roots: rootsPaged,
        isLoading: false,
        hasMore: rootsPaged.length == _size,
      );
      logger.d('state updated: ${state.roots.length} roots, hasMore=${state.hasMore}');
    } catch (e, stackTrace) {
      logger.e('_loadInit() error', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) {
      logger.d('loadMore: skipped (isLoading=${state.isLoading}, hasMore=${state.hasMore})');
      return;
    }
    state = state.copyWith(isLoading: true);
    _page++;
    logger.d('loadMore: loading page=$_page');
    try {
      final roots = await _repository.getRootsPaged(_page, _size);
      logger.i('loadMore: loaded ${roots.length} more items');
      state = state.copyWith(
        roots: [...state.roots, ...roots],
        isLoading: false,
        hasMore: roots.length == _size,
      );
    } catch (e, stackTrace) {
      _page--;
      logger.e('loadMore: error', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }

  Future<void> refresh() async {
    logger.d('refresh: resetting to page 0');
    _page = 0;
    await _loadInit();
  }
}

final NotifierProvider<ReferencePageNotifier, ReferencePageState> referencePageProvider =
    NotifierProvider<ReferencePageNotifier, ReferencePageState>(ReferencePageNotifier.new);
