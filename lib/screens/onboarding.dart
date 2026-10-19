import 'package:flutter/material.dart';

import '../main.dart';
import '../reminders.dart';
import 'pet_form.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    _page.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _finish() {
    final store = StoreScope.read(context);
    store.settings.onboardingDone = true;
    store.changed();
  }

  Future<void> _allowNotifications() async {
    await Reminders.instance.requestPermission();
    final exact = await Reminders.instance.canScheduleExact();
    if (!exact && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('On-time reminders'),
          content: const Text(
              'To get medicine reminders at the exact minute, allow "Alarms & reminders" for Pawly on the next screen. You can skip this; reminders may then arrive a few minutes late.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Skip')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Allow')),
          ],
        ),
      );
      if (go == true) await Reminders.instance.requestExactAlarms();
    }
    if (mounted) _next();
  }

  Future<void> _addPet() async {
    final pet = await openPetForm(context);
    if (pet != null && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      _Page(
        icon: Icons.pets,
        title: 'Welcome to Pawly',
        text:
            'One simple place for all your pets: vaccines, medicines, weight and vet visits.',
        button: FilledButton(onPressed: _next, child: const Text('Next')),
      ),
      _Page(
        icon: Icons.notifications_active,
        title: 'Never miss a dose',
        text:
            'Pawly reminds you on time for every medicine, vaccine and flea treatment. Your data stays on your phone.',
        button: FilledButton(
            onPressed: _allowNotifications,
            child: const Text('Allow reminders')),
        secondary: TextButton(onPressed: _next, child: const Text('Not now')),
      ),
      _Page(
        icon: Icons.favorite,
        title: 'Add your first pet',
        text: 'It takes less than a minute. You can add more pets any time.',
        button: FilledButton.icon(
            onPressed: _addPet,
            icon: const Icon(Icons.add),
            label: const Text('Add a pet')),
        secondary:
            TextButton(onPressed: _finish, child: const Text('Skip for now')),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    this.secondary,
  });
  final IconData icon;
  final String title;
  final String text;
  final Widget button;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 64,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text(title,
              style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(text,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: button),
          if (secondary != null) ...[const SizedBox(height: 8), secondary!],
        ],
      ),
    );
  }
}
