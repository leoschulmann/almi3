import 'package:almi3/model/dto/verb_detail_dto.dart';

class VerbPageState {
  final VerbDetailDto? verb;
  final bool isLoading;
  final String? errMsg;
  final Set<int> bookmarkedFormIds;
  // Health % (0..100+) from HealthService.lexemeHealthWithBonus, or null if
  // the word hasn't been started / its lexeme has no cards yet.
  final double? health;

  const VerbPageState({
    this.verb,
    this.isLoading = false,
    this.errMsg,
    this.bookmarkedFormIds = const {},
    this.health,
  });

  bool isFormBookmarked(int formId) => bookmarkedFormIds.contains(formId);

  VerbPageState copyWith({
    VerbDetailDto? verb,
    bool? isLoading,
    String? errMsg,
    Set<int>? bookmarkedFormIds,
    double? health,
  }) {
    return VerbPageState(
      verb: verb ?? this.verb,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errMsg ?? this.errMsg,
      bookmarkedFormIds: bookmarkedFormIds ?? this.bookmarkedFormIds,
      health: health ?? this.health,
    );
  }
}
