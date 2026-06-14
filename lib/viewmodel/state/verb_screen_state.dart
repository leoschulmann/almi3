import 'package:almi3/model/dto/verb_detail_dto.dart';

class VerbScreenState {
  final VerbDetailDto? verb;
  final bool isLoading;
  final String? errMsg;

  const VerbScreenState({
    this.verb,
    this.isLoading = false,
    this.errMsg,
  });

  VerbScreenState copyWith({VerbDetailDto? verb, bool? isLoading, String? errMsg}) {
    return VerbScreenState(
      verb: verb ?? this.verb,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}
