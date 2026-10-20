// Data models for Pawly. Everything is stored locally as JSON.

import 'dart:math';

final _rand = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
String? _iso(DateTime? d) => d?.toIso8601String();

/// Keeps only year/month/day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

enum Species { dog, cat, other }

Species speciesFrom(String? s) =>
    Species.values.firstWhere((e) => e.name == s, orElse: () => Species.other);

class Pet {
  final String id;
  String name;
  Species species;
  String breed;
  DateTime? birthDate;
  String sex; // 'male', 'female' or ''
  String? photoPath;
  String microchip;
  String notes;
  int colorIndex;
  DateTime? adoptionDate;

  Pet({
    required this.id,
    required this.name,
    this.species = Species.dog,
    this.breed = '',
    this.birthDate,
    this.sex = '',
    this.photoPath,
    this.microchip = '',
    this.notes = '',
    this.colorIndex = 0,
    this.adoptionDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'colorIndex': colorIndex,
        'adoptionDate': _iso(adoptionDate),
        'name': name,
        'species': species.name,
        'breed': breed,
        'birthDate': _iso(birthDate),
        'sex': sex,
        'photoPath': photoPath,
        'microchip': microchip,
        'notes': notes,
      };

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        species: speciesFrom(j['species'] as String?),
        breed: (j['breed'] ?? '') as String,
        birthDate: _date(j['birthDate']),
        sex: (j['sex'] ?? '') as String,
        photoPath: j['photoPath'] as String?,
        microchip: (j['microchip'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        colorIndex: ((j['colorIndex'] ?? 0) as num).toInt(),
        adoptionDate: _date(j['adoptionDate']),
      );
}

/// One vaccine dose that was given, with an optional next due date.
class Vaccine {
  final String id;
  final String petId;
  String name;
  DateTime givenDate;
  DateTime? nextDueDate;
  String vetName;
  String note;

  Vaccine({
    required this.id,
    required this.petId,
    required this.name,
    required this.givenDate,
    this.nextDueDate,
    this.vetName = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'name': name,
        'givenDate': _iso(givenDate),
        'nextDueDate': _iso(nextDueDate),
        'vetName': vetName,
        'note': note,
      };

  factory Vaccine.fromJson(Map<String, dynamic> j) => Vaccine(
        id: j['id'] as String,
        petId: j['petId'] as String,
        name: (j['name'] ?? '') as String,
        givenDate: _date(j['givenDate']) ?? DateTime.now(),
        nextDueDate: _date(j['nextDueDate']),
        vetName: (j['vetName'] ?? '') as String,
        note: (j['note'] ?? '') as String,
      );
}

/// A time of day stored as minutes after midnight.
class DayTime {
  final int minutes;
  const DayTime(this.minutes);
  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;
}

class Medication {
  final String id;
  final String petId;
  String name;
  String dose;
  DateTime startDate;
  DateTime? endDate; // null = ongoing
  List<int> reminderMinutes; // times of day, minutes after midnight
  String note;

  Medication({
    required this.id,
    required this.petId,
    required this.name,
    this.dose = '',
    required this.startDate,
    this.endDate,
    List<int>? reminderMinutes,
    this.note = '',
  }) : reminderMinutes = reminderMinutes ?? [9 * 60];

  bool isActiveOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(dateOnly(startDate))) return false;
    if (endDate != null && d.isAfter(dateOnly(endDate!))) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'name': name,
        'dose': dose,
        'startDate': _iso(startDate),
        'endDate': _iso(endDate),
        'reminderMinutes': reminderMinutes,
        'note': note,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        petId: j['petId'] as String,
        name: (j['name'] ?? '') as String,
        dose: (j['dose'] ?? '') as String,
        startDate: _date(j['startDate']) ?? DateTime.now(),
        endDate: _date(j['endDate']),
        reminderMinutes: ((j['reminderMinutes'] as List?) ?? [540])
            .map((e) => (e as num).toInt())
            .toList(),
        note: (j['note'] ?? '') as String,
      );
}

/// Records that a scheduled dose was given.
class MedLog {
  final String id;
  final String medicationId;
  final DateTime scheduledAt;
  final DateTime givenAt;

  MedLog({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.givenAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'scheduledAt': _iso(scheduledAt),
        'givenAt': _iso(givenAt),
      };

  factory MedLog.fromJson(Map<String, dynamic> j) => MedLog(
        id: j['id'] as String,
        medicationId: j['medicationId'] as String,
        scheduledAt: _date(j['scheduledAt']) ?? DateTime.now(),
        givenAt: _date(j['givenAt']) ?? DateTime.now(),
      );
}

enum CareType { flea, deworm, grooming, bath, nails, custom }

extension CareTypeLabel on CareType {
  String get label => switch (this) {
        CareType.flea => 'Flea & tick',
        CareType.deworm => 'Deworming',
        CareType.grooming => 'Grooming',
        CareType.bath => 'Bath',
        CareType.nails => 'Nail trim',
        CareType.custom => 'Other',
      };
}

/// A repeating care task such as monthly flea treatment.
class CareTask {
  final String id;
  final String petId;
  CareType type;
  String title;
  int repeatEveryDays;
  DateTime nextDate;

