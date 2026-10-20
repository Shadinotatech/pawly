import 'package:flutter/material.dart';

import '../main.dart';
import '../reminders.dart';
import 'add_sheet.dart';
import 'expenses_screen.dart';
import 'home_screen.dart';
import 'pets_screen.dart';
import 'settings_screen.dart';

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
    // When the app comes back to the foreground, refresh Today, reminders and
    // the Pro subscription state.
    _lifecycle = AppLifecycleListener(onResume: () {
      if (!mounted) return;
      Reminders.instance.rescheduleAll(StoreScope.read(context));
      ProScope.read(context).refreshOwnership();
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
      HomeScreen(onOpenPets: () => setState(() => _index = 1)),
      const PetsScreen(),
      const SizedBox.shrink(),
      const ExpensesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTap,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.pets), label: 'Pets'),
          NavigationDestination(
            icon: Container(
              width: 46,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
            ),
            label: 'Add',
          ),
          const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Spending'),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
