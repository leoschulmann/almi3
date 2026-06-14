import 'package:almi3/core/logger.dart';
import 'package:almi3/model/repository/verb_repository.dart';
import 'package:almi3/viewmodel/state/verb_screen_state.dart';
import 'package:almi3/viewmodel/sync_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final verbScreenProvider =
    NotifierProvider.family<VerbScreenNotifier, VerbScreenState, int>((verbId) => VerbScreenNotifier(verbId));

class VerbScreenNotifier extends Notifier<VerbScreenState> {
  VerbScreenNotifier(this._verbId);

  final int _verbId;
  late VerbRepository _verbRepo;

  static const String _lang = 'EN';

  @override
  VerbScreenState build() {
    _verbRepo = ref.watch(verbRepositoryProvider);
    Future.microtask(_load);
    return const VerbScreenState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final detail = await _verbRepo.getVerbDetail(_verbId, _lang);
      state = state.copyWith(verb: detail, isLoading: false);
    } catch (e, st) {
      logger.e('VerbScreenNotifier._load error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errMsg: e.toString());
    }
  }
}
