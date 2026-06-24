import 'package:almi3/model/dto/example_display_dto.dart';

class ExamplePageState {
  final List<VerbFormExampleGroupDto> groups;
  final bool isLoading;
  final String? errMsg;

  const ExamplePageState({
    this.groups = const [],
    this.isLoading = false,
    this.errMsg,
  });

  ExamplePageState copyWith({
    List<VerbFormExampleGroupDto>? groups,
    bool? isLoading,
    String? errMsg,
  }) {
    return ExamplePageState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}
