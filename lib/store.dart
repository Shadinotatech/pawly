import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

enum TodayKind { medication, vaccine, care }

/// One row on the Today screen.
class TodayItem {
  final TodayKind kind;
  final Pet pet;
  final DateTime when;
  final String title;
  final String subtitle;
  final bool done;
  final Medication? medication;
  final Vaccine? vaccine;
  final CareTask? care;

  TodayItem({
    required this.kind,
    required this.pet,
    required this.when,
    required this.title,
    required this.subtitle,
    this.done = false,
    this.medication,
    this.vaccine,
    this.care,
  });

  bool get overdue =>
      !done &&
      (kind == TodayKind.medication
          ? when.isBefore(DateTime.now())
          : dateOnly(when).isBefore(dateOnly(DateTime.now())));
}

/// Holds all app data in memory and saves it to a JSON file on the phone.
class AppStore extends ChangeNotifier {
  AppStore._(this._file);

  final File _file;
  final List<Pet> pets = [];
  final List<Vaccine> vaccines = [];
  final List<Medication> medications = [];
  final List<MedLog> medLogs = [];
  final List<CareTask> careTasks = [];
  final List<WeightEntry> weights = [];
  final List<VetVisit> visits = [];
  AppSettings settings = AppSettings();

  late String photoDir;
  Future<void> _saving = Future.value();

