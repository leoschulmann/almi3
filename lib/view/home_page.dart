import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/view/practice_stub_page.dart';
import 'package:almi3/view/session_stub_page.dart';
import 'package:almi3/viewmodel/home_notifier.dart';
import 'package:almi3/viewmodel/progress_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home/dashboard screen (CAP-2): one primary "Учиться" button reading
/// "N к повторению · M новых" straight from the engine, a secondary
/// "Тренировка" door, and a progress-showcase widget (CAP-9) reading
/// [progressStatusProvider].
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(homeStatusProvider);

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
                'ALMI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 32),

              _StudyButton(
                statusText: statusAsync.when(
                  data: (status) => '${status.dueCount} к повторению · ${status.newCount} новых',
                  loading: () => '...',
                  error: (_, _) => '— к повторению · — новых',
                ),
                onTap: () {
                  Navigator.of(context)
                      .push(adaptivePageRoute(builder: (_) => const SessionStubPage()))
                      .then((_) {
                    if (context.mounted) ref.invalidate(progressStatusProvider);
                  });
                },
              ),

              const SizedBox(height: 16),
              _PracticeDoor(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context)
                      .push(adaptivePageRoute(builder: (_) => const PracticeStubPage()))
                      .then((_) {
                    if (context.mounted) ref.invalidate(progressStatusProvider);
                  });
                },
              ),

              const SizedBox(height: 24),
              const _ProgressShowcase(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary "Учиться" button -- reuses root_card.dart's scale-pulse tap
/// convention (AnimationController + TweenSequence, 1.06/300ms) since it's
/// a physical-size widget, plus mediumImpact haptic (see AGENTS.md).
class _StudyButton extends StatefulWidget {
  final String statusText;
  final VoidCallback onTap;

  const _StudyButton({required this.statusText, required this.onTap});

  @override
  State<_StudyButton> createState() => _StudyButtonState();
}

class _StudyButtonState extends State<_StudyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Учиться',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _pulseController.forward(from: 0);
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.tekhelet,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Учиться',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.statusText,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary "Тренировка" door -- haptic only, no scale pulse (lighter-weight
/// control per house convention, AGENTS.md).
class _PracticeDoor extends StatelessWidget {
  final VoidCallback onTap;

  const _PracticeDoor({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Тренировка',
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Тренировка',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.inkSecondary),
          ],
        ),
      ),
      ),
    );
  }
}

/// Standard Russian 1/2-4/5+ plural-form selection (e.g. n=1 -> [one],
/// n=2..4 -> [few], n=0/5+/11-14 -> [many]).
String _pluralizeRu(int n, {required String one, required String few, required String many}) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

/// Progress-showcase widget (CAP-9): a health-bucket breakdown ("N крепких
/// · M слабых", grammatically agreeing with N/M) over started lexemes,
/// sourced from [progressStatusProvider]. Never shows raw FSRS internals --
/// only the bucketed presentation.
class _ProgressShowcase extends ConsumerWidget {
  const _ProgressShowcase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressStatusProvider);

    final text = progressAsync.when(
      data: (status) {
        if (status.strongCount == 0 && status.weakCount == 0) {
          return 'Начните заниматься, чтобы увидеть прогресс';
        }
        final strongWord = _pluralizeRu(
          status.strongCount,
          one: 'крепкое',
          few: 'крепких',
          many: 'крепких',
        );
        final weakWord = _pluralizeRu(
          status.weakCount,
          one: 'слабое',
          few: 'слабых',
          many: 'слабых',
        );
        return '${status.strongCount} $strongWord · ${status.weakCount} $weakWord';
      },
      loading: () => '...',
      error: (_, _) => '—',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
        ),
      ),
    );
  }
}
