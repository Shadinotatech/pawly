import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../util.dart';
import 'forms.dart';
import 'pet_form.dart';
import 'weight_chart.dart';
import 'widgets.dart';

Future<void> openPetDetail(BuildContext context, Pet pet) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pet.id)),
    );

class PetDetailScreen extends StatefulWidget {
  const PetDetailScreen({super.key, required this.petId});
  final String petId;

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

const _tabs = ['Overview', 'Vaccines', 'Medicine', 'Care', 'Weight', 'Vet'];

class _PetDetailScreenState extends State<PetDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _add(Pet pet, int tab) {
    switch (tab) {
      case 1:
        openVaccineForm(context, pet);
      case 2:
        openMedicationForm(context, pet);
      case 3:
        openCareForm(context, pet);
      case 4:
        openWeightForm(context, pet);
      case 5:
        openVisitForm(context, pet);
    }
  }

  Future<void> _deletePet(Pet pet) async {
    final ok = await confirm(context, 'Delete ${pet.name}?',
        'All records and reminders for ${pet.name} will be deleted. This cannot be undone.');
    if (!ok || !mounted) return;
    final store = StoreScope.read(context);
    Navigator.of(context).pop();
    await store.deletePet(pet.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pet = store.petById(widget.petId);
    if (pet == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final addLabels = [
      '',
      'Add vaccine',
      'Add medicine',
      'Add care task',
      'Add weight',
      'Add visit',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit pet',
            onPressed: () => openPetForm(context, pet: pet),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _deletePet(pet);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete pet')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(pet, _tab.index),
              icon: const Icon(Icons.add),
              label: Text(addLabels[_tab.index]),
            ),
      body: TabBarView(
        controller: _tab,
        children: [
          _Overview(pet: pet, onAdd: (i) => _add(pet, i), onTab: _tab.animateTo),
          _VaccineList(pet: pet),
          _MedList(pet: pet),
          _CareList(pet: pet),
          _WeightTab(pet: pet),
          _VisitList(pet: pet),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Overview

class _Overview extends StatelessWidget {
  const _Overview({required this.pet, required this.onAdd, required this.onTab});
  final Pet pet;
  final void Function(int tab) onAdd;
  final void Function(int tab) onTab;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final weights = store.weightsFor(pet.id);
    final rows = <(String, String)>[
      ('Species', speciesLabel(pet.species)),
      if (pet.breed.isNotEmpty) ('Breed', pet.breed),
      if (pet.birthDate != null)
        ('Birthday', '${fmtDate(pet.birthDate!)} (${ageText(pet.birthDate)})'),
      if (pet.sex.isNotEmpty) ('Sex', pet.sex == 'male' ? 'Male' : 'Female'),
      if (weights.isNotEmpty)
        ('Weight', fmtWeight(weights.last.weightKg, store.settings.useLb)),
      if (pet.microchip.isNotEmpty) ('Microchip', pet.microchip),
    ];

    final upcoming = <(String, DateTime)>[
      for (final v in store.dueVaccines(petId: pet.id))
        ('${v.name} vaccine', v.nextDueDate!),
      for (final c in store.careFor(pet.id)) (c.displayName, c.nextDate),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final meds =
        store.medsFor(pet.id).where((m) => m.isActiveOn(DateTime.now())).toList();

    final quick = [
      (Icons.vaccines_outlined, 'Vaccine', 1),
      (Icons.medication_outlined, 'Medicine', 2),
      (Icons.event_repeat, 'Care', 3),
      (Icons.monitor_weight_outlined, 'Weight', 4),
      (Icons.local_hospital_outlined, 'Vet visit', 5),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 20),
        Center(child: PetAvatar(pet: pet, radius: 48)),
        const SizedBox(height: 12),
        Center(child: Text(pet.name, style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in quick)
                ActionChip(
                  avatar: Icon(q.$1, size: 18),
                  label: Text(q.$2),
                  onPressed: () => onAdd(q.$3),
                ),
            ],
          ),
        ),
        const SectionTitle('Coming up'),
        if (upcoming.isEmpty && meds.isEmpty)
          const ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Nothing scheduled'),
            subtitle: Text('Add a vaccine due date, medicine or care task.'),
          ),
        for (final m in meds)
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: Text(m.name),
            subtitle: Text(
                '${m.reminderMinutes.map(fmtMinutes).join(', ')}${m.endDate == null ? ' · ongoing' : ' · until ${fmtDate(m.endDate!)}'}'),
            onTap: () => onTab(2),
          ),
        for (final u in upcoming.take(6))
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(u.$1),
            subtitle: Text('${fmtDate(u.$2)} · ${relativeDay(u.$2)}'),
            onTap: () => onTab(u.$1.endsWith('vaccine') ? 1 : 3),
          ),
        const SectionTitle('Profile'),
        for (final r in rows)
          ListTile(
            dense: true,
            title: Text(r.$1,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            trailing: Text(r.$2, style: theme.textTheme.bodyLarge),
          ),
        if (pet.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(pet.notes, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

Widget _emptyTab(String title, String message) => ListView(
      children: [
        const SizedBox(height: 40),
        EmptyState(icon: Icons.inbox_outlined, title: title, message: message),
      ],
    );

// ---------------------------------------------------------------- Vaccines

class _VaccineList extends StatelessWidget {
  const _VaccineList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.vaccinesFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab('No vaccines yet',
          'Record a vaccine and set the next due date to get a reminder.');
    }
    final dueIds = store.dueVaccines(petId: pet.id).map((v) => v.id).toSet();
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final v in list)
          ListTile(
            leading: const Icon(Icons.vaccines_outlined),
            title: Text(v.name),
            subtitle: Text([
              'Given ${fmtDate(v.givenDate)}',
              if (v.nextDueDate != null && dueIds.contains(v.id))
                'Next ${fmtDate(v.nextDueDate!)} (${relativeDay(v.nextDueDate!)})',
              if (v.vetName.isNotEmpty) v.vetName,
            ].join('\n')),
            isThreeLine: v.nextDueDate != null || v.vetName.isNotEmpty,
            trailing: dueIds.contains(v.id) && v.nextDueDate != null
                ? TextButton(
                    onPressed: () => openVaccineForm(context, pet, renewOf: v),
                    child: const Text('Renew'),
                  )
                : null,
            onTap: () => openVaccineForm(context, pet, vaccine: v),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Medicine

class _MedList extends StatelessWidget {
  const _MedList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.medsFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab('No medicines',
          'Add a medicine with reminder times and Pawly will alert you for every dose.');
    }
    final today = dateOnly(DateTime.now());
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final m in list)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: Text(m.name),
                  subtitle: Text([
                    if (m.dose.isNotEmpty) m.dose,
                    m.endDate == null
                        ? 'From ${fmtDate(m.startDate)} · ongoing'
                        : '${fmtDate(m.startDate)} to ${fmtDate(m.endDate!)}',
                    if (!m.isActiveOn(today)) 'Not active today',
                  ].join(' · ')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => openMedicationForm(context, pet, medication: m),
                ),
                if (m.isActiveOn(today))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final t in m.reminderMinutes)
                          Builder(builder: (context) {
                            final at = today.add(Duration(minutes: t));
                            final given = store.isDoseGiven(m.id, at);
                            return FilterChip(
                              label: Text(fmtMinutes(t)),
                              selected: given,
                              onSelected: (_) => store.toggleDose(m, at),
                            );
                          }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Care

class _CareList extends StatelessWidget {
  const _CareList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.careFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab('No repeat care',
          'Add flea treatment, deworming, grooming or any task that repeats.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final c in list)
          ListTile(
            leading: const Icon(Icons.event_repeat),
            title: Text(c.displayName),
            subtitle: Text(
                'Every ${c.repeatEveryDays} days · next ${fmtDate(c.nextDate)} (${relativeDay(c.nextDate)})'),
            trailing: TextButton(
              onPressed: () {
                store.completeCare(c);
                toast(context, 'Done. Next: ${fmtDate(c.nextDate)}');
              },
              child: const Text('Done'),
            ),
            onTap: () => openCareForm(context, pet, care: c),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Weight

class _WeightTab extends StatelessWidget {
  const _WeightTab({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.weightsFor(pet.id);
    final useLb = store.settings.useLb;
    if (list.isEmpty) {
      return _emptyTab('No weights yet',
          'Weigh your pet regularly to spot changes early.');
    }
    final latest = list.last;
    String change = '';
    if (list.length >= 2) {
      final diff = latest.weightKg - list[list.length - 2].weightKg;
      final d = useLb ? kgToLb(diff) : diff;
      change =
          '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)} ${useLb ? 'lb' : 'kg'} since last';
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(fmtWeight(latest.weightKg, useLb),
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        if (change.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(change),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: WeightChart(entries: list, useLb: useLb),
        ),
        for (final w in list.reversed)
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: Text(fmtWeight(w.weightKg, useLb)),
            subtitle: Text(fmtDate(w.date)),
            onTap: () => openWeightForm(context, pet, entry: w),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Vet visits

class _VisitList extends StatelessWidget {
  const _VisitList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.visitsFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab('No vet visits',
          'Keep notes from every visit: reason, advice and cost.');
    }
    final total = list.fold<double>(0, (s, v) => s + (v.cost ?? 0));
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Total vet cost: ${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        for (final v in list)
          ListTile(
            leading: const Icon(Icons.local_hospital_outlined),
            title: Text(v.reason),
            subtitle: Text([
              fmtDate(v.date),
              if (v.vetName.isNotEmpty) v.vetName,
              if (v.cost != null) 'Cost ${v.cost!.toStringAsFixed(2)}',
            ].join(' · ')),
            onTap: () => openVisitForm(context, pet, visit: v),
          ),
      ],
    );
  }
}
