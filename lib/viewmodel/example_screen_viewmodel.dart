import 'package:almi3/core/logger.dart';
import 'package:almi3/model/dto/example_display_dto.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/viewmodel/state/example_screen_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exampleScreenProvider =
    NotifierProvider.family<ExampleScreenNotifier, ExampleScreenState, int>(
        (verbId) => ExampleScreenNotifier(verbId));

class ExampleScreenNotifier extends Notifier<ExampleScreenState> {
  
  ExampleScreenNotifier(this._verbId);

  final int _verbId;
  late VerbRepository _verbRepo;

  static const String _lang = 'EN';

  @override
  ExampleScreenState build() {
    _verbRepo = ref.watch(verbRepositoryProvider);
    Future.microtask(_load);
    return const ExampleScreenState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final List<VerbFormExampleGroupDto> groups = await _verbRepo.getExamplesForVerb(_verbId, _lang);
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e, st) {
      logger.e('ExampleScreenNotifier._load error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }
}
