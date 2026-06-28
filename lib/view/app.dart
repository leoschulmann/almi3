import 'dart:ui';
import 'package:almi3/core/app_colors.dart';
import 'package:almi3/view/root_list_page.dart';
import 'package:almi3/view/widgets/browse_popup_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learn_page.dart';
import 'quiz_page.dart';
import 'sync_page.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'almi yaha',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const MainNavigation(),
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

  // One navigator key per tab so each tab keeps its own back-stack.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Used to position the Browse popup above the correct nav item.
  final GlobalKey _browseNavKey = GlobalKey();

  final List<Widget> _roots = const [
    RootListPage(),
    LearnPage(),
    QuizPage(),
    SyncPage(),
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
      onSelect: (page) {
        setState(() => _selectedIndex = 0);
        _navigatorKeys[0].currentState?.push(
          MaterialPageRoute(builder: (_) => page),
        );
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
                onGenerateRoute: (_) => MaterialPageRoute(
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
    (icon: Icons.school, label: 'Learn'),
    (icon: Icons.quiz, label: 'Quiz'),
    (icon: Icons.sync, label: 'Sync'),
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