  static Future<AppStore> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = AppStore._(File('${dir.path}/pawly_data.json'));
    store.photoDir = '${dir.path}/photos';
    await Directory(store.photoDir).create(recursive: true);
    if (await store._file.exists()) {
      try {
        final text = await store._file.readAsString();
        store.importJson(jsonDecode(text) as Map<String, dynamic>,
            notify: false);
      } catch (e) {
        debugPrint('Could not read data file: $e');
        // Keep a copy of the broken file so data is not silently lost.
        try {
          await store._file.copy('${store._file.path}.broken');
        } catch (_) {}
      }
    }
    return store;
  }

  // ---------- persistence ----------

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        'pets': pets.map((e) => e.toJson()).toList(),
        'vaccines': vaccines.map((e) => e.toJson()).toList(),
        'medications': medications.map((e) => e.toJson()).toList(),
        'medLogs': medLogs.map((e) => e.toJson()).toList(),
        'careTasks': careTasks.map((e) => e.toJson()).toList(),
        'weights': weights.map((e) => e.toJson()).toList(),
        'visits': visits.map((e) => e.toJson()).toList(),
      };

  void importJson(Map<String, dynamic> j, {bool notify = true}) {
    List<Map<String, dynamic>> list(String key) =>
        ((j[key] as List?) ?? []).cast<Map<String, dynamic>>();
    settings = AppSettings.fromJson(
        (j['settings'] as Map<String, dynamic>?) ?? const {});
    pets
      ..clear()
      ..addAll(list('pets').map(Pet.fromJson));
    vaccines
      ..clear()
      ..addAll(list('vaccines').map(Vaccine.fromJson));
    medications
      ..clear()
      ..addAll(list('medications').map(Medication.fromJson));
    medLogs
      ..clear()
      ..addAll(list('medLogs').map(MedLog.fromJson));
    careTasks
      ..clear()
      ..addAll(list('careTasks').map(CareTask.fromJson));
    weights
      ..clear()
      ..addAll(list('weights').map(WeightEntry.fromJson));
    visits
      ..clear()
      ..addAll(list('visits').map(VetVisit.fromJson));
    if (notify) changed();
  }

  /// Call after any change: saves to disk and refreshes the UI.
  void changed() {
    _pruneOldLogs();
    final text = jsonEncode(toJson());
    _saving = _saving.then((_) async {
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(_file.path);
    }).catchError((Object e) {
      debugPrint('Save failed: $e');
    });
    notifyListeners();
  }

  void _pruneOldLogs() {
    final cutoff = DateTime.now().subtract(const Duration(days: 120));
    medLogs.removeWhere((l) => l.scheduledAt.isBefore(cutoff));
  }

  // ---------- lookups ----------

  Pet? petById(String id) {
    for (final p in pets) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Vaccine> vaccinesFor(String petId) =>
      vaccines.where((v) => v.petId == petId).toList()
        ..sort((a, b) => b.givenDate.compareTo(a.givenDate));

  List<Medication> medsFor(String petId) =>
      medications.where((m) => m.petId == petId).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  List<CareTask> careFor(String petId) =>
      careTasks.where((c) => c.petId == petId).toList()
        ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

  List<WeightEntry> weightsFor(String petId) =>
      weights.where((w) => w.petId == petId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<VetVisit> visitsFor(String petId) =>
      visits.where((v) => v.petId == petId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// The latest dose of each vaccine that has a next due date.
  List<Vaccine> dueVaccines({String? petId}) {
    final latest = <String, Vaccine>{};
    for (final v in vaccines) {
      if (petId != null && v.petId != petId) continue;
      final key = '${v.petId}|${v.name.trim().toLowerCase()}';
      final cur = latest[key];
      if (cur == null || v.givenDate.isAfter(cur.givenDate)) latest[key] = v;
    }
    return latest.values.where((v) => v.nextDueDate != null).toList()
      ..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
  }

  bool isDoseGiven(String medicationId, DateTime scheduledAt) =>
      medLogs.any((l) =>
          l.medicationId == medicationId &&
          l.scheduledAt.isAtSameMomentAs(scheduledAt));

  /// Things to do today plus vaccines and care due in the next 7 days.
  List<TodayItem> todayItems() {
    final now = DateTime.now();
    final today = dateOnly(now);
    final horizon = today.add(const Duration(days: 7));
    final items = <TodayItem>[];

    for (final m in medications) {
      final pet = petById(m.petId);
      if (pet == null || !m.isActiveOn(today)) continue;
      for (final minutes in m.reminderMinutes) {
        final at = today.add(Duration(minutes: minutes));
        items.add(TodayItem(
          kind: TodayKind.medication,
          pet: pet,
          when: at,
          title: m.name,
          subtitle: m.dose.isEmpty ? pet.name : '${pet.name} · ${m.dose}',
          done: isDoseGiven(m.id, at),
          medication: m,
        ));
      }
    }

    for (final v in dueVaccines()) {
      final pet = petById(v.petId);
      if (pet == null) continue;
      if (dateOnly(v.nextDueDate!).isAfter(horizon)) continue;
      items.add(TodayItem(
        kind: TodayKind.vaccine,
        pet: pet,
        when: v.nextDueDate!,
        title: '${v.name} vaccine',
        subtitle: pet.name,
        vaccine: v,
      ));
    }

    for (final c in careTasks) {
      final pet = petById(c.petId);
      if (pet == null) continue;
      if (dateOnly(c.nextDate).isAfter(horizon)) continue;
      items.add(TodayItem(
        kind: TodayKind.care,
        pet: pet,
        when: c.nextDate,
        title: c.displayName,
        subtitle: pet.name,
        care: c,
      ));
    }

    items.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.when.compareTo(b.when);
    });
    return items;
  }

  // ---------- changes ----------

  void upsertPet(Pet p) {
    final i = pets.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      pets[i] = p;
    } else {
      pets.add(p);
    }
    changed();
  }

  Future<void> deletePet(String petId) async {
    final pet = petById(petId);
    if (pet?.photoPath != null) {
      try {
        await File(pet!.photoPath!).delete();
      } catch (_) {}
    }
    pets.removeWhere((p) => p.id == petId);
    vaccines.removeWhere((e) => e.petId == petId);
    final medIds =
        medications.where((m) => m.petId == petId).map((m) => m.id).toSet();
    medications.removeWhere((e) => e.petId == petId);
    medLogs.removeWhere((l) => medIds.contains(l.medicationId));
    careTasks.removeWhere((e) => e.petId == petId);
    weights.removeWhere((e) => e.petId == petId);
    visits.removeWhere((e) => e.petId == petId);
    changed();
  }

  void _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final i = list.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
    changed();
  }

  void upsertVaccine(Vaccine v) => _upsert(vaccines, v, (e) => e.id);
  void deleteVaccine(String id) {
    vaccines.removeWhere((e) => e.id == id);
    changed();
  }

  void upsertMedication(Medication m) => _upsert(medications, m, (e) => e.id);
  void deleteMedication(String id) {
    medications.removeWhere((e) => e.id == id);
    medLogs.removeWhere((l) => l.medicationId == id);
    changed();
  }

  void toggleDose(Medication m, DateTime scheduledAt) {
    final existing = medLogs.where((l) =>
        l.medicationId == m.id && l.scheduledAt.isAtSameMomentAs(scheduledAt));
    if (existing.isNotEmpty) {
      medLogs.removeWhere((l) =>
          l.medicationId == m.id && l.scheduledAt.isAtSameMomentAs(scheduledAt));
    } else {
      medLogs.add(MedLog(
          id: newId(),
          medicationId: m.id,
          scheduledAt: scheduledAt,
          givenAt: DateTime.now()));
    }
    changed();
  }

  void upsertCare(CareTask c) => _upsert(careTasks, c, (e) => e.id);
  void deleteCare(String id) {
    careTasks.removeWhere((e) => e.id == id);
    changed();
  }

  /// Marks a care task done today and moves it to the next date.
  void completeCare(CareTask c) {
    c.nextDate =
        dateOnly(DateTime.now()).add(Duration(days: c.repeatEveryDays));
    changed();
  }

  void upsertWeight(WeightEntry w) => _upsert(weights, w, (e) => e.id);
  void deleteWeight(String id) {
    weights.removeWhere((e) => e.id == id);
    changed();
  }

  void upsertVisit(VetVisit v) => _upsert(visits, v, (e) => e.id);
  void deleteVisit(String id) {
    visits.removeWhere((e) => e.id == id);
    changed();
  }

  Future<void> deleteAllData() async {
    for (final p in pets) {
      if (p.photoPath != null) {
        try {
          await File(p.photoPath!).delete();
        } catch (_) {}
      }
    }
    final keepOnboarding = settings.onboardingDone;
    importJson(const {}, notify: false);
    settings.onboardingDone = keepOnboarding;
    changed();
  }
}
