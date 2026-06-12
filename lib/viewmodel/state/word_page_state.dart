import 'package:almi3/model/dto/verb_word_dto.dart';

class WordPageState {
  final List<VerbWordDto> words;
  final Set<int> bookmarkedIds;
  final bool isLoading;
  final String? errMsg;

  const WordPageState({
    this.words = const [],
    this.bookmarkedIds = const {},
    this.isLoading = false,
    this.errMsg,
  });

  bool isBookmarked(int id) => bookmarkedIds.contains(id);

  WordPageState copyWith({List<VerbWordDto>? words, Set<int>? bookmarkedIds, bool? isLoading, String? errMsg}) {
    return WordPageState(
      words: words ?? this.words,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}
