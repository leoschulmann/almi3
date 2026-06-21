import 'package:almi3/model/dto/verb_detail_dto.dart';

class VerbScreenState {
  final VerbDetailDto? verb;
  final bool isLoading;
  final String? errMsg;
  final Set<int> bookmarkedFormIds;

  const VerbScreenState({
    this.verb,
    this.isLoading = false,
    this.errMsg,
    this.bookmarkedFormIds = const {},
  });

  bool isFormBookmarked(int formId) => bookmarkedFormIds.contains(formId);

  VerbScreenState copyWith({VerbDetailDto? verb, bool? isLoading, String? errMsg, Set<int>? bookmarkedFormIds}) {
    return VerbScreenState(
      verb: verb ?? this.verb,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errMsg ?? this.errMsg,
      bookmarkedFormIds: bookmarkedFormIds ?? this.bookmarkedFormIds,
    );
  }
}
