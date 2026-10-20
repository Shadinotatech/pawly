import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'pro.dart';
import 'reminders.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final pro = ProService(store);
  await Reminders.instance.init();
  store.addListener(() => Reminders.instance.scheduleSoon(store));
  runApp(PawlyApp(store: store, pro: pro));
  Reminders.instance.rescheduleAll(store);
  pro.init();
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

class ProScope extends InheritedNotifier<ProService> {
  const ProScope({super.key, required ProService pro, required super.child})
      : super(notifier: pro);

  static ProService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProScope>()!.notifier!;

  static ProService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProScope>()!.notifier!;
}

class PawlyApp extends StatelessWidget {
  const PawlyApp({super.key, required this.store, required this.pro});
  final AppStore store;
  final ProService pro;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ProScope(
        pro: pro,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final mode = switch (store.settings.themeMode) {
              AppThemeMode.system => ThemeMode.system,
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
            };
            return MaterialApp(
              title: 'Pawly',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              themeMode: mode,
              builder: (context, child) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                  child: child!,
                );
              },
              home: store.settings.onboardingDone
                  ? const HomeShell()
                  : const OnboardingScreen(),
            );
          },
        ),
      ),
    );
  }
}
