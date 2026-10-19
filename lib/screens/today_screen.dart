import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../reminders.dart';
import '../store.dart';
import '../util.dart';
import 'forms.dart';
import 'pet_detail.dart';
import 'pet_form.dart';
import 'widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool? _notifOk;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    final ok = await Reminders.instance.notificationsEnabled();
    if (mounted) setState(() => _notifOk = ok);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = dateOnly(now);

    if (store.pets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Today')),
        body: EmptyState(
          icon: Icons.pets,
          title: 'Add your first pet',
          message:
              'Pawly reminds you about medicines, vaccines and care so you never miss a thing.',
          action: FilledButton.icon(
            onPressed: () => openPetForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add a pet'),
          ),
        ),
      );
    }

    final items = store.todayItems();
    final overdue = items.where((i) => i.overdue).toList();
    final todayList = items
        .where((i) => !i.overdue && dateOnly(i.when) == today)
        .toList();
    final upcoming =
        items.where((i) => !i.overdue && dateOnly(i.when).isAfter(today)).toList();
    final left = items
        .where((i) => !i.done && !dateOnly(i.when).isAfter(today))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Reminders.instance.rescheduleAll(store);
          await _checkNotifications();
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtDate(now),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    left == 0
                        ? 'All caught up for today'
                        : left == 1
                            ? '1 thing to do today'
                            : '$left things to do today',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            if (_notifOk == false) _NotificationBanner(onFixed: _checkNotifications),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nothing due this week',
                  message:
                      'Add a medicine, vaccine or care task and it will show up here.',
                  action: OutlinedButton.icon(
                    onPressed: () => openPetDetail(context, store.pets.first),
                    icon: const Icon(Icons.add),
                    label: Text('Add for ${store.pets.first.name}'),
                  ),
                ),
              ),
            if (overdue.isNotEmpty) ...[
              const SectionTitle('Overdue'),
              for (final i in overdue) _TodayTile(item: i),
            ],
            if (todayList.isNotEmpty) ...[
              const SectionTitle('Today'),
              for (final i in todayList) _TodayTile(item: i),
            ],
            if (upcoming.isNotEmpty) ...[
              const SectionTitle('Next 7 days'),
              for (final i in upcoming) _TodayTile(item: i),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.onFixed});
  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.notifications_off, color: scheme.onErrorContainer),
        title: Text('Reminders are turned off',
            style: TextStyle(color: scheme.onErrorContainer)),
        subtitle: Text('Allow notifications so Pawly can remind you.',
            style: TextStyle(color: scheme.onErrorContainer)),
        trailing: TextButton(
          onPressed: () async {
            final ok = await Reminders.instance.requestPermission();
            if (!ok) await Reminders.instance.openNotificationSettings();
            onFixed();
          },
          child: const Text('Turn on'),
        ),
      ),
    );
  }
}

class _TodayTile extends StatelessWidget {
  const _TodayTile({required this.item});
  final TodayItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = StoreScope.read(context);
    final icon = switch (item.kind) {
      TodayKind.medication => Icons.medication_outlined,
      TodayKind.vaccine => Icons.vaccines_outlined,
      TodayKind.care => Icons.event_repeat,
    };
    final whenText = item.kind == TodayKind.medication
        ? fmtTime(item.when)
        : relativeDay(item.when);

    Widget trailing = const SizedBox.shrink();
    switch (item.kind) {
      case TodayKind.medication:
        trailing = IconButton.filledTonal(
          tooltip: item.done ? 'Mark not given' : 'Mark as given',
          isSelected: item.done,
          icon: const Icon(Icons.radio_button_unchecked),
          selectedIcon: const Icon(Icons.check_circle),
          onPressed: () => store.toggleDose(item.medication!, item.when),
        );
      case TodayKind.vaccine:
        trailing = TextButton(
          onPressed: () =>
              openVaccineForm(context, item.pet, renewOf: item.vaccine),
          child: const Text('Done'),
        );
      case TodayKind.care:
        trailing = TextButton(
          onPressed: () {
            final previous = item.care!.nextDate;
            store.completeCare(item.care!);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(
                    '${item.title} done. Next: ${fmtDate(item.care!.nextDate)}'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    item.care!.nextDate = previous;
                    store.changed();
                  },
                ),
              ));
          },
          child: const Text('Done'),
        );
    }

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          PetAvatar(pet: item.pet, radius: 22),
          Positioned(
            right: -4,
            bottom: -4,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: theme.colorScheme.surface,
              child: Icon(icon, size: 15, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      title: Text(
        item.title,
        style: item.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(
        '$whenText · ${item.subtitle}',
        style: item.overdue ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      trailing: trailing,
      onTap: () => openPetDetail(context, item.pet),
    );
  }
}
