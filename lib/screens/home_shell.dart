import 'package:flutter/material.dart';

import '../main.dart';
import '../reminders.dart';
import 'add_sheet.dart';
import 'pets_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // When the app comes back to the foreground, refresh Today and reminders
    // (the date may have changed while it was in the background).
    _lifecycle = AppLifecycleListener(onResume: () {
      if (!mounted) return;
      final store = StoreScope.read(context);
      Reminders.instance.rescheduleAll(store);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (i == 2) {
      showAddSheet(context);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayScreen(),
      const PetsScreen(),
      const SizedBox.shrink(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.pets),
              selectedIcon: Icon(Icons.pets),
              label: 'Pets'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Add'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
