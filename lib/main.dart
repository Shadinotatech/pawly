import 'package:flutter/material.dart';

import 'reminders.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  await Reminders.instance.init();
  store.addListener(() => Reminders.instance.scheduleSoon(store));
  runApp(PawlyApp(store: store));
  Reminders.instance.rescheduleAll(store);
}

/// Gives every screen access to the [AppStore] and rebuilds when it changes.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// Use in build methods: the widget rebuilds when data changes.
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Use in callbacks (onPressed etc).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

const brandGreen = Color(0xFF1F7A6B);
const brandOrange = Color(0xFFF2994A);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandGreen,
    brightness: brightness,
  ).copyWith(tertiary: brandOrange);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

class PawlyApp extends StatelessWidget {
  const PawlyApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Pawly',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return store.settings.onboardingDone
        ? const HomeShell()
        : const OnboardingScreen();
  }
}
