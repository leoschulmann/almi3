import 'package:almi3/view/reference_page.dart';
import 'package:flutter/material.dart';
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

  final List<Widget> _roots = const [
    ReferencePage(),
    LearnPage(),
    QuizPage(),
    SyncPage(),
  ];

  // Pop within the active tab's navigator on Android back; exit app only when
  // the tab stack is at root.
  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_selectedIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
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
        body: Stack(
          children: List.generate(_roots.length, (i) {
            // Keep all tab navigators alive so state is preserved when switching.
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
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Reference'),
            BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn'),
            BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'Sync'),
          ],
          currentIndex: _selectedIndex,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