  CareTask({
    required this.id,
    required this.petId,
    required this.type,
    this.title = '',
    required this.repeatEveryDays,
    required this.nextDate,
  });

  String get displayName =>
      type == CareType.custom && title.trim().isNotEmpty ? title : type.label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'type': type.name,
        'title': title,
        'repeatEveryDays': repeatEveryDays,
        'nextDate': _iso(nextDate),
      };

  factory CareTask.fromJson(Map<String, dynamic> j) => CareTask(
        id: j['id'] as String,
        petId: j['petId'] as String,
        type: CareType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => CareType.custom),
        title: (j['title'] ?? '') as String,
        repeatEveryDays: ((j['repeatEveryDays'] ?? 30) as num).toInt(),
        nextDate: _date(j['nextDate']) ?? DateTime.now(),
      );
}

class WeightEntry {
  final String id;
  final String petId;
  DateTime date;
  double weightKg; // always stored in kg

  WeightEntry({
    required this.id,
    required this.petId,
    required this.date,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'date': _iso(date),
        'weightKg': weightKg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        id: j['id'] as String,
        petId: j['petId'] as String,
        date: _date(j['date']) ?? DateTime.now(),
        weightKg: ((j['weightKg'] ?? 0) as num).toDouble(),
      );
}

class VetVisit {
  final String id;
  final String petId;
  DateTime date;
  String reason;
  String vetName;
  double? cost;
  String note;

  VetVisit({
    required this.id,
    required this.petId,
    required this.date,
    this.reason = '',
    this.vetName = '',
    this.cost,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'date': _iso(date),
        'reason': reason,
        'vetName': vetName,
        'cost': cost,
        'note': note,
      };

  factory VetVisit.fromJson(Map<String, dynamic> j) => VetVisit(
        id: j['id'] as String,
        petId: j['petId'] as String,
        date: _date(j['date']) ?? DateTime.now(),
        reason: (j['reason'] ?? '') as String,
        vetName: (j['vetName'] ?? '') as String,
        cost: (j['cost'] as num?)?.toDouble(),
        note: (j['note'] ?? '') as String,
      );
}

enum ExpenseCategory { food, vet, medicine, grooming, insurance, toys, supplies, other }

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.food => 'Food & treats',
        ExpenseCategory.vet => 'Vet',
        ExpenseCategory.medicine => 'Medicine',
        ExpenseCategory.grooming => 'Grooming',
        ExpenseCategory.insurance => 'Insurance',
        ExpenseCategory.toys => 'Toys',
        ExpenseCategory.supplies => 'Supplies',
        ExpenseCategory.other => 'Other',
      };
}

class Expense {
  final String id;
  final String petId;
  DateTime date;
  ExpenseCategory category;
  double amount;
  String note;

  Expense({
    required this.id,
    required this.petId,
    required this.date,
    required this.category,
    required this.amount,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'date': _iso(date),
        'category': category.name,
        'amount': amount,
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        petId: j['petId'] as String,
        date: _date(j['date']) ?? DateTime.now(),
        category: ExpenseCategory.values.firstWhere(
            (e) => e.name == j['category'],
            orElse: () => ExpenseCategory.other),
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        note: (j['note'] ?? '') as String,
      );
}

enum AppThemeMode { system, light, dark }

class AppSettings {
  bool onboardingDone;
  bool useLb;
  int defaultReminderMinutes; // time for vaccine / care reminders
  AppThemeMode themeMode;
  String currency;
  bool proOwned; // cached Play purchase state
  bool proTestUnlocked; // test builds only

  AppSettings({
    this.onboardingDone = false,
    this.useLb = false,
    this.defaultReminderMinutes = 9 * 60,
    this.themeMode = AppThemeMode.system,
    this.currency = r'$',
    this.proOwned = false,
    this.proTestUnlocked = false,
  });

  Map<String, dynamic> toJson() => {
        'onboardingDone': onboardingDone,
        'useLb': useLb,
        'defaultReminderMinutes': defaultReminderMinutes,
        'themeMode': themeMode.name,
        'currency': currency,
        'proOwned': proOwned,
        'proTestUnlocked': proTestUnlocked,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        onboardingDone: (j['onboardingDone'] ?? false) as bool,
        useLb: (j['useLb'] ?? false) as bool,
        defaultReminderMinutes:
            ((j['defaultReminderMinutes'] ?? 540) as num).toInt(),
        themeMode: AppThemeMode.values.firstWhere(
            (e) => e.name == j['themeMode'],
            orElse: () => AppThemeMode.system),
        currency: (j['currency'] ?? r'$') as String,
        proOwned: (j['proOwned'] ?? false) as bool,
        proTestUnlocked: (j['proTestUnlocked'] ?? false) as bool,
      );
}
