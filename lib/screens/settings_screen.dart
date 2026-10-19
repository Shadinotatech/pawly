import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../reminders.dart';
import '../util.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notif;
  bool? _exact;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final n = await Reminders.instance.notificationsEnabled();
    final e = await Reminders.instance.canScheduleExact();
    if (mounted) {
      setState(() {
        _notif = n;
        _exact = e;
      });
    }
  }

  Future<void> _export() async {
    final store = StoreScope.read(context);
    final text = const JsonEncoder.withIndent(' ').convert(store.toJson());
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Backup copied'),
        content: const Text(
            'Your data was copied as text. Paste it into an email to yourself or a notes app and keep it safe. Photos are not included.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore backup'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
              hintText: 'Paste the backup text here'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: const Text('Restore')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      final data = jsonDecode(text.trim()) as Map<String, dynamic>;
      if (!data.containsKey('pets')) throw const FormatException();
      final ok = await confirm(context, 'Replace all data?',
          'Everything in the app now will be replaced by the backup.',
          ok: 'Replace');
      if (!ok || !mounted) return;
      final store = StoreScope.read(context);
      store.importJson(data);
      store.settings.onboardingDone = true;
      store.changed();
      toast(context, 'Backup restored.');
    } catch (_) {
      if (mounted) toast(context, 'That text is not a valid Pawly backup.');
    }
  }

  Future<void> _deleteAll() async {
    final ok = await confirm(context, 'Delete all data?',
        'All pets, records and reminders will be deleted from this phone. This cannot be undone.');
    if (!ok || !mounted) return;
    await StoreScope.read(context).deleteAllData();
    if (mounted) toast(context, 'All data deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionTitle('Reminders'),
          ListTile(
            leading: Icon(_notif == false
                ? Icons.notifications_off
                : Icons.notifications_active),
            title: const Text('Notifications'),
            subtitle: Text(_notif == null
                ? 'Checking...'
                : _notif!
                    ? 'On'
                    : 'Off. Tap to turn on.'),
            onTap: () async {
              final ok = await Reminders.instance.requestPermission();
              if (!ok) await Reminders.instance.openNotificationSettings();
              await _refresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('On-time reminders'),
            subtitle: Text(_exact == null
                ? 'Checking...'
                : _exact!
                    ? 'Allowed. Reminders arrive at the exact time.'
                    : 'Not allowed. Reminders may be a few minutes late. Tap to allow.'),
            onTap: () async {
              await Reminders.instance.requestExactAlarms();
              await _refresh();
              if (mounted) {
                await Reminders.instance.rescheduleAll(StoreScope.read(context));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Time for vaccine & care reminders'),
            subtitle: Text(fmtMinutes(s.defaultReminderMinutes)),
            onTap: () async {
              final m = await pickMinutes(context, s.defaultReminderMinutes);
              if (m == null) return;
              s.defaultReminderMinutes = m;
              store.changed();
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Send a test notification'),
            onTap: () async {
              await Reminders.instance.requestPermission();
              await Reminders.instance.showTest();
            },
          ),
          const ListTile(
            leading: Icon(Icons.battery_alert_outlined),
            title: Text('Not getting reminders?'),
            subtitle: Text(
                'Some phones stop apps in the background. Open phone Settings > Apps > Pawly > Battery and choose "Unrestricted" or "Don\'t optimize".'),
            isThreeLine: true,
          ),
          const SectionTitle('Units'),
          SwitchListTile(
            secondary: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Show weight in pounds (lb)'),
            subtitle: Text(s.useLb ? 'Pounds' : 'Kilograms'),
            value: s.useLb,
            onChanged: (v) {
              s.useLb = v;
              store.changed();
            },
          ),
          const SectionTitle('Your data'),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Copy backup'),
            subtitle: const Text('Copies all your records as text'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore backup'),
            subtitle: const Text('Paste a backup you copied before'),
            onTap: _import,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Delete all data'),
            onTap: _deleteAll,
          ),
          const SectionTitle('About'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Privacy'),
            subtitle: Text(
                'Pawly has no account and no ads. Your data is stored only on this phone and is never sent to us.'),
            isThreeLine: true,
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Not veterinary advice'),
            subtitle: Text(
                'Pawly is a tracker and reminder tool. Always follow your vet\'s advice.'),
            isThreeLine: true,
          ),
          const ListTile(
            leading: Icon(Icons.pets),
            title: Text('Pawly'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}
