import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:almi3/view/onboarding_page.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:almi3/view/root_list_page.dart';
import 'package:almi3/view/widgets/browse_popup_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_page.dart';
import 'quiz_page.dart';

/// Resolves whether onboarding is complete, deriving true for installs that
/// update without reinstalling: onboardingComplete unset in prefs but an
/// fsrs_params row already exists (an earlier first-run insert happened
/// before this pref existed). Purely derives the bool from state it watches
/// -- it never writes to settingsProvider itself (which it also watches),
/// so it can't trigger an extra rebuild of its own. Never touches
/// schedulerProvider -- only the repository -- so onboarding's own
/// first-run insert (via confirm()) can't race it. The migration re-checks
/// getLatest() on every cold start until onboarding's own confirm() (or the
/// user finishing onboarding) persists onboardingComplete in prefs.
final onboardingGateProvider = FutureProvider<bool>((ref) async {
  final alreadyComplete = ref.watch(settingsProvider.select((s) => s.onboardingComplete));
  if (alreadyComplete) return true;

  final latest = await ref.watch(fsrsParamsRepositoryProvider).getLatest();
  return latest != null;
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(settingsProvider.select((s) => s.theme));
    final themeMode = switch (appTheme) {
      AppTheme.light => ThemeMode.light,
      AppTheme.dark  => ThemeMode.dark,
      AppTheme.auto  => ThemeMode.system,
    };

    final onboardingGate = ref.watch(onboardingGateProvider);

    return MaterialApp(
      title: 'almi yaha',
      themeMode: themeMode,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.tekhelet)),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.tekhelet, brightness: Brightness.dark)),
      home: CupertinoTheme(
        data: const CupertinoThemeData(primaryColor: AppColors.tekhelet),
        child: onboardingGate.when(
          data: (complete) => complete ? const MainNavigation() : const OnboardingPage(),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) {
            debugPrint('onboardingGateProvider failed: $error\n$stackTrace');
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Something went wrong loading your data.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(onboardingGateProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  BrowseMode _browseMode = BrowseMode.allRoots;

  // One navigator key per tab so each tab keeps its own back-stack.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Used to position the Browse popup above the correct nav item.
  final GlobalKey _browseNavKey = GlobalKey();

  final List<Widget> _roots = const [
    RootListPage(),
    HomePage(),
    QuizPage(),
  ];

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_selectedIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  void _onBrowseLongPress() {
    HapticFeedback.mediumImpact();
    showBrowsePopupMenu(
      context: context,
      anchorKey: _browseNavKey,
      currentMode: _browseMode,
      onSelect: (page, mode) {
        setState(() {
          _selectedIndex = 0;
          _browseMode = mode;
        });
        if (page == null) {
          // All roots — pop back to root list
          _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
        } else {
          _navigatorKeys[0].currentState?.push(
            adaptivePageRoute(builder: (_) => page),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: List.generate(_roots.length, (i) {
            return Offstage(
              offstage: _selectedIndex != i,
              child: Navigator(
                key: _navigatorKeys[i],
                onGenerateRoute: (_) => adaptivePageRoute(
                  builder: (_) => _roots[i],
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: _CustomBottomNav(
          selectedIndex: _selectedIndex,
          browseNavKey: _browseNavKey,
          onTap: (idx) {
            // Tapping Browse always resets it to RootListPage.
            if (idx == 0) {
              _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
              setState(() => _browseMode = BrowseMode.allRoots);
            }
            setState(() => _selectedIndex = idx);
          },
          onBrowseLongPress: _onBrowseLongPress,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom bottom nav — identical visuals to BottomNavigationBarType.fixed but
// exposes per-item long press for the Browse item.
// ---------------------------------------------------------------------------

class _CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final GlobalKey browseNavKey;
  final ValueChanged<int> onTap;
  final VoidCallback onBrowseLongPress;

  const _CustomBottomNav({
    required this.selectedIndex,
    required this.browseNavKey,
    required this.onTap,
    required this.onBrowseLongPress,
  });

  static const _items = [
    (icon: Icons.book, label: 'Browse'),
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.quiz, label: 'Quiz'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const selectedColor = AppColors.tekhelet;
    const unselectedColor = AppColors.inkSecondary;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.navBarBackground,
            border: Border(top: BorderSide(color: AppColors.hairline, width: 0.5)),
          ),
      child: SizedBox(
        height: kBottomNavigationBarHeight + bottomPadding,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isSelected = selectedIndex == i;
              final color = isSelected ? selectedColor : unselectedColor;
              final isBrowse = i == 0;

              return Expanded(
                child: GestureDetector(
                  key: isBrowse ? browseNavKey : null,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  onLongPress: isBrowse ? onBrowseLongPress : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: color),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
