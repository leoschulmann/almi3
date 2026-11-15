import '../../model/dto/root_card_stats.dart';
import '../../model/dto/root_dto.dart';

class RootListPageState {
  final List<RootDto> roots;
  final bool isLoading;
  final bool hasMore;
  final String? errMsg;
  final Set<int> bookmarkedRootIds;
  final Set<int> toReviewRootIds;
  final Map<int, RootCardStats> rootStats;

  const RootListPageState({this.roots = const [], this.isLoading = false, this.hasMore = true, this.errMsg,
    this.bookmarkedRootIds = const {}, this.toReviewRootIds = const {},
    this.rootStats = const {},
  });

  RootListPageState copyWith({List<RootDto>? roots, bool? isLoading, bool? hasMore, String? errMsg,
    Set<int>? bookmarkedRootIds, Set<int>? toReviewRootIds,
    Map<int, RootCardStats>? rootStats}) {
    return RootListPageState(
      roots: roots ?? this.roots,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errMsg: errMsg ?? this.errMsg,
      bookmarkedRootIds: bookmarkedRootIds ?? this.bookmarkedRootIds,
      toReviewRootIds: toReviewRootIds ?? this.toReviewRootIds,
      rootStats: rootStats ?? this.rootStats,
    );
  }

  bool isBookmarked(int rootId) => bookmarkedRootIds.contains(rootId);
  bool isToReview(int rootId) => toReviewRootIds.contains(rootId);
}
