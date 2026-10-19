import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../util.dart';
import 'widgets.dart';

Future<void> _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

Future<void> openVaccineForm(BuildContext context, Pet pet,
        {Vaccine? vaccine, Vaccine? renewOf}) =>
    _open(context, VaccineForm(pet: pet, vaccine: vaccine, renewOf: renewOf));

Future<void> openMedicationForm(BuildContext context, Pet pet,
        {Medication? medication}) =>
    _open(context, MedicationForm(pet: pet, medication: medication));

Future<void> openCareForm(BuildContext context, Pet pet, {CareTask? care}) =>
    _open(context, CareForm(pet: pet, care: care));

Future<void> openWeightForm(BuildContext context, Pet pet,
        {WeightEntry? entry}) =>
    _open(context, WeightForm(pet: pet, entry: entry));

Future<void> openVisitForm(BuildContext context, Pet pet, {VetVisit? visit}) =>
    _open(context, VisitForm(pet: pet, visit: visit));

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
double? _parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

// ---------------------------------------------------------------- Vaccine

class VaccineForm extends StatefulWidget {
  const VaccineForm({super.key, required this.pet, this.vaccine, this.renewOf});
  final Pet pet;
  final Vaccine? vaccine;

  /// When set, the form records a new dose of this vaccine given today.
  final Vaccine? renewOf;

  @override
  State<VaccineForm> createState() => _VaccineFormState();
}

class _VaccineFormState extends State<VaccineForm> {
  late final TextEditingController _name;
  late final TextEditingController _vet;
  late final TextEditingController _note;
  late DateTime _given;
  DateTime? _next;

  @override
  void initState() {
    super.initState();
    final v = widget.vaccine;
    final r = widget.renewOf;
    _name = TextEditingController(text: v?.name ?? r?.name ?? '');
    _vet = TextEditingController(text: v?.vetName ?? r?.vetName ?? '');
    _note = TextEditingController(text: v?.note ?? '');
    _given = v?.givenDate ?? dateOnly(DateTime.now());
    _next = v?.nextDueDate;
    if (v == null && r != null && r.nextDueDate != null) {
      // Keep the same interval as last time.
      final gap = r.nextDueDate!.difference(r.givenDate).inDays;
      if (gap > 0) _next = _given.add(Duration(days: gap));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _vet.dispose();
    _note.dispose();
    super.dispose();
  }

  List<String> get _suggestions => switch (widget.pet.species) {
        Species.dog => const [
            'Rabies', 'DHPP', 'Bordetella', 'Leptospirosis', 'Lyme',
            'Canine influenza',
          ],
        Species.cat => const ['Rabies', 'FVRCP', 'FeLV'],
        Species.other => const ['Rabies'],
      };

  void _setNext(int? days) {
    setState(() => _next = days == null ? null : _given.add(Duration(days: days)));
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Please enter the vaccine name.');
      return;
    }
    StoreScope.read(context).upsertVaccine(Vaccine(
      id: widget.vaccine?.id ?? newId(),
      petId: widget.pet.id,
      name: name,
      givenDate: _given,
      nextDueDate: _next,
      vetName: _vet.text.trim(),
      note: _note.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete vaccine?',
        'This record will be removed.')) {
      return;
    }
    if (!mounted) return;
    StoreScope.read(context).deleteVaccine(widget.vaccine!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.vaccine == null
          ? 'Vaccine for ${widget.pet.name}'
          : 'Edit vaccine',
      onSave: _save,
      onDelete: widget.vaccine == null ? null : _delete,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Vaccine name *'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s),
                onPressed: () => setState(() => _name.text = s),
              ),
          ],
        ),
        PickerField(
          label: 'Date given',
          value: fmtDate(_given),
          onTap: () async {
            final d = await pickDate(context, _given, last: DateTime.now());
            if (d != null) setState(() => _given = d);
          },
        ),
        PickerField(
          label: 'Next due date (reminder)',
          value: _next == null ? 'No reminder' : fmtDate(_next!),
          icon: Icons.notifications_active_outlined,
          onTap: () async {
            final d = await pickDate(
                context, _next ?? _given.add(const Duration(days: 365)),
                first: _given);
            if (d != null) setState(() => _next = d);
          },
          onClear: _next == null ? null : () => _setNext(null),
        ),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
                label: const Text('+3 weeks'), onPressed: () => _setNext(21)),
            ActionChip(
                label: const Text('+1 year'), onPressed: () => _setNext(365)),
            ActionChip(
                label: const Text('+3 years'),
                onPressed: () => _setNext(365 * 3)),
          ],
        ),
        TextField(
          controller: _vet,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Vet / clinic'),
        ),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Medication

