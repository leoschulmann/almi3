import '../../model/dto/root_dto.dart';

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
