import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';
import 'util.dart';

/// Schedules local notifications for medicines, vaccines and care tasks.
///
/// Strategy: whenever data changes (and when the app opens) we cancel all
/// pending notifications and schedule one-shot notifications for the next
/// [_daysAhead] days. One-shot times are converted to UTC, so daylight saving
/// changes are handled correctly without needing a time zone database.
class Reminders {
  Reminders._();
  static final Reminders instance = Reminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;

  static const _daysAhead = 21;
  static const _maxScheduled = 400; // Android allows ~500 alarms per app.

  static const _channel = AndroidNotificationDetails(
    'pawly_reminders',
    'Pet care reminders',
    channelDescription: 'Medicine, vaccine and care reminders for your pets',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_paw',
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_paw'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for notification permission (Android 13+). Returns true if allowed.
  Future<bool> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> notificationsEnabled() async =>
      (await _android?.areNotificationsEnabled()) ?? true;

  Future<bool> canScheduleExact() async =>
      (await _android?.canScheduleExactNotifications()) ?? true;

  /// Opens the system screen where the user can allow exact alarms.
  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
  }

  Future<void> openNotificationSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (e) {
      debugPrint('Could not open settings: $e');
    }
  }

  Future<void> showTest() async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: 999999,
      title: 'Pawly reminders are working',
      body: 'You will get alerts like this for medicines and vaccines.',
      notificationDetails: const NotificationDetails(android: _channel),
    );
  }

  /// Call after any data change. Waits a moment so many quick edits only
  /// trigger one reschedule.
  void scheduleSoon(AppStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      rescheduleAll(store);
    });
  }

  Future<void> rescheduleAll(AppStore store) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      final entries = _buildEntries(store);
      final exact = await canScheduleExact();
      final mode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      var id = 1;
      for (final e in entries.take(_maxScheduled)) {
        await _plugin.zonedSchedule(
          id: id++,
          title: e.title,
          body: e.body,
          scheduledDate: tz.TZDateTime.from(e.at.toUtc(), tz.UTC),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: mode,
        );
      }
    } catch (e) {
      debugPrint('Reschedule failed: $e');
    }
  }

  List<_Entry> _buildEntries(AppStore store) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final out = <_Entry>[];
    final remindAt = store.settings.defaultReminderMinutes;

    // Medicines: every dose for the next few weeks.
    for (final m in store.medications) {
      final pet = store.petById(m.petId);
      if (pet == null) continue;
      for (var d = 0; d < _daysAhead; d++) {
        final day = today.add(Duration(days: d));
        if (!m.isActiveOn(day)) continue;
        for (final minutes in m.reminderMinutes) {
          final at = day.add(Duration(minutes: minutes));
          if (!at.isAfter(now)) continue;
          if (store.isDoseGiven(m.id, at)) continue;
          out.add(_Entry(
            at,
            'Time for ${pet.name}\'s ${m.name}',
            m.dose.isEmpty
                ? 'Tap to open Pawly and mark it as given.'
                : 'Dose: ${m.dose}. Tap to mark it as given.',
          ));
        }
      }
    }

    // Vaccines: 3 days before and on the due date.
    for (final v in store.dueVaccines()) {
      final pet = store.petById(v.petId);
      if (pet == null) continue;
      final due = dateOnly(v.nextDueDate!);
      final early = due.subtract(const Duration(days: 3));
      final earlyAt = early.add(Duration(minutes: remindAt));
      final dueAt = due.add(Duration(minutes: remindAt));
      if (earlyAt.isAfter(now)) {
        out.add(_Entry(earlyAt, '${pet.name}\'s ${v.name} vaccine is due soon',
            'Due on ${fmtDate(due)}. Book a vet visit if needed.'));
      }
      if (dueAt.isAfter(now)) {
        out.add(_Entry(dueAt, '${pet.name}\'s ${v.name} vaccine is due today',
            'Mark it done in Pawly after the visit.'));
      }
    }

    // Care tasks: on the next date.
    for (final c in store.careTasks) {
      final pet = store.petById(c.petId);
      if (pet == null) continue;
      final at = dateOnly(c.nextDate).add(Duration(minutes: remindAt));
      if (at.isAfter(now)) {
        out.add(_Entry(at, '${c.displayName} for ${pet.name}',
            'Due today. Mark it done in Pawly.'));
      }
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

class _Entry {
  final DateTime at;
  final String title;
  final String body;
  _Entry(this.at, this.title, this.body);
}
