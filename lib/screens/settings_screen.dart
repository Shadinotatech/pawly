import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../reminders.dart';
import '../theme.dart';
import '../util.dart';
import 'pro_screen.dart';
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
            'All your records were copied as text. Paste them into an email to yourself or a notes app. Photos are not included.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
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
          decoration: const InputDecoration(hintText: 'Paste the backup text here'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Restore')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      final data = jsonDecode(text.trim()) as Map<String, dynamic>;
      if (!data.containsKey('pets')) throw const FormatException();
      final ok = await confirm(context, 'Replace all data?',
          'Everything in the app now will be replaced by the backup.', ok: 'Replace');
      if (!ok || !mounted) return;
      final store = StoreScope.read(context);
      final keep = store.settings;
      store.importJson(data, notify: false);
      // Purchase state always comes from Google Play, never from a backup.
      store.settings
        ..onboardingDone = true
        ..proOwned = keep.proOwned
        ..proTestUnlocked = keep.proTestUnlocked;
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

  Future<void> _pickCurrency() async {
    final store = StoreScope.read(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final cur in currencies)
              ChoiceChip(
                label: Text(cur, style: const TextStyle(fontSize: 16)),
                selected: store.settings.currency == cur,
                onSelected: (_) => Navigator.pop(c, cur),
              ),
          ]),
        ),
      ),
    );
    if (picked == null) return;
    store.settings.currency = picked;
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);

    Widget group(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 56),
                children[i],
              ],
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Panel(
              onTap: () => openPro(context),
              color: Brand.marigold.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.2),
              child: Row(children: [
                const Icon(Icons.workspace_premium, color: Brand.marigold, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(store.isPro ? 'Pawly Pro is active' : 'Upgrade to Pawly Pro',
                        style: theme.textTheme.titleMedium),
                    Text(
                        store.isPro
                            ? (s.proTestUnlocked && !s.proOwned ? 'Unlocked for testing' : 'Thank you for your support')
                            : 'Unlimited pets, PDF reports, spending insights',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
          const SectionTitle('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Theme', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Auto')),
                      ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                      ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) {
                      s.themeMode = v.first;
                      store.changed();
                    },
                  ),
                ),
              ]),
            ),
          ),
          const SectionTitle('Reminders'),
          group([
            ListTile(
              leading: Icon(_notif == false ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                  color: _notif == false ? c.overdue : null),
              title: const Text('Notifications'),
              subtitle: Text(_notif == null ? 'Checking...' : _notif! ? 'On' : 'Off. Tap to turn on.'),
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
                      ? 'Allowed. Alerts arrive at the exact minute.'
                      : 'Not allowed. Alerts may be a few minutes late. Tap to allow.'),
              onTap: () async {
                await Reminders.instance.requestExactAlarms();
                await _refresh();
                if (context.mounted) await Reminders.instance.rescheduleAll(StoreScope.read(context));
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Vaccine & care reminder time'),
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
                  'Some phones stop apps in the background. Open phone Settings > Apps > Pawly > Battery and choose "Unrestricted".'),
              isThreeLine: true,
            ),
          ]),
          const SectionTitle('Units'),
          group([
            SwitchListTile(
              secondary: const Icon(Icons.monitor_weight_outlined),
              title: const Text('Weight in pounds (lb)'),
              subtitle: Text(s.useLb ? 'Pounds' : 'Kilograms'),
              value: s.useLb,
              onChanged: (v) {
                s.useLb = v;
                store.changed();
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Currency'),
              trailing: Text(s.currency, style: theme.textTheme.titleMedium),
              onTap: _pickCurrency,
            ),
          ]),
          const SectionTitle('Your data'),
          group([
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copy backup'),
              subtitle: const Text('Copies all records as text'),
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore backup'),
              subtitle: const Text('Paste a backup you copied before'),
              onTap: _import,
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: c.overdue),
              title: Text('Delete all data', style: TextStyle(color: c.overdue)),
              onTap: _deleteAll,
            ),
          ]),
          const SectionTitle('About'),
          group(const [
            ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Private by design'),
              subtitle: Text('No account and no ads. Your records stay on this phone.'),
            ),
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Not veterinary advice'),
              subtitle: Text('Pawly is a tracker. Always follow your vet\'s advice.'),
            ),
            ListTile(
              leading: Icon(Icons.pets),
              title: Text('Pawly'),
              subtitle: Text('Version 1.1.0'),
            ),
          ]),
        ],
      ),
    );
  }
}
