import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/viewmodel/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// First-launch screen gating [MainNavigation]: pick >=1 deck and an
/// intensity, then confirm. No numeric desired_retention or the word
/// "retention" anywhere here -- qualitative labels only (see spec
/// Boundaries & Constraints).
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Welcome to ALMI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick how often you want to review.',
                style: TextStyle(fontSize: 15, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 32),

              const Text(
                'Decks',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 8),
              _DeckTile(
                title: 'All words',
                subtitle: 'The full ALMI vocabulary',
                selected: state.selectedDeckIds.contains(kDefaultDeckId),
                onChanged: (v) => notifier.toggleDeck(kDefaultDeckId, v),
              ),

              const SizedBox(height: 32),
              const Text(
                'Pace',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 8),
              AdaptiveSegmentedControl<ReviewIntensity>(
                segments: ReviewIntensity.values.map((v) => (v, intensityLabel(v))).toList(),
                selected: state.intensity,
                onChanged: notifier.setIntensity,
              ),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Something went wrong. Please try again.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFFF3B30)),
                ),
              ],

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tekhelet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: state.canConfirm
                      ? () {
                          HapticFeedback.mediumImpact();
                          notifier.confirm();
                        }
                      : null,
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Start learning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _DeckTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSecondary)),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                activeColor: AppColors.tekhelet,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