class MedicationForm extends StatefulWidget {
  const MedicationForm({super.key, required this.pet, this.medication});
  final Pet pet;
  final Medication? medication;

  @override
  State<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<MedicationForm> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _note;
  late DateTime _start;
  DateTime? _end;
  late List<int> _times;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(text: m?.dose ?? '');
    _note = TextEditingController(text: m?.note ?? '');
    _start = m?.startDate ?? dateOnly(DateTime.now());
    _end = m?.endDate;
    _times = [...(m?.reminderMinutes ?? const [9 * 60])];
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final m = await pickMinutes(context, _times.isEmpty ? 9 * 60 : 20 * 60);
    if (m == null || _times.contains(m)) return;
    setState(() => _times = [..._times, m]..sort());
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Please enter the medicine name.');
      return;
    }
    if (_times.isEmpty) {
      toast(context, 'Add at least one reminder time.');
      return;
    }
    StoreScope.read(context).upsertMedication(Medication(
      id: widget.medication?.id ?? newId(),
      petId: widget.pet.id,
      name: name,
      dose: _dose.text.trim(),
      startDate: _start,
      endDate: _end,
      reminderMinutes: _times,
      note: _note.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete medicine?',
        'Its reminders and history will be removed.')) {
      return;
    }
    if (!mounted) return;
    StoreScope.read(context).deleteMedication(widget.medication!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.medication == null
          ? 'Medicine for ${widget.pet.name}'
          : 'Edit medicine',
      onSave: _save,
      onDelete: widget.medication == null ? null : _delete,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Medicine name *'),
        ),
        TextField(
          controller: _dose,
          decoration: const InputDecoration(
              labelText: 'Dose', hintText: 'e.g. 1 tablet, 5 ml'),
        ),
        Text('Reminder times', style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in _times)
              InputChip(
                label: Text(fmtMinutes(t)),
                onDeleted: () => setState(() => _times = [..._times]..remove(t)),
                onPressed: () async {
                  final m = await pickMinutes(context, t);
                  if (m == null) return;
                  setState(() {
                    _times = [..._times]..remove(t);
                    if (!_times.contains(m)) _times.add(m);
                    _times.sort();
                  });
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add time'),
              onPressed: _addTime,
            ),
          ],
        ),
        PickerField(
          label: 'Start date',
          value: fmtDate(_start),
          onTap: () async {
            final d = await pickDate(context, _start);
            if (d != null) setState(() => _start = d);
          },
        ),
        PickerField(
          label: 'End date',
          value: _end == null ? 'Ongoing' : fmtDate(_end!),
          icon: Icons.event_busy_outlined,
          onTap: () async {
            final d = await pickDate(
                context, _end ?? _start.add(const Duration(days: 7)),
                first: _start);
            if (d != null) setState(() => _end = d);
          },
          onClear: _end == null ? null : () => setState(() => _end = null),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final days in const [5, 7, 14, 30])
              ActionChip(
                label: Text('$days days'),
                onPressed: () => setState(() =>
                    _end = _start.add(Duration(days: days - 1))),
              ),
          ],
        ),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'Note', hintText: 'e.g. give with food'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Care task

class CareForm extends StatefulWidget {
  const CareForm({super.key, required this.pet, this.care});
  final Pet pet;
  final CareTask? care;

  @override
  State<CareForm> createState() => _CareFormState();
}

class _CareFormState extends State<CareForm> {
  late CareType _type;
  late final TextEditingController _title;
  late final TextEditingController _days;
  late DateTime _next;

  @override
  void initState() {
    super.initState();
    final c = widget.care;
    _type = c?.type ?? CareType.flea;
    _title = TextEditingController(text: c?.title ?? '');
    _days = TextEditingController(text: '${c?.repeatEveryDays ?? 30}');
    _next = c?.nextDate ?? dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    super.dispose();
  }

