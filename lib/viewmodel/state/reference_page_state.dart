import '../../model/dto/root_dto.dart';

class ReferencePageState {
  final List<RootDto> roots;
  final bool isLoading;
  final bool hasMore;
  final String? errMsg;
  final Set<int> bookmarkedRootIds;
  final Map<int, int> verbCounts;

  const ReferencePageState({this.roots = const [], this.isLoading = false, this.hasMore = true, this.errMsg,
    this.bookmarkedRootIds = const {}, this.verbCounts = const {},
  });

  ReferencePageState copyWith({List<RootDto>? roots, bool? isLoading, bool? hasMore, String? errMsg,
    Set<int>? bookmarkedRootIds, Map<int, int>? verbCounts}) {
    return ReferencePageState(
      roots: roots ?? this.roots,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errMsg: errMsg ?? this.errMsg,
      bookmarkedRootIds: bookmarkedRootIds ?? this.bookmarkedRootIds,
      verbCounts: verbCounts ?? this.verbCounts,
    );
  }

  bool isBookmarked(int rootId) => bookmarkedRootIds.contains(rootId);
  int verbCount(int rootId) => verbCounts[rootId] ?? 0;
}
