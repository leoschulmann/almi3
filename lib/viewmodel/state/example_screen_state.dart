import 'package:almi3/model/dto/example_display_dto.dart';

class ExampleScreenState {
  final List<VerbFormExampleGroupDto> groups;
  final bool isLoading;
  final String? errMsg;

  const ExampleScreenState({
    this.groups = const [],
    this.isLoading = false,
    this.errMsg,
  });

  ExampleScreenState copyWith({
    List<VerbFormExampleGroupDto>? groups,
    bool? isLoading,
    String? errMsg,
  }) {
    return ExampleScreenState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}
