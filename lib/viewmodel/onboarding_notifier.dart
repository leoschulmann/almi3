import 'package:almi3/core/enums.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory onboarding selection. Nothing here is persisted until
/// [OnboardingNotifier.confirm] runs -- no eager persistence.
class OnboardingState {
  final Set<int> selectedDeckIds;
  final ReviewIntensity intensity;
  final bool isSubmitting;
  final String? error;

  const OnboardingState({
    required this.selectedDeckIds,
    required this.intensity,
    this.isSubmitting = false,
    this.error,
  });

  bool get canConfirm => selectedDeckIds.isNotEmpty && !isSubmitting;

  OnboardingState copyWith({
    Set<int>? selectedDeckIds,
    ReviewIntensity? intensity,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      selectedDeckIds: selectedDeckIds ?? this.selectedDeckIds,
      intensity: intensity ?? this.intensity,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // Pre-checked default deck (the single hardcoded debug deck -- §9.1
    // decides against a computed/semantic deck model in this story).
    return const OnboardingState(
      selectedDeckIds: {kDefaultDeckId},
      intensity: ReviewIntensity.normal,
    );
  }

  void toggleDeck(int deckId, bool selected) {
    final next = Set<int>.from(state.selectedDeckIds);
    if (selected) {
      next.add(deckId);
    } else {
      next.remove(deckId);
    }
    state = state.copyWith(selectedDeckIds: next, clearError: true);
  }

  void setIntensity(ReviewIntensity v) {
    state = state.copyWith(intensity: v, clearError: true);
  }

  /// Writes fsrs_params snapshot + activeDeckIds/reviewIntensity first,
  /// onboardingComplete=true last -- the pref is the commit marker, so a
  /// mid-confirm crash never strands it true without data (see spec I/O
  /// matrix: "Confirm write fails"). Re-enables confirm on failure; every
  /// step here is idempotent, so a retry after partial failure is safe
  /// regardless of exactly how far the previous attempt got.
  Future<void> confirm() async {
    if (!state.canConfirm) return;

    state = state.copyWith(isSubmitting: true, clearError: true);
    final settings = ref.read(settingsProvider.notifier);

    try {
      // Also snapshots fsrs_params via FsrsParamsRepository.snapshotIfChanged
      // -- the shared helper backing both onboarding and later Settings
      // changes (§4.1).
      await settings.setReviewIntensity(state.intensity);
      settings.setActiveDeckIds(state.selectedDeckIds.toList());
      settings.setOnboardingComplete(true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return;
    }

    state = state.copyWith(isSubmitting: false);
  }
}