  void _save() {
    final days = int.tryParse(_days.text.trim());
    if (days == null || days < 1 || days > 3650) {
      toast(context, 'Enter how often it repeats (1 to 3650 days).');
      return;
    }
    if (_type == CareType.custom && _title.text.trim().isEmpty) {
      toast(context, 'Enter a name for this task.');
      return;
    }
    StoreScope.read(context).upsertCare(CareTask(
      id: widget.care?.id ?? newId(),
      petId: widget.pet.id,
      type: _type,
      title: _title.text.trim(),
      repeatEveryDays: days,
      nextDate: _next,
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete task?', 'This reminder will stop.')) {
      return;
    }
    if (!mounted) return;
    StoreScope.read(context).deleteCare(widget.care!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.care == null
          ? 'Repeat care for ${widget.pet.name}'
          : 'Edit care task',
      onSave: _save,
      onDelete: widget.care == null ? null : _delete,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in CareType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        if (_type == CareType.custom)
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Task name *'),
          ),
        TextField(
          controller: _days,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: 'Repeat every (days)', suffixText: 'days'),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final d in const [7, 14, 30, 90])
              ActionChip(
                label: Text(d == 7
                    ? 'Weekly'
                    : d == 14
                        ? '2 weeks'
                        : d == 30
                            ? 'Monthly'
                            : '3 months'),
                onPressed: () => setState(() => _days.text = '$d'),
              ),
          ],
        ),
        PickerField(
          label: 'Next date',
          value: fmtDate(_next),
          icon: Icons.notifications_active_outlined,
          onTap: () async {
            final d = await pickDate(context, _next);
            if (d != null) setState(() => _next = d);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Weight

class WeightForm extends StatefulWidget {
  const WeightForm({super.key, required this.pet, this.entry});
  final Pet pet;
  final WeightEntry? entry;

  @override
  State<WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<WeightForm> {
  late final TextEditingController _value;
  late DateTime _date;
  bool _useLb = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _useLb = StoreScope.read(context).settings.useLb;
  }

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? dateOnly(DateTime.now());
    _value = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final e = widget.entry;
      if (e != null && mounted) {
        final v = _useLb ? kgToLb(e.weightKg) : e.weightKg;
        _value.text = v.toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final v = _parseNum(_value.text);
    if (v == null || v <= 0 || v > 1000) {
      toast(context, 'Enter a valid weight.');
      return;
    }
    StoreScope.read(context).upsertWeight(WeightEntry(
      id: widget.entry?.id ?? newId(),
      petId: widget.pet.id,
      date: _date,
      weightKg: _useLb ? lbToKg(v) : v,
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete entry?', 'This weight will be removed.')) {
      return;
    }
    if (!mounted) return;
    StoreScope.read(context).deleteWeight(widget.entry!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.entry == null
          ? 'Weight for ${widget.pet.name}'
          : 'Edit weight',
      onSave: _save,
      onDelete: widget.entry == null ? null : _delete,
      children: [
        TextField(
          controller: _value,
          autofocus: widget.entry == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimal],
          decoration: InputDecoration(
              labelText: 'Weight *', suffixText: _useLb ? 'lb' : 'kg'),
        ),
        PickerField(
          label: 'Date',
          value: fmtDate(_date),
          onTap: () async {
            final d = await pickDate(context, _date, last: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Vet visit

class VisitForm extends StatefulWidget {
  const VisitForm({super.key, required this.pet, this.visit});
  final Pet pet;
  final VetVisit? visit;

  @override
  State<VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends State<VisitForm> {
  late final TextEditingController _reason;
  late final TextEditingController _vet;
  late final TextEditingController _cost;
  late final TextEditingController _note;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _reason = TextEditingController(text: v?.reason ?? '');
    _vet = TextEditingController(text: v?.vetName ?? '');
    _cost = TextEditingController(
        text: v?.cost == null ? '' : v!.cost!.toStringAsFixed(2));
    _note = TextEditingController(text: v?.note ?? '');
    _date = v?.date ?? dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _reason.dispose();
    _vet.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (_reason.text.trim().isEmpty) {
      toast(context, 'Please enter the reason for the visit.');
      return;
    }
    StoreScope.read(context).upsertVisit(VetVisit(
      id: widget.visit?.id ?? newId(),
      petId: widget.pet.id,
      date: _date,
      reason: _reason.text.trim(),
      vetName: _vet.text.trim(),
      cost: _parseNum(_cost.text),
      note: _note.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete visit?', 'This record will be removed.')) {
      return;
    }
    if (!mounted) return;
    StoreScope.read(context).deleteVisit(widget.visit!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.visit == null
          ? 'Vet visit for ${widget.pet.name}'
          : 'Edit vet visit',
      onSave: _save,
      onDelete: widget.visit == null ? null : _delete,
      children: [
        PickerField(
          label: 'Date',
          value: fmtDate(_date),
          onTap: () async {
            final d = await pickDate(context, _date);
            if (d != null) setState(() => _date = d);
          },
        ),
        TextField(
          controller: _reason,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Reason *', hintText: 'e.g. Annual check-up'),
        ),
        TextField(
          controller: _vet,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Vet / clinic'),
        ),
        TextField(
          controller: _cost,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimal],
          decoration: const InputDecoration(labelText: 'Cost'),
        ),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
              labelText: 'Notes', hintText: 'Diagnosis, advice, next steps'),
        ),
      ],
    );
  }
}
